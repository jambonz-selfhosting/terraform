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
    Get private IPs of instances in a managed instance group (GCP).

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

    providers = {
        'gcp': 'gcp', 'aws': 'aws', 'azure': 'azure',
        'exoscale': 'exoscale', 'oci': 'oci', 'hetzner': 'hetzner'
    }
    for key, value in providers.items():
        if key in dir_name:
            return value

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
    startup_checks = server_types_config.get('service_checks', {}).get('startup_scripts', {})
    provider_check = startup_checks.get(provider.lower())

    if provider_check:
        check_cmd = provider_check.get('command')
        success_indicator = provider_check.get('success_indicator')
    else:
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

        if provider.lower() == 'gcp':
            has_pid = "Main PID:" in stdout
            has_success = ("status=0/SUCCESS" in stdout or "Deactivated successfully" in stdout)

            if exit_code == 0 and has_pid and has_success:
                return (True, "Startup script completed successfully")
            elif has_pid:
                return (True, "Startup script completed")
            else:
                return (False, "Startup script not complete or failed")
        else:
            if exit_code == 0 and success_indicator in stdout:
                return (True, "Startup script completed")
            else:
                return (False, "Startup script not complete or failed")

    except SSHError as e:
        return (False, f"SSH error: {e}")


def check_systemd_services(host: str, expected_services: list, ssh_config: dict, optional_services: list = None, service_aliases: dict = None, jump_host: str = None) -> tuple:
    """
    Check if expected systemd services are running.

    Returns:
        (success: bool, message: str, details: dict)
    """
    optional_services = optional_services or []
    service_aliases = service_aliases or {}
    results = {}
    failed_required = []

    for service in expected_services:
        services_to_try = [service]
        if service in service_aliases:
            services_to_try.extend(service_aliases[service])

        is_active = False
        last_status = "unknown"

        for svc_name in services_to_try:
            try:
                stdout, stderr, exit_code = run_ssh_command(
                    host=host,
                    command=f"systemctl is-active {svc_name}",
                    ssh_config=ssh_config,
                    jump_host=jump_host,
                    timeout=10
                )

                last_status = stdout.strip()
                if last_status == "active":
                    is_active = True
                    break

            except SSHError as e:
                last_status = f"error: {e}"

        results[service] = "active" if is_active else last_status

        if not is_active and service not in optional_services:
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

        missing = []
        offline = []

        for service in expected_services:
            if service not in stdout:
                if service not in optional_services:
                    missing.append(service)
            else:
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


def test_server(label: str, ip: str, server_type_name: str, server_types: dict,
                provider: str, ssh_config: dict, server_types_config: dict,
                optional_systemd: list, optional_pm2: list, systemd_aliases: dict,
                verbose: bool, jump_host: str = None, ssh_user: str = None) -> bool:
    """
    Run all checks (SSH, cloud-init, systemd, PM2) for a single server.

    Returns True if all required checks pass.
    """
    passed = True
    orig_user = ssh_config.get('user')

    # Temporarily override SSH user if needed (e.g., root for DB server)
    if ssh_user:
        ssh_config['user'] = ssh_user

    try:
        if jump_host:
            print(f"Testing SSH connectivity via jump host {jump_host}...")
        else:
            print(f"Testing SSH connectivity to {ip}...")
        if test_ssh_connectivity_wrapper(ip, ssh_config, jump_host=jump_host):
            print("✅ SSH connectivity OK")
        else:
            print("❌ SSH connectivity FAILED")
            return False
        print()

        print("Checking startup script...")
        success, message = check_startup_script(ip, provider, ssh_config, server_types_config, jump_host=jump_host)
        if success:
            print(f"✅ {message}")
        else:
            print(f"❌ {message}")
            passed = False
        print()

        server_type = server_types.get(server_type_name, {})
        expected_systemd = server_type.get('systemd_services', [])
        expected_pm2 = server_type.get('pm2_processes', [])

        if expected_systemd:
            print("Checking systemd services...")
            success, message, details = check_systemd_services(
                ip, expected_systemd, ssh_config, optional_systemd, systemd_aliases, jump_host=jump_host)
            if success:
                print(f"✅ {message}")
            else:
                print(f"❌ {message}")
                print("  Service status:")
                for svc, status in details.items():
                    symbol = "✅" if status == "active" else "❌"
                    print(f"    {symbol} {svc}: {status}")
                passed = False
            print()

        if expected_pm2:
            print("Checking PM2 services...")
            success, message, pm2_details = check_pm2_services(
                ip, expected_pm2, ssh_config, optional_pm2, jump_host=jump_host)
            if success:
                print(f"✅ {message}")
            else:
                print(f"❌ {message}")
                passed = False

            if verbose and pm2_details:
                print()
                print("PM2 Status:")
                print("-" * 70)
                print(pm2_details)
                print("-" * 70)
            print()

    finally:
        # Restore original user
        if ssh_user and orig_user is not None:
            ssh_config['user'] = orig_user

    return passed


def build_server_list(tf_outputs: dict, tf_dir: Path, provider: str) -> list:
    """
    Build a list of servers to test from terraform outputs.

    Returns list of dicts:
        [{ 'label': str, 'type': str, 'ips': [str], 'jump_host': str|None, 'ssh_user': str|None }, ...]
    """
    is_mini = 'mini' in str(tf_dir).lower()
    is_large = 'large' in str(tf_dir).lower()
    servers = []

    if is_mini:
        # Mini: single all-in-one VM
        ip = (tf_outputs.get('public_ip') or tf_outputs.get('server_ip')
              or tf_outputs.get('web_monitoring_public_ip'))
        if ip:
            servers.append({
                'label': 'Mini Server (All-in-one)',
                'type': 'mini',
                'ips': [ip],
                'jump_host': None,
                'ssh_user': None,
            })
        return servers

    if is_large:
        # Large: separate monitoring, web, SIP, RTP, feature, recording, DB

        # Monitoring server
        monitoring_ip = tf_outputs.get('monitoring_public_ip')
        if monitoring_ip:
            servers.append({
                'label': 'Monitoring Server',
                'type': 'monitoring',
                'ips': [monitoring_ip],
                'jump_host': None,
                'ssh_user': None,
            })

        # Web server
        web_ip = tf_outputs.get('web_public_ip')
        if web_ip:
            servers.append({
                'label': 'Web Server',
                'type': 'web',
                'ips': [web_ip],
                'jump_host': None,
                'ssh_user': None,
            })

        # SIP servers
        sip_ips = tf_outputs.get('sip_public_ips', [])
        if sip_ips:
            servers.append({
                'label': 'SIP Server',
                'type': 'sip',
                'ips': sip_ips,
                'jump_host': None,
                'ssh_user': None,
            })

        # RTP servers
        rtp_ips = tf_outputs.get('rtp_public_ips', [])
        if rtp_ips:
            servers.append({
                'label': 'RTP Server',
                'type': 'rtp',
                'ips': rtp_ips,
                'jump_host': None,
                'ssh_user': None,
            })

        # Feature servers
        fs_ips = tf_outputs.get('feature_server_public_ips', [])
        if fs_ips:
            servers.append({
                'label': 'Feature Server',
                'type': 'feature-server',
                'ips': fs_ips,
                'jump_host': None,
                'ssh_user': None,
            })

        # Recording servers
        rec_ips = tf_outputs.get('recording_server_public_ips', [])
        if rec_ips:
            servers.append({
                'label': 'Recording Server',
                'type': 'recording',
                'ips': rec_ips,
                'jump_host': None,
                'ssh_user': None,
            })

        # Database server (private IP, accessed via jump host)
        db_ip = tf_outputs.get('db_private_ip')
        if db_ip:
            # Use first SIP server as jump host, fallback to web
            jump = sip_ips[0] if sip_ips else web_ip
            servers.append({
                'label': 'Database Server',
                'type': 'db',
                'ips': [db_ip],
                'jump_host': jump,
                'ssh_user': 'jambonz',
            })

        return servers

    # Medium: web-monitoring, SBC, feature, recording, DB

    # Web/Monitoring server
    web_ip = tf_outputs.get('web_monitoring_public_ip')
    if web_ip:
        servers.append({
            'label': 'Web/Monitoring Server',
            'type': 'web-monitoring',
            'ips': [web_ip],
            'jump_host': None,
            'ssh_user': None,
        })

    # SBC servers
    sbc_ips = tf_outputs.get('sbc_public_ips', [])
    if sbc_ips:
        servers.append({
            'label': 'SBC Server',
            'type': 'sbc',
            'ips': sbc_ips,
            'jump_host': None,
            'ssh_user': None,
        })

    # Feature servers — try public IPs first, fall back to private via jump
    fs_public_ips = tf_outputs.get('feature_server_public_ips', [])
    fs_private_ips = tf_outputs.get('feature_server_private_ips', [])
    # Flatten nested lists (some providers output [[ip], [ip]])
    fs_private_ips = [ip[0] if isinstance(ip, list) else ip for ip in fs_private_ips]

    if fs_public_ips:
        servers.append({
            'label': 'Feature Server',
            'type': 'feature-server',
            'ips': fs_public_ips,
            'jump_host': None,
            'ssh_user': None,
        })
    elif fs_private_ips:
        jump = sbc_ips[0] if sbc_ips else web_ip
        servers.append({
            'label': 'Feature Server',
            'type': 'feature-server',
            'ips': fs_private_ips,
            'jump_host': jump,
            'ssh_user': None,
        })

    # Recording servers — same pattern
    rec_public_ips = tf_outputs.get('recording_server_public_ips', [])
    rec_private_ips = tf_outputs.get('recording_server_private_ips', [])
    rec_private_ips = [ip[0] if isinstance(ip, list) else ip for ip in rec_private_ips]

    if rec_public_ips:
        servers.append({
            'label': 'Recording Server',
            'type': 'recording',
            'ips': rec_public_ips,
            'jump_host': None,
            'ssh_user': None,
        })
    elif rec_private_ips:
        jump = sbc_ips[0] if sbc_ips else web_ip
        servers.append({
            'label': 'Recording Server',
            'type': 'recording',
            'ips': rec_private_ips,
            'jump_host': jump,
            'ssh_user': None,
        })

    # Database server (private IP, accessed via jump host)
    db_ip = tf_outputs.get('db_private_ip')
    if db_ip:
        jump = sbc_ips[0] if sbc_ips else web_ip
        servers.append({
            'label': 'Database Server',
            'type': 'db',
            'ips': [db_ip],
            'jump_host': jump,
            'ssh_user': 'jambonz',
        })

    return servers


def build_server_list_gcp(tf_outputs: dict, tf_dir: Path, server_list: list) -> list:
    """
    Handle GCP MIG-based feature/recording servers.
    Appends MIG instances to the server list if detected.

    Returns the extended server list.
    """
    feature_server_mig = tf_outputs.get('feature_server_mig_name')
    recording_mig = tf_outputs.get('recording_mig_name')

    if not feature_server_mig and not recording_mig:
        return server_list

    # Get project ID
    project_id = tf_dir.parent.parent.name
    if 'project_id' in tf_outputs:
        project_id = tf_outputs['project_id']
    elif 'service_account_email' in tf_outputs:
        email = tf_outputs['service_account_email']
        project_id = email.split('@')[1].split('.')[0]

    web_ip = tf_outputs.get('web_monitoring_public_ip') or tf_outputs.get('web_public_ip')

    if feature_server_mig:
        fs_instances = get_mig_instance_ips("name~-fs-", project_id)
        if fs_instances:
            server_list.append({
                'label': 'Feature Server (MIG)',
                'type': 'feature-server',
                'ips': [ip for _, ip in fs_instances],
                'jump_host': web_ip,
                'ssh_user': None,
            })

    if recording_mig and recording_mig != "Not deployed":
        rec_instances = get_mig_instance_ips("name~-recording-", project_id)
        if rec_instances:
            server_list.append({
                'label': 'Recording Server (MIG)',
                'type': 'recording',
                'ips': [ip for _, ip in rec_instances],
                'jump_host': web_ip,
                'ssh_user': None,
            })

    return server_list


def get_exoscale_pool_instance_ips(pool_id: str, zone: str) -> list:
    """
    Get public IPs of instances in an Exoscale instance pool.

    Instance pool members are named pool-{first5 chars of pool_id}-{random}.
    We list all instances in the zone and match by name prefix.

    Args:
        pool_id: Instance pool ID
        zone: Exoscale zone

    Returns:
        List of tuples: [(name, public_ip), ...]
    """
    prefix = f"pool-{pool_id[:5]}"

    try:
        result = subprocess.run(
            [
                "exo", "compute", "instance", "list",
                "--zone", zone,
                "--output-format", "json"
            ],
            capture_output=True,
            text=True,
            check=True
        )

        instances = json.loads(result.stdout)
        matches = []
        for inst in instances:
            if inst.get('name', '').startswith(prefix) and inst.get('state') == 'running':
                matches.append((inst['name'], inst['ip_address']))

        return matches

    except subprocess.CalledProcessError as e:
        print(f"⚠️  Failed to list Exoscale instances: {e.stderr}")
        return []
    except (json.JSONDecodeError, KeyError) as e:
        print(f"⚠️  Failed to parse Exoscale instance list: {e}")
        return []


def build_server_list_exoscale(tf_outputs: dict, tf_dir: Path, server_list: list) -> list:
    """
    Handle Exoscale instance-pool-based feature/recording servers.
    Appends pool instances to the server list if pool IDs are present
    but individual IPs were not already discovered.

    Returns the extended server list.
    """
    fs_pool_id = tf_outputs.get('feature_server_pool_id')
    rec_pool_id = tf_outputs.get('recording_server_pool_id')
    zone = tf_outputs.get('zone')

    if not zone:
        print("⚠️  No zone output found — cannot query Exoscale instance pools")
        return server_list

    # Check if feature servers were already discovered
    has_fs = any(s['type'] == 'feature-server' for s in server_list)
    has_rec = any(s['type'] == 'recording' for s in server_list)

    if fs_pool_id and not has_fs:
        fs_instances = get_exoscale_pool_instance_ips(fs_pool_id, zone)
        if fs_instances:
            server_list.append({
                'label': 'Feature Server',
                'type': 'feature-server',
                'ips': [ip for _, ip in fs_instances],
                'jump_host': None,
                'ssh_user': None,
            })

    if rec_pool_id and not has_rec:
        rec_instances = get_exoscale_pool_instance_ips(rec_pool_id, zone)
        if rec_instances:
            server_list.append({
                'label': 'Recording Server',
                'type': 'recording',
                'ips': [ip for _, ip in rec_instances],
                'jump_host': None,
                'ssh_user': None,
            })

    return server_list


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
    - Systemd and PM2 services are running
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
    systemd_aliases = server_types_config.get('service_aliases', {}).get('systemd', {})

    # Load SSH config
    if config:
        config_path = Path(config)
    else:
        possible_paths = [
            SCRIPT_DIR / "testing" / "config.yaml",
            Path.cwd() / "config.yaml",
            Path.cwd() / "testing" / "config.yaml",
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

    # Build the list of servers to test
    server_list = build_server_list(tf_outputs, tf_dir, provider)

    # Provider-specific instance group handling
    if provider.lower() == 'gcp':
        server_list = build_server_list_gcp(tf_outputs, tf_dir, server_list)
    elif provider.lower() == 'exoscale':
        server_list = build_server_list_exoscale(tf_outputs, tf_dir, server_list)

    if not server_list:
        print("❌ No servers found in terraform outputs")
        sys.exit(1)

    # Print discovery summary
    print("Discovered servers:")
    for entry in server_list:
        count = len(entry['ips'])
        suffix = f" ({count} instances)" if count > 1 else ""
        via = f" (via {entry['jump_host']})" if entry['jump_host'] else ""
        print(f"  ✓ {entry['label']}{suffix}{via}: {', '.join(entry['ips'])}")
    print()

    # Run tests
    all_passed = True
    test_num = 0

    for entry in server_list:
        ips = entry['ips']
        count = len(ips)

        for idx, ip in enumerate(ips):
            test_num += 1
            if count > 1:
                instance_label = f"{entry['label']} {idx + 1} of {count}: {ip}"
            else:
                instance_label = f"{entry['label']}: {ip}"

            print("=" * 70)
            print(f"Test {test_num}: {instance_label}")
            print("=" * 70)
            print()

            passed = test_server(
                label=instance_label,
                ip=ip,
                server_type_name=entry['type'],
                server_types=server_types,
                provider=provider,
                ssh_config=ssh_config,
                server_types_config=server_types_config,
                optional_systemd=optional_systemd,
                optional_pm2=optional_pm2,
                systemd_aliases=systemd_aliases,
                verbose=verbose,
                jump_host=entry['jump_host'],
                ssh_user=entry['ssh_user'],
            )

            if not passed:
                all_passed = False

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
