#!/usr/bin/env python3
"""
Standalone test for DNS record management.

This tool creates and tests DNS A records for a Jambonz deployment.
Can be run independently to test DNS functionality without a full deployment.

Usage:
    # Create DNS records for deployment
    python test_dns.py create \\
        --subdomain gcp \\
        --web-ip 136.115.167.147 \\
        --sbc-ip 34.44.168.210 \\
        --config config.yaml

    # Test existing DNS records
    python test_dns.py test \\
        --subdomain gcp \\
        --web-ip 136.115.167.147 \\
        --sbc-ip 34.44.168.210

    # Delete DNS records
    python test_dns.py delete \\
        --subdomain gcp \\
        --config config.yaml

    # List all records
    python test_dns.py list --config config.yaml
"""

import sys
import click
from pathlib import Path

# Add lib directory to path
sys.path.insert(0, str(Path(__file__).parent / "lib"))

from config_loader import load_config
from dns_manager import (
    DNSManager,
    DNSError,
    wait_for_dns_propagation,
    extract_base_domain,
    extract_subdomain
)


@click.group()
def cli():
    """DNS record management for Jambonz deployments."""
    pass


@cli.command()
@click.option(
    '--url-portal',
    help='Portal URL from terraform outputs (e.g., "gcp.jambonz.io"). Overrides --subdomain and --base-domain.'
)
@click.option(
    '--subdomain',
    help='Subdomain for this deployment (e.g., "gcp", "azure-test"). Used if --url-portal not provided.'
)
@click.option(
    '--base-domain',
    help='Base domain (e.g., "jambonz.io"). Used if --url-portal not provided. Defaults to config or "jambonz.io".'
)
@click.option(
    '--web-ip',
    required=True,
    help='Public IP for web/monitoring server'
)
@click.option(
    '--sbc-ip',
    required=True,
    multiple=True,
    help='Public IP for SBC (can specify multiple times)'
)
@click.option(
    '--config',
    default='config.yaml',
    type=click.Path(exists=True),
    help='Path to config file (default: config.yaml)'
)
@click.option(
    '--ttl',
    default=300,
    type=int,
    help='DNS TTL in seconds (default: 300)'
)
@click.option(
    '--wait',
    is_flag=True,
    help='Wait for DNS propagation after creating records'
)
def create(url_portal, subdomain, base_domain, web_ip, sbc_ip, config, ttl, wait):
    """
    Create DNS A records for a Jambonz deployment.

    Creates the following records:
    - <subdomain>.<base_domain> -> web_ip
    - api.<subdomain>.<base_domain> -> web_ip
    - grafana.<subdomain>.<base_domain> -> web_ip
    - homer.<subdomain>.<base_domain> -> web_ip
    - public-apps.<subdomain>.<base_domain> -> web_ip
    - sip.<subdomain>.<base_domain> -> sbc_ip[0]
    """
    print("=" * 70)
    print("DNS Record Creation")
    print("=" * 70)
    print()

    # Extract subdomain and base_domain from url_portal if provided
    if url_portal:
        subdomain = extract_subdomain(url_portal)
        base_domain = extract_base_domain(url_portal)
        print(f"Using url_portal: {url_portal}")
        print(f"  → Subdomain: {subdomain}")
        print(f"  → Base domain: {base_domain}")
        print()
    elif not subdomain:
        print("❌ Either --url-portal or --subdomain must be provided")
        sys.exit(1)

    # Load configuration
    try:
        config_data = load_config(config)
        dns_config = config_data.get('dns', {})

        if not dns_config:
            print("❌ No DNS configuration found in config.yaml")
            print()
            print("Please add DNS configuration:")
            print("dns:")
            print("  provider: dnsmadeeasy")
            print("  api_key: your-api-key")
            print("  secret: your-secret")
            sys.exit(1)

    except Exception as e:
        print(f"❌ Failed to load config: {e}")
        sys.exit(1)

    # Initialize DNS manager
    try:
        provider = dns_config.get('provider', 'dnsmadeeasy')
        # Pass base_domain explicitly (from url_portal or flag or config)
        effective_base_domain = base_domain or dns_config.get('base_domain', 'jambonz.io')
        dns = DNSManager(provider=provider, config=dns_config, base_domain=effective_base_domain)
        print(f"✓ DNS manager initialized (provider: {provider})")
        print(f"  Base domain: {effective_base_domain}")
        print()
    except DNSError as e:
        print(f"❌ Failed to initialize DNS manager: {e}")
        sys.exit(1)

    # Define records to create
    records_to_create = [
        (subdomain, web_ip),
        (f"api.{subdomain}", web_ip),
        (f"grafana.{subdomain}", web_ip),
        (f"homer.{subdomain}", web_ip),
        (f"public-apps.{subdomain}", web_ip),
        (f"sip.{subdomain}", sbc_ip[0]),  # Use first SBC IP
    ]

    print(f"Creating {len(records_to_create)} DNS records...")
    print()

    created_records = []
    failed = 0

    for record_subdomain, ip in records_to_create:
        full_domain = f"{record_subdomain}.{effective_base_domain}"
        print(f"  Creating: {full_domain} -> {ip}")

        try:
            record = dns.create_a_record(
                subdomain=record_subdomain,
                ip_address=ip,
                ttl=ttl
            )
            created_records.append(record)
            print(f"    ✅ Created (ID: {record.get('id', 'N/A')})")
        except NotImplementedError:
            print(f"    ⚠️  DNS API not yet implemented (would create: {full_domain} -> {ip})")
        except DNSError as e:
            print(f"    ❌ Failed: {e}")
            failed += 1

    print()
    print("=" * 70)
    print(f"Summary: {len(created_records)} created, {failed} failed")
    print("=" * 70)

    if created_records:
        print()
        print("Created records:")
        for record in created_records:
            print(f"  - {record.get('name', 'N/A')} (ID: {record.get('id', 'N/A')})")

    # Wait for propagation if requested
    if wait and created_records:
        print()
        print("Waiting for DNS propagation...")
        for record_subdomain, ip in records_to_create[:1]:  # Test first record
            full_domain = f"{record_subdomain}.{effective_base_domain}"
            try:
                wait_for_dns_propagation(full_domain, ip, timeout=120)
            except DNSError as e:
                print(f"⚠️  {e}")

    print()
    sys.exit(0 if failed == 0 else 1)


@cli.command()
@click.option(
    '--subdomain',
    required=True,
    help='Subdomain to test'
)
@click.option(
    '--web-ip',
    required=True,
    help='Expected IP for web/monitoring server'
)
@click.option(
    '--sbc-ip',
    required=True,
    help='Expected IP for SBC'
)
def test(subdomain, web_ip, sbc_ip):
    """
    Test if DNS records are correctly configured and propagated.
    """
    import socket

    print("=" * 70)
    print("DNS Record Testing")
    print("=" * 70)
    print()

    # Records to test
    records_to_test = [
        (f"{subdomain}.jambonz.io", web_ip),
        (f"api.{subdomain}.jambonz.io", web_ip),
        (f"grafana.{subdomain}.jambonz.io", web_ip),
        (f"homer.{subdomain}.jambonz.io", web_ip),
        (f"public-apps.{subdomain}.jambonz.io", web_ip),
        (f"sip.{subdomain}.jambonz.io", sbc_ip),
    ]

    passed = 0
    failed = 0

    for domain, expected_ip in records_to_test:
        print(f"Testing: {domain}")

        try:
            resolved_ip = socket.gethostbyname(domain)

            if resolved_ip == expected_ip:
                print(f"  ✅ Resolves to {resolved_ip}")
                passed += 1
            else:
                print(f"  ❌ Resolves to {resolved_ip}, expected {expected_ip}")
                failed += 1
        except socket.gaierror:
            print(f"  ❌ Cannot resolve (not yet propagated)")
            failed += 1

    print()
    print("=" * 70)
    print(f"Summary: {passed} passed, {failed} failed")
    print("=" * 70)
    print()

    sys.exit(0 if failed == 0 else 1)


@cli.command()
@click.option(
    '--config',
    default='config.yaml',
    type=click.Path(exists=True),
    help='Path to config file (default: config.yaml)'
)
@click.option(
    '--subdomain',
    help='Optional subdomain filter'
)
def list(config, subdomain):
    """
    List existing DNS records.
    """
    print("=" * 70)
    print("DNS Records")
    print("=" * 70)
    print()

    # Load configuration
    try:
        config_data = load_config(config)
        dns_config = config_data.get('dns', {})

        if not dns_config:
            print("❌ No DNS configuration found in config.yaml")
            sys.exit(1)

        provider = dns_config.get('provider', 'dnsmadeeasy')
        dns = DNSManager(provider=provider, config=dns_config)

        records = dns.list_records(subdomain=subdomain)

        if records:
            print(f"Found {len(records)} record(s):")
            print()
            for record in records:
                print(f"  {record.get('name', 'N/A')} -> {record.get('value', 'N/A')} (TTL: {record.get('ttl', 'N/A')})")
        else:
            print("No records found.")

    except NotImplementedError:
        print("⚠️  DNS API not yet implemented")
        print("Would list records for:", dns_config.get('base_domain', 'jambonz.io'))
        if subdomain:
            print(f"Filtered by subdomain: {subdomain}")
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

    print()


@cli.command()
@click.option(
    '--subdomain',
    required=True,
    help='Subdomain to delete records for'
)
@click.option(
    '--config',
    default='config.yaml',
    type=click.Path(exists=True),
    help='Path to config file (default: config.yaml)'
)
@click.option(
    '--yes',
    is_flag=True,
    help='Skip confirmation'
)
def delete(subdomain, config, yes):
    """
    Delete DNS records for a subdomain.
    """
    print("=" * 70)
    print("DNS Record Deletion")
    print("=" * 70)
    print()

    if not yes:
        response = input(f"Delete all records for '{subdomain}'? (yes/no): ")
        if response.lower() not in ['yes', 'y']:
            print("Cancelled.")
            sys.exit(0)

    # Load configuration
    try:
        config_data = load_config(config)
        dns_config = config_data.get('dns', {})

        if not dns_config:
            print("❌ No DNS configuration found in config.yaml")
            sys.exit(1)

        provider = dns_config.get('provider', 'dnsmadeeasy')
        dns = DNSManager(provider=provider, config=dns_config)

        # List records to delete
        records = dns.list_records(subdomain=subdomain)

        if not records:
            print("No records found to delete.")
            sys.exit(0)

        print(f"Deleting {len(records)} record(s)...")
        print()

        deleted = 0
        failed = 0

        for record in records:
            record_name = record.get('name', 'N/A')
            record_id = record.get('id')

            print(f"  Deleting: {record_name}")

            try:
                dns.delete_a_record(record_id)
                print(f"    ✅ Deleted")
                deleted += 1
            except NotImplementedError:
                print(f"    ⚠️  DNS API not yet implemented (would delete: {record_name})")
            except DNSError as e:
                print(f"    ❌ Failed: {e}")
                failed += 1

        print()
        print(f"Summary: {deleted} deleted, {failed} failed")

    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

    print()


if __name__ == '__main__':
    cli()
