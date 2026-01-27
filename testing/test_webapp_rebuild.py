#!/usr/bin/env python3
"""
Standalone test for rebuilding the Jambonz webapp with HTTPS configuration.

This tool updates the webapp .env file to use HTTPS URLs and rebuilds the webapp.
This should be run after TLS certificates have been provisioned via certbot.

Usage:
    # Rebuild webapp with HTTPS
    python test_webapp_rebuild.py run \
        --host 136.115.167.147 \
        --config config.yaml

    # Verify webapp is running with HTTPS
    python test_webapp_rebuild.py test \
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
    """Webapp rebuild management for Jambonz deployments."""
    pass


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
def run(host, config):
    """
    Rebuild the Jambonz webapp with HTTPS configuration.

    This will:
    1. Update the .env file to replace http:// with https://
    2. Rebuild the webapp (npm run build)
    3. Restart the webapp PM2 process
    """
    print("=" * 70)
    print("Webapp HTTPS Rebuild")
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
        # Step 1: Show current .env configuration
        print("Step 1: Checking current .env configuration...")
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="grep 'http' /home/jambonz/apps/webapp/.env | head -5",
            ssh_config=ssh_config
        )

        if exit_code == 0:
            print("Current configuration:")
            print("-" * 70)
            print(stdout)
            print("-" * 70)
        else:
            print("⚠️  Could not read current .env file")

        print()

        # Step 2: Update .env file to use HTTPS
        print("Step 2: Updating .env file to use HTTPS...")
        update_cmd = "cd /home/jambonz/apps/webapp && sed -i 's|http://|https://|g' .env"

        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=update_cmd,
            ssh_config=ssh_config
        )

        if exit_code == 0:
            print("✅ .env file updated successfully")
        else:
            print(f"❌ Failed to update .env file")
            print(f"   Stderr: {stderr}")
            sys.exit(1)

        # Verify the change
        stdout2, stderr2, exit_code2 = run_ssh_command(
            host=host,
            command="grep 'https' /home/jambonz/apps/webapp/.env | head -5",
            ssh_config=ssh_config
        )

        if "https://" in stdout2:
            print("Updated configuration:")
            print("-" * 70)
            print(stdout2)
            print("-" * 70)
        else:
            print("⚠️  Warning: Could not verify HTTPS in .env file")

        print()

        # Step 3: Rebuild the webapp
        print("Step 3: Rebuilding webapp (this may take 1-2 minutes)...")
        build_cmd = "cd /home/jambonz/apps/webapp && npm run build"

        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=build_cmd,
            ssh_config=ssh_config,
            timeout=300  # 5 minutes for build
        )

        if exit_code == 0:
            print("✅ Webapp built successfully")
            # Show last few lines of build output
            build_lines = stdout.strip().split('\n')
            if len(build_lines) > 10:
                print("Build output (last 10 lines):")
                print("-" * 70)
                print('\n'.join(build_lines[-10:]))
                print("-" * 70)
        else:
            print(f"❌ Build failed with exit code {exit_code}")
            print("Build output:")
            print("-" * 70)
            print(stdout)
            if stderr:
                print("Errors:")
                print(stderr)
            print("-" * 70)
            sys.exit(1)

        print()

        # Step 4: Restart PM2 process
        print("Step 4: Restarting webapp PM2 process...")
        restart_cmd = "pm2 restart webapp"

        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command=restart_cmd,
            ssh_config=ssh_config
        )

        if exit_code == 0:
            print("✅ Webapp restarted successfully")
            print(stdout)
        else:
            print(f"❌ Failed to restart webapp")
            print(f"   Stderr: {stderr}")
            sys.exit(1)

        print()
        print("=" * 70)
        print("✅ Webapp rebuild complete!")
        print("=" * 70)
        print()
        print("The webapp should now be accessible via HTTPS.")
        print("You may need to wait a few seconds for the webapp to fully restart.")
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
def test(host, config):
    """
    Test if the webapp is running correctly with HTTPS.
    """
    print("=" * 70)
    print("Webapp Status Check")
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
        # Check .env file
        print("Checking .env configuration...")
        stdout, stderr, exit_code = run_ssh_command(
            host=host,
            command="grep -E '(http://|https://)' /home/jambonz/apps/webapp/.env",
            ssh_config=ssh_config
        )

        if "https://" in stdout:
            print("✅ .env file is configured for HTTPS")
            http_count = stdout.count("http://")
            https_count = stdout.count("https://")
            if http_count > 0:
                print(f"⚠️  Warning: Found {http_count} http:// and {https_count} https:// URLs")
                print("   Some URLs may still be using HTTP")
            else:
                print(f"   All {https_count} URLs are using HTTPS")
        else:
            print("⚠️  .env file appears to still be using HTTP")

        print()

        # Check PM2 status
        print("Checking PM2 status...")
        stdout2, stderr2, exit_code2 = run_ssh_command(
            host=host,
            command="pm2 list | grep webapp",
            ssh_config=ssh_config
        )

        if "online" in stdout2:
            print("✅ webapp PM2 process is online")
            print(stdout2.strip())
        else:
            print("⚠️  webapp PM2 process status unclear")
            print(stdout2)

        print()

        # Check recent logs
        print("Recent webapp logs (last 10 lines)...")
        stdout3, stderr3, exit_code3 = run_ssh_command(
            host=host,
            command="pm2 logs webapp --lines 10 --nostream",
            ssh_config=ssh_config
        )

        print("-" * 70)
        print(stdout3)
        print("-" * 70)

    except SSHError as e:
        print(f"❌ SSH error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    cli()
