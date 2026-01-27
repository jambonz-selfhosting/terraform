"""
Cloud-init verification for deployed instances.

Checks that cloud-init completed successfully and all expected
services are running via PM2.
"""

import re
import logging
from typing import List, Dict, Tuple
from ssh_helper import run_ssh_command, SSHError


logger = logging.getLogger("jambonz-test")


class CloudInitError(Exception):
    """Raised when cloud-init verification fails."""
    pass


def _verify_gcp_startup_scripts(
    host: str,
    ssh_config: dict,
    jump_host: str = None,
    role: str = "instance"
) -> Tuple[bool, str]:
    """
    Verify GCP google-startup-scripts completed successfully.

    GCP uses google-startup-scripts.service instead of cloud-init.

    Args:
        host: Instance hostname or IP
        ssh_config: SSH configuration dict
        jump_host: Optional jump host for private instances
        role: Instance role name

    Returns:
        Tuple of (success: bool, message: str)

    Raises:
        SSHError: If SSH connection fails
        CloudInitError: If verification fails
    """
    logger.debug(f"Checking GCP startup scripts on {role}")

    try:
        # Check if google-startup-scripts service completed
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="sudo journalctl -u google-startup-scripts.service --no-pager | tail -10",
            ssh_config=ssh_config,
            jump_host=jump_host
        )

        # Look for completion markers
        completion_markers = [
            "Finished running startup scripts",
            "Finished google-startup-scripts.service",
            "setup complete"
        ]

        if any(marker in stdout for marker in completion_markers):
            success_msg = f"{role}: GCP startup scripts completed successfully"
            logger.info(f"✓ {success_msg}")
            return True, success_msg

        # Check for errors
        if "failed" in stdout.lower() or exit_code != 0:
            error_msg = f"{role}: GCP startup scripts may have failed. Check logs."
            logger.error(error_msg)
            raise CloudInitError(error_msg)

        # If no clear completion but no errors, check service status
        stdout2, stderr2, exit_code2 = run_ssh_command(
            host=host,
            command="sudo systemctl is-active google-startup-scripts.service",
            ssh_config=ssh_config,
            jump_host=jump_host
        )

        # Service is inactive after successful completion
        if "inactive" in stdout2.lower() or "dead" in stdout2.lower():
            success_msg = f"{role}: GCP startup scripts completed (service inactive)"
            logger.info(f"✓ {success_msg}")
            return True, success_msg

        error_msg = f"{role}: GCP startup scripts status unclear"
        logger.warning(error_msg)
        raise CloudInitError(error_msg)

    except SSHError as e:
        error_msg = f"{role}: Failed to check GCP startup scripts: {e}"
        logger.error(error_msg)
        raise CloudInitError(error_msg)


def verify_cloud_init(
    host: str,
    ssh_config: dict,
    jump_host: str = None,
    role: str = "instance",
    provider: str = None
) -> Tuple[bool, str]:
    """
    Verify cloud-init completed successfully on an instance.

    Args:
        host: Instance hostname or IP
        ssh_config: SSH configuration dict
        jump_host: Optional jump host for private instances
        role: Instance role name (for logging)
        provider: Cloud provider (gcp, aws, azure, exoscale, etc.)

    Returns:
        Tuple of (success: bool, message: str)

    Raises:
        SSHError: If SSH connection fails
        CloudInitError: If cloud-init verification fails
    """
    logger.debug(f"Verifying startup on {role} ({host}) [provider: {provider}]")

    # GCP uses google-startup-scripts instead of cloud-init
    if provider and provider.lower() == 'gcp':
        return _verify_gcp_startup_scripts(host, ssh_config, jump_host, role)

    # Method 1: Check cloud-init status command (works on most cloud providers)
    cloud_init_available = True
    try:
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="cloud-init status --wait",
            ssh_config=ssh_config,
            timeout=300,  # cloud-init may still be running
            jump_host=jump_host
        )

        # Check for "status: done"
        if "status: done" not in stdout.lower() and exit_code != 0:
            error_msg = f"{role}: cloud-init not complete. Status: {stdout.strip()}"
            logger.error(error_msg)
            raise CloudInitError(error_msg)

        # If we got here, cloud-init is done
        success_msg = f"{role}: cloud-init completed successfully"
        logger.info(f"✓ {success_msg}")
        return True, success_msg

    except SSHError as e:
        # cloud-init command might not be available (e.g., GCP), try alternate methods
        if "command not found" in str(e).lower() or "127" in str(e):
            cloud_init_available = False
            logger.debug(f"{role}: cloud-init command not available, trying GCP startup script check...")
        else:
            logger.warning(f"{role}: cloud-init status command failed: {e}")
            logger.info(f"{role}: Trying alternate verification method...")

    # Method 2: Check GCP google-startup-scripts service (for GCP instances)
    if not cloud_init_available:
        try:
            stdout, stderr, exit_code = run_ssh_command(
                host=host,
                command="sudo systemctl status google-startup-scripts.service --no-pager | grep -E '(Active:|Finished running)'",
                ssh_config=ssh_config,
                jump_host=jump_host
            )

            # Check if startup scripts finished
            if ("Finished running startup scripts" in stdout or
                "Deactivated successfully" in stdout or
                "Active: active" in stdout):
                # Additional check: look for completion message in journal
                stdout2, stderr2, exit_code2 = run_ssh_command(
                    host=host,
                    command="sudo journalctl -u google-startup-scripts.service --no-pager | tail -5",
                    ssh_config=ssh_config,
                    jump_host=jump_host
                )

                if "Finished running startup scripts" in stdout2 or "setup complete" in stdout2.lower():
                    success_msg = f"{role}: GCP startup scripts completed successfully"
                    logger.info(f"✓ {success_msg}")
                    return True, success_msg

        except SSHError as e:
            logger.warning(f"{role}: GCP startup script check failed: {e}")

    # Method 2: Check cloud-init log for completion marker
    try:
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="tail -n 50 /var/log/cloud-init-output.log",
            ssh_config=ssh_config,
            jump_host=jump_host
        )

        # Look for completion marker
        if "Cloud-init v." not in stdout or "finished" not in stdout.lower():
            error_msg = f"{role}: cloud-init log does not show completion"
            logger.error(error_msg)
            raise CloudInitError(error_msg)

        # Check for errors in log
        error_patterns = [
            r'ERROR',
            r'CRITICAL',
            r'Failed to',
            r'Traceback \(most recent call last\)'
        ]

        errors_found = []
        for pattern in error_patterns:
            matches = re.findall(pattern, stdout, re.IGNORECASE)
            if matches:
                errors_found.extend(matches)

        if errors_found:
            logger.warning(f"{role}: Found potential errors in cloud-init log: {errors_found}")
            # Don't fail on warnings, just log them
            # Some errors might be expected or non-critical

    except SSHError as e:
        error_msg = f"{role}: Failed to check cloud-init log: {e}"
        logger.error(error_msg)
        raise CloudInitError(error_msg)

    success_msg = f"{role}: cloud-init completed successfully"
    logger.info(f"✓ {success_msg}")
    return True, success_msg


def verify_pm2_services(
    host: str,
    ssh_config: dict,
    jump_host: str = None,
    role: str = "instance",
    expected_services: List[str] = None
) -> List[Dict[str, str]]:
    """
    Verify PM2 services are running on an instance.

    Args:
        host: Instance hostname or IP
        ssh_config: SSH configuration dict
        jump_host: Optional jump host for private instances
        role: Instance role name (for logging)
        expected_services: Optional list of service names to expect

    Returns:
        List of service dicts with keys: name, status, uptime, cpu, memory

    Raises:
        SSHError: If SSH connection fails
        CloudInitError: If PM2 services are not running as expected
    """
    logger.debug(f"Checking PM2 services on {role} ({host})")

    try:
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="pm2 jlist",  # JSON output
            ssh_config=ssh_config,
            jump_host=jump_host
        )

        if exit_code != 0:
            # Try regular list format as fallback
            stdout, stderr, exit_code = run_ssh_command(
                host=host,
                command="pm2 list",
                ssh_config=ssh_config,
                jump_host=jump_host
            )

            if exit_code != 0:
                error_msg = f"{role}: PM2 command failed: {stderr}"
                logger.error(error_msg)
                raise CloudInitError(error_msg)

            # Parse table format
            services = _parse_pm2_table(stdout)
        else:
            # Parse JSON format
            import json
            try:
                pm2_data = json.loads(stdout)
                services = []
                for proc in pm2_data:
                    services.append({
                        'name': proc.get('name', 'unknown'),
                        'status': proc.get('pm2_env', {}).get('status', 'unknown'),
                        'uptime': _format_uptime(proc.get('pm2_env', {}).get('pm_uptime', 0)),
                        'restarts': proc.get('pm2_env', {}).get('restart_time', 0),
                        'cpu': f"{proc.get('monit', {}).get('cpu', 0)}%",
                        'memory': _format_memory(proc.get('monit', {}).get('memory', 0))
                    })
            except json.JSONDecodeError:
                # Fallback to table parsing
                services = _parse_pm2_table(stdout)

        if not services:
            error_msg = f"{role}: No PM2 services found"
            logger.warning(error_msg)
            return []

        # Check expected services if provided
        if expected_services:
            service_names = [s['name'] for s in services]
            missing_services = [s for s in expected_services if s not in service_names]
            if missing_services:
                error_msg = f"{role}: Missing expected services: {missing_services}"
                logger.error(error_msg)
                raise CloudInitError(error_msg)

        # Check for online services
        online_services = [s for s in services if s['status'] == 'online']
        stopped_services = [s for s in services if s['status'] != 'online']

        if online_services:
            service_list = ', '.join([s['name'] for s in online_services])
            logger.info(f"✓ {role}: {len(online_services)} services online: {service_list}")

        if stopped_services:
            service_list = ', '.join([s['name'] for s in stopped_services])
            logger.warning(f"{role}: {len(stopped_services)} services not online: {service_list}")

        return services

    except SSHError as e:
        error_msg = f"{role}: Failed to check PM2 services: {e}"
        logger.error(error_msg)
        raise CloudInitError(error_msg)


def _parse_pm2_table(output: str) -> List[Dict[str, str]]:
    """
    Parse PM2 list table format output.

    Args:
        output: PM2 list command output

    Returns:
        List of service dicts
    """
    services = []
    lines = output.split('\n')

    # Find the table data lines (skip header and separator)
    data_started = False
    for line in lines:
        # Skip empty lines
        if not line.strip():
            continue

        # Skip header lines (contain '│' or '┤' or '├')
        if '┌' in line or '├' in line or '└' in line or 'App name' in line:
            continue

        # Look for data lines with │ separator
        if '│' in line:
            data_started = True
            parts = [p.strip() for p in line.split('│') if p.strip()]

            if len(parts) >= 2:
                # Extract name and status at minimum
                name = parts[0] if len(parts) > 0 else 'unknown'
                status = parts[1] if len(parts) > 1 else 'unknown'

                services.append({
                    'name': name,
                    'status': status,
                    'uptime': parts[2] if len(parts) > 2 else 'N/A',
                    'restarts': parts[3] if len(parts) > 3 else 'N/A',
                    'cpu': parts[4] if len(parts) > 4 else 'N/A',
                    'memory': parts[5] if len(parts) > 5 else 'N/A'
                })

    return services


def _format_uptime(timestamp_ms: int) -> str:
    """Format uptime from milliseconds timestamp."""
    from datetime import datetime
    if not timestamp_ms:
        return "N/A"

    uptime_seconds = (datetime.now().timestamp() * 1000 - timestamp_ms) / 1000

    if uptime_seconds < 60:
        return f"{int(uptime_seconds)}s"
    elif uptime_seconds < 3600:
        return f"{int(uptime_seconds / 60)}m"
    elif uptime_seconds < 86400:
        hours = int(uptime_seconds / 3600)
        minutes = int((uptime_seconds % 3600) / 60)
        return f"{hours}h {minutes}m"
    else:
        days = int(uptime_seconds / 86400)
        hours = int((uptime_seconds % 86400) / 3600)
        return f"{days}d {hours}h"


def _format_memory(bytes_value: int) -> str:
    """Format memory from bytes to human-readable format."""
    if not bytes_value:
        return "N/A"

    if bytes_value < 1024:
        return f"{bytes_value}B"
    elif bytes_value < 1024 * 1024:
        return f"{bytes_value / 1024:.1f}KB"
    elif bytes_value < 1024 * 1024 * 1024:
        return f"{bytes_value / (1024 * 1024):.1f}MB"
    else:
        return f"{bytes_value / (1024 * 1024 * 1024):.1f}GB"


def verify_instance(
    host: str,
    ssh_config: dict,
    role: str = "instance",
    jump_host: str = None,
    expected_services: List[str] = None,
    provider: str = None
) -> Dict[str, any]:
    """
    Complete verification of an instance (cloud-init + PM2 services).

    Args:
        host: Instance hostname or IP
        ssh_config: SSH configuration dict
        role: Instance role name
        jump_host: Optional jump host for private instances
        expected_services: Optional list of expected PM2 service names
        provider: Cloud provider (gcp, aws, azure, exoscale, etc.)

    Returns:
        Dictionary with verification results: {
            'host': str,
            'role': str,
            'cloud_init': bool,
            'services': List[Dict],
            'success': bool
        }

    Raises:
        SSHError: If SSH connection fails
        CloudInitError: If verification fails
    """
    result = {
        'host': host,
        'role': role,
        'cloud_init': False,
        'services': [],
        'success': False
    }

    # Verify cloud-init or provider-specific startup mechanism
    cloud_init_success, message = verify_cloud_init(
        host=host,
        ssh_config=ssh_config,
        jump_host=jump_host,
        role=role,
        provider=provider
    )
    result['cloud_init'] = cloud_init_success

    # Verify PM2 services
    services = verify_pm2_services(
        host=host,
        ssh_config=ssh_config,
        jump_host=jump_host,
        role=role,
        expected_services=expected_services
    )
    result['services'] = services

    # Overall success if cloud-init passed and at least one service is online
    online_services = [s for s in services if s['status'] == 'online']
    result['success'] = cloud_init_success and len(online_services) > 0

    return result
