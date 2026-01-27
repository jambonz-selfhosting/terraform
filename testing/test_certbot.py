#!/usr/bin/env python3
"""
Standalone test for TLS certificate provisioning via certbot.

This tool runs certbot on the web/monitoring server to provision TLS certificates
and configure nginx with HTTPS.

Usage:
    # Run certbot for a deployment
    python test_certbot.py run \
        --host 136.115.167.147 \
        --domains gcp.jambonz.io,api.gcp.jambonz.io,grafana.gcp.jambonz.io \
        --email admin@example.com \
        --config config.yaml

    # Test certificate status
    python test_certbot.py test \
        --host 136.115.167.147 \
        --config config.yaml
"""

import sys
import click
from pathlib import Path

# Add lib directory to path
sys.path.insert(0, str(Path(__file__).parent / "lib"))

from config_loader import load_config
from ssh_helper import run_ssh_command, SSHError


@click.group()
def cli():
    """TLS certificate management via certbot for Jambonz deployments."""
    pass


@cli.command()
@click.option(
    '--host',
    required=True,
    help='Web/monitoring server IP or hostname'
)
@click.option(
    '--email',
    required=True,
    help='Email address for Let\'s Encrypt notifications'
)
@click.option(
    '--config',
    default='config.yaml',
    type=click.Path(exists=True),
    help='Path to config file (default: config.yaml)'
)
@click.option(
    '--staging',
    is_flag=True,
    help='Use Let\'s Encrypt staging server (for testing)'
)
@click.option(
    '--expand',
    is_flag=True,
    help='Expand existing certificate with additional domains'
)
def run(host, email, config, staging, expand):
    """
    Run certbot on the web/monitoring server to provision TLS certificates.

    This will:
    1. Run certbot --nginx to discover domains from nginx config
    2. Automatically accept all offered domains
    3. Obtain certificates from Let's Encrypt
    4. Configure nginx with the certificates
    5. Reload nginx to enable HTTPS

    The script will automatically answer all certbot prompts to:
    - Accept all domains that certbot discovers
    - Agree to terms of service
    - Provide the email address
    - Enable HTTP -> HTTPS redirect
    """
    print("=" * 70)
    print("TLS Certificate Provisioning (certbot)")
    print("=" * 70)
    print()

    # Load configuration
    try:
        config_data = load_config(config)
        ssh_config = config_data.get('ssh', {})

        if not ssh_config:
            print("❌ No SSH configuration found in config.yaml")
            sys.exit(1)

    except Exception as e:
        print(f"❌ Failed to load config: {e}")
        sys.exit(1)

    print(f"Target host: {host}")
    print(f"Email: {email}")

    if staging:
        print("⚠️  Using Let's Encrypt STAGING server")
    if expand:
        print("⚠️  Expanding existing certificate")

    print()

    # Step 1: Discover domains from nginx configuration
    print("Discovering domains from nginx configuration...")
    try:
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="sudo grep -h 'server_name' /etc/nginx/sites-enabled/* | grep -v '#' | sed 's/.*server_name//g' | sed 's/;//g' | tr -s ' ' '\n' | grep -v '^$' | sort -u",
            ssh_config=ssh_config
        )

        if exit_code != 0 or not stdout.strip():
            print("❌ Failed to discover domains from nginx")
            print(f"   Stdout: {stdout}")
            print(f"   Stderr: {stderr}")
            sys.exit(1)

        # Parse discovered domains
        discovered_domains = [d.strip() for d in stdout.strip().split('\n') if d.strip() and d.strip() != '_']

        if not discovered_domains:
            print("❌ No domains found in nginx configuration")
            sys.exit(1)

        print(f"✓ Found {len(discovered_domains)} domain(s):")
        for domain in discovered_domains:
            print(f"  - {domain}")
        print()

    except SSHError as e:
        print(f"❌ Failed to discover domains: {e}")
        sys.exit(1)

    # Step 2: Build certbot command with discovered domains
    certbot_cmd_parts = ["sudo certbot --nginx"]

    # Add all discovered domains
    for domain in discovered_domains:
        certbot_cmd_parts.append(f"-d {domain}")

    # Add email
    certbot_cmd_parts.append(f"--email {email}")

    # Non-interactive mode
    certbot_cmd_parts.append("--non-interactive")
    certbot_cmd_parts.append("--agree-tos")

    # No email sharing with EFF
    certbot_cmd_parts.append("--no-eff-email")

    # Staging or production
    if staging:
        certbot_cmd_parts.append("--staging")

    # Expand existing certificate (if adding more domains later)
    if expand:
        certbot_cmd_parts.append("--expand")

    # Redirect HTTP to HTTPS
    certbot_cmd_parts.append("--redirect")

    certbot_cmd = " ".join(certbot_cmd_parts)

    print("Running certbot command:")
    print(f"  {certbot_cmd}")
    print()

    # Execute certbot
    try:
        print("Executing certbot (this may take 1-2 minutes)...")
        print()

        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=certbot_cmd,
            ssh_config=ssh_config,
            timeout=180  # 3 minutes timeout
        )

        print("Certbot output:")
        print("-" * 70)
        print(stdout)
        if stderr:
            print("Errors/Warnings:")
            print(stderr)
        print("-" * 70)
        print()

        if exit_code == 0:
            print("✅ Certbot completed successfully!")
            print()
            print("TLS certificates have been provisioned and nginx has been configured.")
            print("HTTPS should now be enabled for all specified domains.")
            print()

            # Verify nginx is running
            print("Verifying nginx status...")
            stdout2, stderr2, exit_code2 = run_ssh_command(
                host=host,
                command="sudo systemctl status nginx --no-pager | head -10",
                ssh_config=ssh_config
            )

            if "active (running)" in stdout2:
                print("✅ Nginx is running")
            else:
                print("⚠️  Nginx status unclear:")
                print(stdout2)

            sys.exit(0)
        else:
            print(f"❌ Certbot failed with exit code {exit_code}")

            # Check for common errors
            if "too many certificates" in stdout.lower() or "rate limit" in stdout.lower():
                print()
                print("⚠️  Rate limit hit. Let's Encrypt has limits on certificate issuance.")
                print("   Consider using --staging flag for testing.")

            if "connection refused" in stdout.lower() or "timeout" in stdout.lower():
                print()
                print("⚠️  Connection issues. Ensure:")
                print("   - DNS records are properly configured and propagated")
                print("   - Port 80 and 443 are open in firewall")
                print("   - Nginx is running and configured correctly")

            sys.exit(1)

    except SSHError as e:
        print(f"❌ SSH error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)


@cli.command()
@click.option(
    '--host',
    required=True,
    help='Web/monitoring server IP or hostname'
)
@click.option(
    '--config',
    default='config.yaml',
    type=click.Path(exists=True),
    help='Path to config file (default: config.yaml)'
)
def test(host, config):
    """
    Test certificate status and HTTPS configuration.
    """
    print("=" * 70)
    print("TLS Certificate Status Check")
    print("=" * 70)
    print()

    # Load configuration
    try:
        config_data = load_config(config)
        ssh_config = config_data.get('ssh', {})

        if not ssh_config:
            print("❌ No SSH configuration found in config.yaml")
            sys.exit(1)

    except Exception as e:
        print(f"❌ Failed to load config: {e}")
        sys.exit(1)

    print(f"Target host: {host}")
    print()

    try:
        # Check certbot certificates
        print("Checking installed certificates...")
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="sudo certbot certificates",
            ssh_config=ssh_config
        )

        if exit_code == 0 and "Certificate Name:" in stdout:
            print("✅ Certificates found:")
            print("-" * 70)
            print(stdout)
            print("-" * 70)
        else:
            print("⚠️  No certificates found or certbot not configured")
            print(stdout if stdout else "No output")

        print()

        # Check nginx SSL configuration
        print("Checking nginx SSL configuration...")
        stdout2, stderr2, exit_code2 = run_ssh_command(
            host=host,
            command="sudo nginx -T 2>&1 | grep -E '(ssl_certificate|listen.*443)' | head -20",
            ssh_config=ssh_config
        )

        if "ssl_certificate" in stdout2:
            print("✅ Nginx SSL configuration found:")
            print("-" * 70)
            print(stdout2)
            print("-" * 70)
        else:
            print("⚠️  No SSL configuration found in nginx")

        print()

    except SSHError as e:
        print(f"❌ SSH error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)


@cli.command()
@click.option(
    '--host',
    required=True,
    help='Web/monitoring server IP or hostname'
)
@click.option(
    '--config',
    default='config.yaml',
    type=click.Path(exists=True),
    help='Path to config file (default: config.yaml)'
)
def renew(host, config):
    """
    Manually trigger certificate renewal.
    """
    print("=" * 70)
    print("Certificate Renewal")
    print("=" * 70)
    print()

    # Load configuration
    try:
        config_data = load_config(config)
        ssh_config = config_data.get('ssh', {})

        if not ssh_config:
            print("❌ No SSH configuration found in config.yaml")
            sys.exit(1)

    except Exception as e:
        print(f"❌ Failed to load config: {e}")
        sys.exit(1)

    print(f"Target host: {host}")
    print()

    try:
        print("Running certbot renew...")
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="sudo certbot renew",
            ssh_config=ssh_config,
            timeout=180
        )

        print(stdout)
        if stderr:
            print("Warnings:")
            print(stderr)

        if exit_code == 0:
            print()
            print("✅ Certificate renewal completed")
        else:
            print()
            print(f"❌ Renewal failed with exit code {exit_code}")
            sys.exit(1)

    except SSHError as e:
        print(f"❌ SSH error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    cli()
