#!/usr/bin/env python3
"""
Step 1: Verify Jambonz Deployment

Tests that all VMs are accessible, cloud-init completed, and services are running.
Run this immediately after terraform apply.

Usage:
    # From terraform deployment directory (e.g., gcp/provision-vm-medium)
    cd gcp/provision-vm-medium
    python ../../test_deployment.py

    # Or specify terraform directory
    python test_deployment.py --terraform-dir gcp/provision-vm-medium
"""

import sys
import json
import subprocess
from pathlib import Path
import click
import yaml

# Add testing lib directory to path
SCRIPT_DIR = Path(__file__).parent
TESTING_DIR = SCRIPT_DIR / "testing"
sys.path.insert(0, str(TESTING_DIR / "lib"))

from config_loader import load_config
from ssh_helper import run_ssh_command, test_ssh_connectivity, SSHError


def load_server_types(testing_dir: Path) -> dict:
    """
    Load server type definitions from YAML file.
    """
    server_types_file = testing_dir / "server_types.yaml"

    if not server_types_file.exists():
        print(f"⚠️  Server types file not found: {server_types_file}")
        print("Using default configuration")
        return {}

    try:
        with open(server_types_file, 'r') as f:
            return yaml.safe_load(f)
    except Exception as e:
        print(f"⚠️  Failed to load server types: {e}")
        print("Using default configuration")
        return {}


def run_terraform_output(terraform_dir: Path) -> dict:
    """
    Run terraform output -json and return parsed results.
    """
    print("📋 Gathering terraform outputs...")
    print()

    try:
        result = subprocess.run(
            ["terraform", "output", "-json"],
            cwd=terraform_dir,
            capture_output=True,
            text=True,
            check=True
        )

        outputs = json.loads(result.stdout)

        # Extract values from terraform output format
        extracted = {}
        for key, value in outputs.items():
            if isinstance(value, dict) and 'value' in value:
                extracted[key] = value['value']
            else:
                extracted[key] = value

        return extracted

    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to run terraform output: {e}")
        print(f"   Stderr: {e.stderr}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse terraform output: {e}")
        sys.exit(1)


def get_mig_instance_ips(mig_filter: str, project_id: str) -> list:
    """
    Get private IPs of instances in a managed instance group.

    Args:
        mig_filter: Filter pattern (e.g., "name~-fs-" for feature servers)
        project_id: GCP project ID

    Returns:
        List of tuples: [(name, private_ip), ...]
    """
    try:
        result = subprocess.run(
            [
                "gcloud", "compute", "instances", "list",
                f"--filter={mig_filter}",
                "--format=json(name,networkInterfaces[0].networkIP)",
                f"--project={project_id}"
            ],
            capture_output=True,
            text=True,
            check=True
        )

        instances = json.loads(result.stdout)
        return [(inst['name'], inst['networkInterfaces'][0]['networkIP']) for inst in instances]

    except subprocess.CalledProcessError as e:
        print(f"⚠️  Failed to list MIG instances: {e.stderr}")
        return []
    except (json.JSONDecodeError, KeyError) as e:
        print(f"⚠️  Failed to parse instance list: {e}")
        return []


def detect_provider(terraform_dir: Path) -> str:
    """
    Detect cloud provider from terraform directory name.
    """
    dir_name = terraform_dir.resolve().parent.name.lower()

    if 'gcp' in dir_name:
        return 'gcp'
    elif 'azure' in dir_name:
        return 'azure'
    elif 'exoscale' in dir_name:
        return 'exoscale'
    else:
        # Default to gcp if can't detect
        print("⚠️  Could not detect provider from directory, assuming GCP")
        return 'gcp'


def test_ssh_connectivity_wrapper(host: str, ssh_config: dict, jump_host: str = None) -> bool:
    """
    Test SSH connectivity to a host.
    """
    try:
        return test_ssh_connectivity(host, ssh_config, jump_host=jump_host)
    except SSHError:
        return False


def check_startup_script(host: str, provider: str, ssh_config: dict, server_types_config: dict, jump_host: str = None) -> tuple:
    """
    Check if cloud-init/startup script completed successfully.

    Returns:
        (success: bool, message: str)
    """
    # Get provider-specific check from config
    startup_checks = server_types_config.get('service_checks', {}).get('startup_scripts', {})
    provider_check = startup_checks.get(provider.lower())

    if provider_check:
        check_cmd = provider_check.get('command')
        success_indicator = provider_check.get('success_indicator')
    else:
        # Fallback to defaults
        if provider == 'gcp':
            check_cmd = "sudo systemctl status google-startup-scripts.service --no-pager | head -20"
            success_indicator = "Main PID:"
        else:
            check_cmd = "sudo cloud-init status"
            success_indicator = "status: done"

    try:
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=check_cmd,
            ssh_config=ssh_config,
            jump_host=jump_host,
            timeout=30
        )

        # For GCP, check for successful completion indicators
        if provider.lower() == 'gcp':
            # Success if:
            # 1. Has Main PID (it ran)
            # 2. Shows "status=0/SUCCESS" or "Deactivated successfully"
            has_pid = "Main PID:" in stdout
            has_success = ("status=0/SUCCESS" in stdout or "Deactivated successfully" in stdout)

            if exit_code == 0 and has_pid and has_success:
                return (True, "Startup script completed successfully")
            elif has_pid:
                return (True, "Startup script completed")
            else:
                return (False, "Startup script not complete or failed")
        else:
            # For other providers, use the success indicator
            if exit_code == 0 and success_indicator in stdout:
                return (True, "Startup script completed")
            else:
                return (False, "Startup script not complete or failed")

    except SSHError as e:
        return (False, f"SSH error: {e}")


def check_systemd_services(host: str, expected_services: list, ssh_config: dict, optional_services: list = None, jump_host: str = None) -> tuple:
    """
    Check if expected systemd services are running.

    Returns:
        (success: bool, message: str, details: dict)
    """
    optional_services = optional_services or []
    results = {}
    failed_required = []

    for service in expected_services:
        try:
            stdout, stderr, exit_code = run_ssh_command(
                host=host,
                command=f"systemctl is-active {service}",
                ssh_config=ssh_config,
                jump_host=jump_host,
                timeout=10
            )

            is_active = stdout.strip() == "active"
            results[service] = "active" if is_active else stdout.strip()

            if not is_active and service not in optional_services:
                failed_required.append(service)

        except SSHError as e:
            results[service] = f"error: {e}"
            if service not in optional_services:
                failed_required.append(service)

    if failed_required:
        return (False, f"Inactive services: {', '.join(failed_required)}", results)
    else:
        active_count = sum(1 for status in results.values() if status == "active")
        return (True, f"{active_count}/{len(expected_services)} services active", results)


def check_pm2_services(host: str, expected_services: list, ssh_config: dict, optional_services: list = None, jump_host: str = None) -> tuple:
    """
    Check if expected PM2 services are running.

    Returns:
        (success: bool, message: str, details: str)
    """
    optional_services = optional_services or []

    try:
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="pm2 list",
            ssh_config=ssh_config,
            jump_host=jump_host,
            timeout=30
        )

        if exit_code != 0:
            return (False, "PM2 not responding", stdout)

        # Check each expected service
        missing = []
        offline = []

        for service in expected_services:
            if service not in stdout:
                if service not in optional_services:
                    missing.append(service)
            else:
                # Check if this specific service is online
                # Look for the service line in the output
                lines = stdout.split('\n')
                for line in lines:
                    if service in line and 'online' not in line.lower():
                        if service not in optional_services:
                            offline.append(service)
                        break

        if missing:
            return (False, f"Missing services: {', '.join(missing)}", stdout)
        elif offline:
            return (False, f"Offline services: {', '.join(offline)}", stdout)
        else:
            return (True, f"All {len(expected_services)} services online", stdout)

    except SSHError as e:
        return (False, f"SSH error: {e}", "")


@click.command()
@click.option(
    '--terraform-dir',
    type=click.Path(exists=True),
    help='Terraform deployment directory (default: current directory)'
)
@click.option(
    '--config',
    type=click.Path(),
    help='Path to SSH config file (default: testing/config.yaml from script location)'
)
@click.option(
    '--verbose',
    is_flag=True,
    help='Show detailed output'
)
def main(terraform_dir, config, verbose):
    """
    Test Jambonz deployment after terraform apply.

    Verifies:
    - SSH connectivity to all VMs
    - Cloud-init/startup scripts completed
    - PM2 services are running
    """
    print("=" * 70)
    print("Jambonz Deployment Test - Step 1: Verify Infrastructure")
    print("=" * 70)
    print()

    # Determine terraform directory
    if terraform_dir:
        tf_dir = Path(terraform_dir).resolve()
    else:
        tf_dir = Path.cwd()

    print(f"Terraform directory: {tf_dir}")
    print()

    # Detect provider
    provider = detect_provider(tf_dir)
    print(f"Detected provider: {provider.upper()}")
    print()

    # Load server types configuration
    server_types_config = load_server_types(TESTING_DIR)
    server_types = server_types_config.get('server_types', {})
    optional_systemd = server_types_config.get('optional_services', {}).get('systemd', [])
    optional_pm2 = server_types_config.get('optional_services', {}).get('pm2', [])

    # Load SSH config - try multiple locations
    if config:
        config_path = Path(config)
    else:
        # Try multiple default locations
        possible_paths = [
            SCRIPT_DIR / "testing" / "config.yaml",  # Relative to script
            Path.cwd() / "config.yaml",  # Current directory
            Path.cwd() / "testing" / "config.yaml",  # Current/testing
        ]

        config_path = None
        for path in possible_paths:
            if path.exists():
                config_path = path
                break

        if not config_path:
            print("❌ Could not find config.yaml")
            print("Tried:")
            for path in possible_paths:
                print(f"  - {path}")
            print()
            print("Please specify config location with --config")
            sys.exit(1)

    if not config_path.exists():
        print(f"❌ Config file not found: {config_path}")
        sys.exit(1)

    print(f"Using config: {config_path}")
    print()

    try:
        config_data = load_config(str(config_path))
        ssh_config = config_data.get('ssh', {})

        if not ssh_config:
            print("❌ No SSH configuration found in config.yaml")
            sys.exit(1)

    except Exception as e:
        print(f"❌ Failed to load config from {config_path}: {e}")
        sys.exit(1)

    # Get terraform outputs
    tf_outputs = run_terraform_output(tf_dir)

    if verbose:
        print("Terraform outputs:")
        print(json.dumps(tf_outputs, indent=2))
        print()

    # Extract relevant IPs and info
    web_ip = tf_outputs.get('web_monitoring_public_ip')
    sbc_ips = tf_outputs.get('sbc_public_ips', [])
    feature_server_mig = tf_outputs.get('feature_server_mig_name')
    recording_mig = tf_outputs.get('recording_mig_name')

    if not web_ip:
        print("❌ Could not find web_monitoring_public_ip in terraform outputs")
        sys.exit(1)

    if not sbc_ips:
        print("❌ Could not find sbc_public_ips in terraform outputs")
        sys.exit(1)

    print(f"✓ Web/Monitoring IP: {web_ip}")
    print(f"✓ SBC IPs: {', '.join(sbc_ips)}")
    if feature_server_mig:
        print(f"✓ Feature Server MIG: {feature_server_mig}")
    if recording_mig and recording_mig != "Not deployed":
        print(f"✓ Recording MIG: {recording_mig}")
    print()

    # Track results
    all_passed = True

    # Test 1: Web/Monitoring Server
    print("=" * 70)
    print("Test 1: Web/Monitoring Server")
    print("=" * 70)
    print()

    print(f"Testing SSH connectivity to {web_ip}...")
    if test_ssh_connectivity_wrapper(web_ip, ssh_config):
        print("✅ SSH connectivity OK")
    else:
        print("❌ SSH connectivity FAILED")
        all_passed = False
    print()

    print("Checking startup script...")
    success, message = check_startup_script(web_ip, provider, ssh_config, server_types_config)
    if success:
        print(f"✅ {message}")
    else:
        print(f"❌ {message}")
        all_passed = False
    print()

    # Get expected services from server types config
    web_monitoring_type = server_types.get('web-monitoring', {})
    expected_systemd = web_monitoring_type.get('systemd_services', [])
    expected_pm2 = web_monitoring_type.get('pm2_processes', [])

    if expected_systemd:
        print("Checking systemd services...")
        success, message, details = check_systemd_services(web_ip, expected_systemd, ssh_config, optional_systemd)
        if success:
            print(f"✅ {message}")
        else:
            print(f"❌ {message}")
            if verbose:
                print("  Service status:")
                for svc, status in details.items():
                    symbol = "✅" if status == "active" else "❌"
                    print(f"    {symbol} {svc}: {status}")
            all_passed = False
        print()

    if expected_pm2:
        print("Checking PM2 services...")
        success, message, pm2_details = check_pm2_services(web_ip, expected_pm2, ssh_config, optional_pm2)
        if success:
            print(f"✅ {message}")
        else:
            print(f"❌ {message}")
            all_passed = False

        if verbose and pm2_details:
            print()
            print("PM2 Status:")
            print("-" * 70)
            print(pm2_details)
            print("-" * 70)

    print()

    # Test 2: SBC Servers
    print("=" * 70)
    print(f"Test 2: SBC Servers ({len(sbc_ips)} instance(s))")
    print("=" * 70)
    print()

    for idx, sbc_ip in enumerate(sbc_ips, 1):
        print(f"SBC {idx}: {sbc_ip}")
        print("-" * 70)

        print(f"Testing SSH connectivity...")
        if test_ssh_connectivity_wrapper(sbc_ip, ssh_config):
            print("✅ SSH connectivity OK")
        else:
            print("❌ SSH connectivity FAILED")
            all_passed = False
        print()

        print("Checking startup script...")
        success, message = check_startup_script(sbc_ip, provider, ssh_config, server_types_config)
        if success:
            print(f"✅ {message}")
        else:
            print(f"❌ {message}")
            all_passed = False
        print()

        # Get expected services from server types config
        sbc_type = server_types.get('sbc', {})
        expected_systemd = sbc_type.get('systemd_services', [])
        expected_pm2 = sbc_type.get('pm2_processes', [])

        if expected_systemd:
            print("Checking systemd services...")
            success, message, details = check_systemd_services(sbc_ip, expected_systemd, ssh_config, optional_systemd)
            if success:
                print(f"✅ {message}")
            else:
                print(f"❌ {message}")
                if verbose:
                    print("  Service status:")
                    for svc, status in details.items():
                        symbol = "✅" if status == "active" else "❌"
                        print(f"    {symbol} {svc}: {status}")
                all_passed = False
            print()

        if expected_pm2:
            print("Checking PM2 services...")
            success, message, pm2_details = check_pm2_services(sbc_ip, expected_pm2, ssh_config, optional_pm2)
            if success:
                print(f"✅ {message}")
            else:
                print(f"❌ {message}")
                all_passed = False

            if verbose and pm2_details:
                print()
                print("PM2 Status:")
                print("-" * 70)
                print(pm2_details)
                print("-" * 70)

        print()

    # Test 3: Feature Servers (MIG instances)
    if provider.lower() == 'gcp' and feature_server_mig:
        print("=" * 70)
        print("Test 3: Feature Servers (Managed Instance Group)")
        print("=" * 70)
        print()

        # Get project ID from terraform outputs
        project_id = tf_dir.parent.parent.name  # Try to infer from path
        if 'project_id' in tf_outputs:
            project_id = tf_outputs['project_id']
        elif 'service_account_email' in tf_outputs:
            # Extract from service account email
            email = tf_outputs['service_account_email']
            project_id = email.split('@')[1].split('.')[0]

        # List feature server instances
        fs_instances = get_mig_instance_ips("name~-fs-", project_id)

        if not fs_instances:
            print("⚠️  No feature server instances found (may be scaled to 0)")
            print()
        else:
            print(f"Found {len(fs_instances)} feature server instance(s)")
            print()

            for idx, (name, private_ip) in enumerate(fs_instances, 1):
                print(f"Feature Server {idx}: {name} ({private_ip})")
                print("-" * 70)

                print(f"Testing SSH connectivity via jump host {web_ip}...")
                if test_ssh_connectivity_wrapper(private_ip, ssh_config, jump_host=web_ip):
                    print("✅ SSH connectivity OK")
                else:
                    print("❌ SSH connectivity FAILED")
                    all_passed = False
                print()

                print("Checking startup script...")
                success, message = check_startup_script(private_ip, provider, ssh_config, server_types_config, jump_host=web_ip)
                if success:
                    print(f"✅ {message}")
                else:
                    print(f"❌ {message}")
                    all_passed = False
                print()

                # Get expected services from server types config
                fs_type = server_types.get('feature-server', {})
                expected_systemd = fs_type.get('systemd_services', [])
                expected_pm2 = fs_type.get('pm2_processes', [])

                if expected_systemd:
                    print("Checking systemd services...")
                    success, message, details = check_systemd_services(private_ip, expected_systemd, ssh_config, optional_systemd, jump_host=web_ip)
                    if success:
                        print(f"✅ {message}")
                    else:
                        print(f"❌ {message}")
                        if verbose:
                            print("  Service status:")
                            for svc, status in details.items():
                                symbol = "✅" if status == "active" else "❌"
                                print(f"    {symbol} {svc}: {status}")
                        all_passed = False
                    print()

                if expected_pm2:
                    print("Checking PM2 services...")
                    success, message, pm2_details = check_pm2_services(private_ip, expected_pm2, ssh_config, optional_pm2, jump_host=web_ip)
                    if success:
                        print(f"✅ {message}")
                    else:
                        print(f"❌ {message}")
                        all_passed = False

                    if verbose and pm2_details:
                        print()
                        print("PM2 Status:")
                        print("-" * 70)
                        print(pm2_details)
                        print("-" * 70)

                print()

    # Test 4: Recording Servers (MIG instances)
    if provider.lower() == 'gcp' and recording_mig and recording_mig != "Not deployed":
        print("=" * 70)
        print("Test 4: Recording Servers (Managed Instance Group)")
        print("=" * 70)
        print()

        # Use same project_id from above
        recording_instances = get_mig_instance_ips("name~-recording-", project_id)

        if not recording_instances:
            print("⚠️  No recording server instances found (may be scaled to 0)")
            print()
        else:
            print(f"Found {len(recording_instances)} recording server instance(s)")
            print()

            for idx, (name, private_ip) in enumerate(recording_instances, 1):
                print(f"Recording Server {idx}: {name} ({private_ip})")
                print("-" * 70)

                print(f"Testing SSH connectivity via jump host {web_ip}...")
                if test_ssh_connectivity_wrapper(private_ip, ssh_config, jump_host=web_ip):
                    print("✅ SSH connectivity OK")
                else:
                    print("❌ SSH connectivity FAILED")
                    all_passed = False
                print()

                print("Checking startup script...")
                success, message = check_startup_script(private_ip, provider, ssh_config, server_types_config, jump_host=web_ip)
                if success:
                    print(f"✅ {message}")
                else:
                    print(f"❌ {message}")
                    all_passed = False
                print()

                # Get expected services from server types config
                rec_type = server_types.get('recording', {})
                expected_systemd = rec_type.get('systemd_services', [])
                expected_pm2 = rec_type.get('pm2_processes', [])

                if expected_systemd:
                    print("Checking systemd services...")
                    success, message, details = check_systemd_services(private_ip, expected_systemd, ssh_config, optional_systemd, jump_host=web_ip)
                    if success:
                        print(f"✅ {message}")
                    else:
                        print(f"❌ {message}")
                        if verbose:
                            print("  Service status:")
                            for svc, status in details.items():
                                symbol = "✅" if status == "active" else "❌"
                                print(f"    {symbol} {svc}: {status}")
                        all_passed = False
                    print()

                if expected_pm2:
                    print("Checking PM2 services...")
                    success, message, pm2_details = check_pm2_services(private_ip, expected_pm2, ssh_config, optional_pm2, jump_host=web_ip)
                    if success:
                        print(f"✅ {message}")
                    else:
                        print(f"❌ {message}")
                        all_passed = False

                    if verbose and pm2_details:
                        print()
                        print("PM2 Status:")
                        print("-" * 70)
                        print(pm2_details)
                        print("-" * 70)

                print()

    # Summary
    print("=" * 70)
    print("Summary")
    print("=" * 70)
    print()

    if all_passed:
        print("✅ All tests PASSED")
        print()
        print("Your deployment is ready!")
        print()
        print("Next step: Run post-installation configuration")
        print(f"  python ../../post_install.py --email your-email@example.com")
        print()
        sys.exit(0)
    else:
        print("❌ Some tests FAILED")
        print()
        print("Please review the errors above and troubleshoot.")
        print("Common issues:")
        print("  - Startup scripts may still be running (wait 5-10 minutes)")
        print("  - SSH key mismatch")
        print("  - Firewall blocking SSH access")
        print()
        sys.exit(1)


if __name__ == '__main__':
    main()
