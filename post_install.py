#!/usr/bin/env python3
"""
Step 2: Post-Installation Configuration

Configures DNS records, provisions TLS certificates, and rebuilds webapp for HTTPS.
Run this after test_deployment.py passes.

Usage:
    # From terraform deployment directory (e.g., gcp/provision-vm-medium)
    cd gcp/provision-vm-medium
    python ../../post_install.py --email admin@example.com

    # Or specify terraform directory
    python post_install.py --terraform-dir gcp/provision-vm-medium --email admin@example.com

    # Skip DNS creation (if already exists)
    python ../../post_install.py --email admin@example.com --skip-dns

    # Skip TLS (testing)
    python ../../post_install.py --email admin@example.com --skip-tls
"""

import sys
import json
import subprocess
from pathlib import Path
import click

# Add testing lib directory to path
SCRIPT_DIR = Path(__file__).parent
TESTING_DIR = SCRIPT_DIR / "testing"
sys.path.insert(0, str(TESTING_DIR / "lib"))

from config_loader import load_config
from ssh_helper import run_ssh_command, SSHError
from dns_manager import DNSManager, DNSError, extract_base_domain, extract_subdomain


def run_terraform_output(terraform_dir: Path) -> dict:
    """
    Run terraform output -json and return parsed results.
    """
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
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse terraform output: {e}")
        sys.exit(1)


def create_dns_records(
    url_portal: str,
    web_ip: str,
    sbc_ip: str,
    dns_manager: DNSManager,
    base_domain: str,
    ttl: int = 300
) -> bool:
    """
    Create DNS A records for the deployment.

    Returns:
        True if all records created successfully
    """
    print("Creating DNS records...")
    print()

    subdomain = extract_subdomain(url_portal)

    # Define records to create
    records_to_create = [
        (subdomain, web_ip),
        (f"api.{subdomain}", web_ip),
        (f"grafana.{subdomain}", web_ip),
        (f"homer.{subdomain}", web_ip),
        (f"public-apps.{subdomain}", web_ip),
        (f"sip.{subdomain}", sbc_ip),
    ]

    created_records = []
    failed = 0

    for record_subdomain, ip in records_to_create:
        full_domain = f"{record_subdomain}.{base_domain}"
        print(f"  Creating: {full_domain} -> {ip}")

        try:
            record = dns_manager.create_a_record(
                subdomain=record_subdomain,
                ip_address=ip,
                ttl=ttl
            )
            created_records.append(record)
            print(f"    ✅ Created (ID: {record.get('id')})")
        except DNSError as e:
            print(f"    ❌ Failed: {e}")
            failed += 1

    print()
    print(f"Results: {len(created_records)} created, {failed} failed")
    print()

    if failed > 0:
        print("⚠️  Some DNS records failed to create")
        return False

    print("✅ All DNS records created successfully")
    print()
    print("⏳ Waiting 20 seconds for DNS propagation...")
    import time
    time.sleep(20)
    print()

    return True


def provision_tls_certificates(
    host: str,
    email: str,
    ssh_config: dict,
    staging: bool = False
) -> bool:
    """
    Provision TLS certificates using certbot.

    Returns:
        True if successful
    """
    print("Provisioning TLS certificates...")
    print()

    # Step 1: Discover domains from nginx
    print("Step 1: Discovering domains from nginx configuration...")
    try:
        # Try both Debian/Ubuntu style (sites-enabled) and RHEL/Oracle style (conf.d)
        # Use shell to check both locations and combine results
        discover_cmd = """
        (
            sudo grep -h 'server_name' /etc/nginx/sites-enabled/* 2>/dev/null || true
            sudo grep -h 'server_name' /etc/nginx/conf.d/*.conf 2>/dev/null || true
        ) | grep -v '#' | sed 's/.*server_name//g' | sed 's/;//g' | tr -s ' ' '\\n' | grep -v '^$' | sort -u
        """
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=discover_cmd,
            ssh_config=ssh_config
        )

        if not stdout.strip():
            print("❌ Failed to discover domains from nginx")
            return False

        discovered_domains = [d.strip() for d in stdout.strip().split('\n') if d.strip() and d.strip() != '_']

        if not discovered_domains:
            print("❌ No domains found in nginx configuration")
            return False

        print(f"✓ Found {len(discovered_domains)} domain(s):")
        for domain in discovered_domains:
            print(f"  - {domain}")
        print()

    except SSHError as e:
        print(f"❌ Failed to discover domains: {e}")
        return False

    # Step 2: Build certbot command
    print("Step 2: Running certbot...")
    certbot_cmd_parts = ["sudo certbot --nginx"]

    for domain in discovered_domains:
        certbot_cmd_parts.append(f"-d {domain}")

    certbot_cmd_parts.append(f"--email {email}")
    certbot_cmd_parts.append("--non-interactive")
    certbot_cmd_parts.append("--agree-tos")
    certbot_cmd_parts.append("--no-eff-email")
    certbot_cmd_parts.append("--redirect")

    if staging:
        certbot_cmd_parts.append("--staging")

    certbot_cmd = " ".join(certbot_cmd_parts)

    try:
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=certbot_cmd,
            ssh_config=ssh_config,
            timeout=180
        )

        if exit_code == 0:
            print("✅ Certbot completed successfully!")
            print()
            return True
        else:
            print(f"❌ Certbot failed with exit code {exit_code}")
            print("Output:")
            print("-" * 70)
            print(stdout)
            if stderr:
                print("Errors:")
                print(stderr)
            print("-" * 70)
            return False

    except SSHError as e:
        print(f"❌ SSH error: {e}")
        return False


def rebuild_webapp_https(host: str, ssh_config: dict) -> bool:
    """
    Update webapp .env to use HTTPS and rebuild.

    Returns:
        True if successful
    """
    print("Rebuilding webapp with HTTPS configuration...")
    print()

    try:
        # Step 1: Update .env file
        print("Step 1: Updating .env file to use HTTPS...")
        update_cmd = "cd /home/jambonz/apps/webapp && sed -i 's|http://|https://|g' .env"

        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=update_cmd,
            ssh_config=ssh_config
        )

        if exit_code != 0:
            print(f"❌ Failed to update .env file")
            print(f"   Stderr: {stderr}")
            return False

        print("✅ .env file updated")
        print()

        # Step 2: Rebuild webapp
        print("Step 2: Rebuilding webapp (this may take 1-2 minutes)...")
        build_cmd = "cd /home/jambonz/apps/webapp && npm run build"

        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=build_cmd,
            ssh_config=ssh_config,
            timeout=300
        )

        if exit_code != 0:
            print(f"❌ Build failed with exit code {exit_code}")
            return False

        print("✅ Webapp built successfully")
        print()

        # Step 3: Restart PM2
        print("Step 3: Restarting webapp PM2 process...")
        restart_cmd = "pm2 restart webapp"

        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=restart_cmd,
            ssh_config=ssh_config
        )

        if exit_code != 0:
            print(f"❌ Failed to restart webapp")
            return False

        print("✅ Webapp restarted successfully")
        print()

        return True

    except SSHError as e:
        print(f"❌ SSH error: {e}")
        return False


@click.command()
@click.option(
    '--terraform-dir',
    type=click.Path(exists=True),
    help='Terraform deployment directory (default: current directory)'
)
@click.option(
    '--email',
    required=True,
    help='Email address for Let\'s Encrypt certificate notifications'
)
@click.option(
    '--config',
    type=click.Path(),
    help='Path to config file (default: testing/config.yaml from script location)'
)
@click.option(
    '--skip-dns',
    is_flag=True,
    help='Skip DNS record creation (if already exists)'
)
@click.option(
    '--skip-tls',
    is_flag=True,
    help='Skip TLS certificate provisioning'
)
@click.option(
    '--skip-webapp',
    is_flag=True,
    help='Skip webapp rebuild'
)
@click.option(
    '--staging',
    is_flag=True,
    help='Use Let\'s Encrypt staging server (for testing)'
)
def main(terraform_dir, email, config, skip_dns, skip_tls, skip_webapp, staging):
    """
    Post-installation configuration for Jambonz deployment.

    Steps:
    1. Create DNS A records
    2. Provision TLS certificates with certbot
    3. Rebuild webapp for HTTPS
    """
    print("=" * 70)
    print("Jambonz Deployment - Step 2: Post-Installation Configuration")
    print("=" * 70)
    print()

    # Determine terraform directory
    if terraform_dir:
        tf_dir = Path(terraform_dir).resolve()
    else:
        tf_dir = Path.cwd()

    print(f"Terraform directory: {tf_dir}")
    print()

    # Load config - try multiple locations
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
        dns_config = config_data.get('dns', {})

        if not ssh_config:
            print("❌ No SSH configuration found in config.yaml")
            sys.exit(1)

        if not skip_dns and not dns_config:
            print("❌ No DNS configuration found in config.yaml")
            print()
            print("Please add DNS configuration to config.yaml:")
            print("dns:")
            print("  provider: dnsmadeeasy")
            print("  api_key: your-api-key")
            print("  secret: your-secret")
            sys.exit(1)

    except Exception as e:
        print(f"❌ Failed to load config from {config_path}: {e}")
        sys.exit(1)

    # Get terraform outputs
    print("📋 Gathering terraform outputs...")
    tf_outputs = run_terraform_output(tf_dir)

    portal_url = tf_outputs.get('portal_url', '').replace('http://', '').replace('https://', '')
    # Support medium (web_monitoring_public_ip), large split (web_public_ip), and mini (public_ip)
    web_ip = tf_outputs.get('web_monitoring_public_ip') or tf_outputs.get('web_public_ip') or tf_outputs.get('public_ip')
    sbc_ips = tf_outputs.get('sbc_public_ips') or tf_outputs.get('sip_public_ips', [])
    # For mini deployments, the single VM handles SBC too
    is_mini = 'mini' in str(tf_dir).lower()
    if is_mini and not sbc_ips and web_ip:
        sbc_ips = [web_ip]  # Mini uses same IP for all services
    portal_password = tf_outputs.get('portal_password') or tf_outputs.get('admin_password')

    if not portal_url or not web_ip or not sbc_ips:
        print("❌ Missing required terraform outputs")
        print(f"   portal_url: {portal_url}")
        print(f"   web_ip: {web_ip}")
        print(f"   sbc_ips: {sbc_ips}")
        sys.exit(1)

    if is_mini:
        print(f"✓ Portal URL: {portal_url}")
        print(f"✓ Mini Server IP: {web_ip} (all-in-one)")
    else:
        print(f"✓ Portal URL: {portal_url}")
        print(f"✓ Web/Monitoring IP: {web_ip}")
        print(f"✓ SBC IPs: {', '.join(sbc_ips)}")
    print()

    # Track results
    all_passed = True

    # Step 1: Create DNS records
    if not skip_dns:
        print("=" * 70)
        print("Step 1: Create DNS Records")
        print("=" * 70)
        print()

        base_domain = extract_base_domain(portal_url)
        subdomain = extract_subdomain(portal_url)

        print(f"Domain: {portal_url}")
        print(f"  → Subdomain: {subdomain}")
        print(f"  → Base domain: {base_domain}")
        print()

        try:
            provider = dns_config.get('provider', 'dnsmadeeasy')
            dns_manager = DNSManager(provider=provider, config=dns_config, base_domain=base_domain)

            if not create_dns_records(portal_url, web_ip, sbc_ips[0], dns_manager, base_domain):
                print("❌ DNS record creation failed")
                all_passed = False
            else:
                print("✅ DNS records created and propagating")

        except DNSError as e:
            print(f"❌ DNS manager error: {e}")
            all_passed = False

        print()
    else:
        print("Skipping DNS record creation (--skip-dns)")
        print()

    # Step 2: Provision TLS certificates
    if not skip_tls and all_passed:
        print("=" * 70)
        print("Step 2: Provision TLS Certificates")
        print("=" * 70)
        print()

        print(f"Target: {web_ip}")
        print(f"Email: {email}")
        if staging:
            print("⚠️  Using Let's Encrypt STAGING server")
        print()

        if not provision_tls_certificates(web_ip, email, ssh_config, staging):
            print("❌ TLS certificate provisioning failed")
            all_passed = False
        else:
            print("✅ TLS certificates provisioned")

        print()
    elif skip_tls:
        print("Skipping TLS certificate provisioning (--skip-tls)")
        print()

    # Step 3: Rebuild webapp for HTTPS
    if not skip_webapp and all_passed:
        print("=" * 70)
        print("Step 3: Rebuild Webapp for HTTPS")
        print("=" * 70)
        print()

        print(f"Target: {web_ip}")
        print()

        if not rebuild_webapp_https(web_ip, ssh_config):
            print("❌ Webapp rebuild failed")
            all_passed = False
        else:
            print("✅ Webapp rebuilt for HTTPS")

        print()
    elif skip_webapp:
        print("Skipping webapp rebuild (--skip-webapp)")
        print()

    # Summary
    print("=" * 70)
    print("Summary")
    print("=" * 70)
    print()

    if all_passed:
        print("✅ Post-installation configuration COMPLETE!")
        print()
        print("Your Jambonz deployment is ready to use!")
        print()
        print(f"Portal URL: https://{portal_url}")
        print(f"Username: admin")
        print(f"Password: {portal_password}")
        print()
        print("⚠️  You will be required to change the password on first login")
        print()
        print("Additional URLs:")
        print(f"  - API: https://api.{portal_url}/api/v1")
        print(f"  - Grafana: https://grafana.{portal_url}")
        print(f"  - Homer: https://homer.{portal_url}")
        print()
        sys.exit(0)
    else:
        print("❌ Post-installation configuration FAILED")
        print()
        print("Please review the errors above and troubleshoot.")
        print()
        sys.exit(1)


if __name__ == '__main__':
    main()
