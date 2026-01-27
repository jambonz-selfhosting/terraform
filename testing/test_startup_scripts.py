#!/usr/bin/env python3
"""
Standalone test for startup script verification (cloud-init or GCP startup scripts).

This is a minimal, independent test that checks if startup scripts completed
on specific instances without requiring terraform state or full deployment context.

Usage:
    # Test a single instance
    python test_startup_scripts.py --host 136.115.167.147 --provider gcp

    # Test with jump host
    python test_startup_scripts.py --host 172.20.10.6 --jump-host 136.115.167.147 --provider gcp

    # Test multiple instances
    python test_startup_scripts.py --host 136.115.167.147 --host 34.44.168.210 --provider gcp
"""

import sys
import click
from pathlib import Path

# Add lib directory to path
sys.path.insert(0, str(Path(__file__).parent / "lib"))

from config_loader import load_config
from cloud_init_checker import verify_cloud_init, CloudInitError
from ssh_helper import SSHError


@click.command()
@click.option(
    '--host',
    multiple=True,
    required=True,
    help='Instance IP or hostname (can specify multiple times)'
)
@click.option(
    '--jump-host',
    help='Jump host for accessing private instances'
)
@click.option(
    '--provider',
    type=click.Choice(['gcp', 'aws', 'azure', 'exoscale', 'digitalocean'], case_sensitive=False),
    default='exoscale',
    help='Cloud provider (affects which startup mechanism to check)'
)
@click.option(
    '--config',
    default='config.yaml',
    type=click.Path(exists=True),
    help='Path to config file (default: config.yaml)'
)
@click.option(
    '--role',
    help='Instance role name (for logging, e.g., "web-monitoring", "sbc-0")'
)
def main(host, jump_host, provider, config, role):
    """
    Test startup script completion on one or more instances.

    This tool checks if cloud-init (or provider-specific startup scripts)
    completed successfully on the specified instances.
    """
    # Load configuration
    try:
        config_data = load_config(config)
        ssh_config = config_data.get('ssh', {})
    except Exception as e:
        print(f"❌ Failed to load config: {e}")
        sys.exit(1)

    print("=" * 70)
    print("Startup Script Verification Test")
    print("=" * 70)
    print()
    print(f"Provider: {provider}")
    print(f"Instances to test: {len(host)}")
    if jump_host:
        print(f"Jump host: {jump_host}")
    print()

    # Test each host
    passed = 0
    failed = 0

    for i, instance_host in enumerate(host):
        instance_role = role if role else f"instance-{i}"

        print(f"Testing {instance_role} ({instance_host})...")
        if jump_host:
            print(f"  → via jump host {jump_host}")

        try:
            success, message = verify_cloud_init(
                host=instance_host,
                ssh_config=ssh_config,
                jump_host=jump_host,
                role=instance_role,
                provider=provider
            )

            if success:
                print(f"  ✅ {message}")
                passed += 1
            else:
                print(f"  ❌ {message}")
                failed += 1

        except (SSHError, CloudInitError) as e:
            print(f"  ❌ Error: {e}")
            failed += 1
        except Exception as e:
            print(f"  ❌ Unexpected error: {e}")
            failed += 1

        print()

    # Summary
    print("=" * 70)
    print("Summary")
    print("=" * 70)
    print(f"Total instances: {len(host)}")
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    print()

    sys.exit(0 if failed == 0 else 1)


if __name__ == '__main__':
    main()
