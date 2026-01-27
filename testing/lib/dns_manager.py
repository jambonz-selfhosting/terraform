"""
DNS record management for Jambonz deployments.

Supports creating and deleting DNS A records via DNS provider APIs.
Currently supports: DNSMadeEasy (extendable to other providers).

Phase 2 of the testing framework.
"""

import logging
import requests
from typing import List, Dict, Tuple
from datetime import datetime
import hashlib
import hmac


logger = logging.getLogger("jambonz-test")


class DNSError(Exception):
    """Raised when DNS operations fail."""
    pass


class DNSManager:
    """
    DNS record manager supporting multiple providers.
    """

    def __init__(self, provider: str, config: dict, base_domain: str = None):
        """
        Initialize DNS manager.

        Args:
            provider: DNS provider name (dnsmadeeasy)
            config: Provider-specific configuration (api_key, secret)
            base_domain: Base domain (e.g., 'jambonz.io') - can be extracted from url_portal
        """
        self.provider = provider.lower()
        self.config = config

        if self.provider == 'dnsmadeeasy':
            self.api_key = config.get('api_key')
            self.secret = config.get('secret')
            self.api_url = config.get('api_url', 'https://api.dnsmadeeasy.com/V2.0')

            # Base domain can come from:
            # 1. Explicitly passed (from terraform outputs)
            # 2. Config file (fallback)
            # 3. Default to jambonz.io
            self.base_domain = base_domain or config.get('base_domain', 'jambonz.io')

            if not self.api_key or not self.secret:
                raise DNSError("DNSMadeEasy requires api_key and secret in config")

            logger.debug(f"DNSMadeEasy API URL: {self.api_url}")
        else:
            raise DNSError(f"Unsupported DNS provider: {provider}")

    def create_a_record(
        self,
        subdomain: str,
        ip_address: str,
        ttl: int = 300
    ) -> Dict[str, any]:
        """
        Create an A record.

        Args:
            subdomain: Subdomain (e.g., 'gcp', 'api.gcp')
            ip_address: IP address to point to
            ttl: TTL in seconds (default: 300)

        Returns:
            Dictionary with record details: {
                'id': str,
                'name': str,
                'type': 'A',
                'value': str,
                'ttl': int
            }

        Raises:
            DNSError: If record creation fails
        """
        full_domain = f"{subdomain}.{self.base_domain}"
        logger.info(f"Creating A record: {full_domain} -> {ip_address}")

        if self.provider == 'dnsmadeeasy':
            return self._create_dnsmadeeasy_record(subdomain, ip_address, ttl)

        raise DNSError(f"Provider {self.provider} not implemented")

    def delete_a_record(self, record_id: str) -> bool:
        """
        Delete an A record by ID.

        Args:
            record_id: Provider-specific record ID

        Returns:
            True if deletion successful

        Raises:
            DNSError: If deletion fails
        """
        logger.info(f"Deleting DNS record: {record_id}")

        if self.provider == 'dnsmadeeasy':
            return self._delete_dnsmadeeasy_record(record_id)

        raise DNSError(f"Provider {self.provider} not implemented")

    def list_records(self, subdomain: str = None) -> List[Dict[str, any]]:
        """
        List existing DNS records.

        Args:
            subdomain: Optional subdomain filter

        Returns:
            List of record dictionaries

        Raises:
            DNSError: If listing fails
        """
        logger.debug(f"Listing DNS records for {self.base_domain}")

        if self.provider == 'dnsmadeeasy':
            return self._list_dnsmadeeasy_records(subdomain)

        raise DNSError(f"Provider {self.provider} not implemented")

    def _create_dnsmadeeasy_record(
        self,
        subdomain: str,
        ip_address: str,
        ttl: int
    ) -> Dict[str, any]:
        """
        Create A record via DNSMadeEasy API.

        API docs: https://api-docs.dnsmadeeasy.com/
        """
        # Step 1: Get domain ID
        domain_id = self._get_domain_id(self.base_domain)

        if not domain_id:
            raise DNSError(f"Domain not found: {self.base_domain}")

        # Step 2: Check if record exists and delete it first
        existing_records = self._list_dnsmadeeasy_records(subdomain)
        for record in existing_records:
            if record['name'] == subdomain and record['type'] == 'A':
                logger.info(f"Deleting existing record: {subdomain}.{self.base_domain}")
                self._delete_dnsmadeeasy_record(record['id'])

        # Step 3: Create new record
        headers = self._generate_dnsmadeeasy_headers()
        url = f"{self.api_url}/dns/managed/{domain_id}/records"

        data = {
            "name": subdomain,
            "type": "A",
            "value": ip_address,
            "ttl": ttl
        }

        response = requests.post(url, headers=headers, json=data)

        if response.status_code not in [200, 201]:
            raise DNSError(f"Failed to create record: {response.status_code} - {response.text}")

        result = response.json()
        return {
            'id': result.get('id'),
            'name': subdomain,
            'type': 'A',
            'value': ip_address,
            'ttl': ttl
        }

    def _delete_dnsmadeeasy_record(self, record_id: str) -> bool:
        """
        Delete record via DNSMadeEasy API.
        """
        # Get domain ID first
        domain_id = self._get_domain_id(self.base_domain)

        if not domain_id:
            raise DNSError(f"Domain not found: {self.base_domain}")

        headers = self._generate_dnsmadeeasy_headers()
        url = f"{self.api_url}/dns/managed/{domain_id}/records/{record_id}"

        response = requests.delete(url, headers=headers)

        if response.status_code not in [200, 204]:
            raise DNSError(f"Failed to delete record {record_id}: {response.status_code} - {response.text}")

        logger.debug(f"Deleted record ID: {record_id}")
        return True

    def _list_dnsmadeeasy_records(self, subdomain: str = None) -> List[Dict[str, any]]:
        """
        List records via DNSMadeEasy API.
        """
        # Get domain ID first
        domain_id = self._get_domain_id(self.base_domain)

        if not domain_id:
            raise DNSError(f"Domain not found: {self.base_domain}")

        headers = self._generate_dnsmadeeasy_headers()
        url = f"{self.api_url}/dns/managed/{domain_id}/records"

        response = requests.get(url, headers=headers)

        if response.status_code != 200:
            raise DNSError(f"Failed to list records: {response.status_code} - {response.text}")

        result = response.json()
        records = result.get('data', [])

        # Filter by subdomain if provided
        if subdomain:
            # Match records that either:
            # - Are exactly the subdomain (e.g., "gcp")
            # - End with ".subdomain" (e.g., "api.gcp")
            records = [
                r for r in records
                if r.get('name') == subdomain or r.get('name', '').endswith(f".{subdomain}")
            ]

        # Convert to standardized format
        return [
            {
                'id': r.get('id'),
                'name': r.get('name'),
                'type': r.get('type'),
                'value': r.get('value'),
                'ttl': r.get('ttl')
            }
            for r in records
        ]

    def _get_domain_id(self, domain: str) -> str:
        """
        Get domain ID from DNSMadeEasy for a given domain name.

        Args:
            domain: Domain name (e.g., 'jambonz.io')

        Returns:
            Domain ID string

        Raises:
            DNSError: If domain not found or API call fails
        """
        headers = self._generate_dnsmadeeasy_headers()
        url = f"{self.api_url}/dns/managed/name?domainname={domain}"

        response = requests.get(url, headers=headers)

        if response.status_code != 200:
            raise DNSError(f"Failed to get domain ID for {domain}: {response.status_code} - {response.text}")

        result = response.json()
        domain_id = result.get('id')

        if not domain_id:
            raise DNSError(f"Domain {domain} not found in DNSMadeEasy")

        logger.debug(f"Found domain ID {domain_id} for {domain}")
        return str(domain_id)

    def _generate_dnsmadeeasy_headers(self) -> dict:
        """
        Generate authentication headers for DNSMadeEasy API.

        DNSMadeEasy uses HMAC-SHA1 authentication with timestamp.
        """
        timestamp = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')

        # Create HMAC-SHA1 signature
        hmac_hash = hmac.new(
            self.secret.encode('utf-8'),
            timestamp.encode('utf-8'),
            hashlib.sha1
        ).hexdigest()

        return {
            'x-dnsme-apiKey': self.api_key,
            'x-dnsme-requestDate': timestamp,
            'x-dnsme-hmac': hmac_hash,
            'Content-Type': 'application/json'
        }


def extract_base_domain(url_portal: str) -> str:
    """
    Extract base domain from url_portal terraform output.

    Args:
        url_portal: Full portal URL (e.g., 'gcp.jambonz.io', 'azure-prod.jambonz.io')

    Returns:
        Base domain (e.g., 'jambonz.io')

    Examples:
        >>> extract_base_domain('gcp.jambonz.io')
        'jambonz.io'
        >>> extract_base_domain('test.example.com')
        'example.com'
    """
    parts = url_portal.split('.')
    if len(parts) >= 2:
        # Return last two parts (domain.tld)
        return '.'.join(parts[-2:])
    return url_portal


def extract_subdomain(url_portal: str) -> str:
    """
    Extract subdomain from url_portal terraform output.

    Args:
        url_portal: Full portal URL (e.g., 'gcp.jambonz.io', 'azure-prod.jambonz.io')

    Returns:
        Subdomain (e.g., 'gcp', 'azure-prod')

    Examples:
        >>> extract_subdomain('gcp.jambonz.io')
        'gcp'
        >>> extract_subdomain('azure-prod.jambonz.io')
        'azure-prod'
    """
    parts = url_portal.split('.')
    if len(parts) >= 3:
        # Return all parts except last two (everything before domain.tld)
        return '.'.join(parts[:-2])
    return url_portal.split('.')[0] if '.' in url_portal else url_portal


def wait_for_dns_propagation(
    domain: str,
    expected_ip: str,
    timeout: int = 120,
    interval: int = 5
) -> bool:
    """
    Wait for DNS record to propagate.

    Args:
        domain: Domain to check
        expected_ip: Expected IP address
        timeout: Max wait time in seconds
        interval: Check interval in seconds

    Returns:
        True if DNS propagated successfully

    Raises:
        DNSError: If timeout reached
    """
    import time
    import socket

    logger.info(f"Waiting for DNS propagation: {domain} -> {expected_ip}")

    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            resolved_ip = socket.gethostbyname(domain)
            if resolved_ip == expected_ip:
                elapsed = int(time.time() - start_time)
                logger.info(f"✓ DNS propagated successfully in {elapsed}s")
                return True
            else:
                logger.debug(f"DNS resolves to {resolved_ip}, expected {expected_ip}")
        except socket.gaierror:
            logger.debug(f"DNS not yet resolvable for {domain}")

        time.sleep(interval)

    raise DNSError(f"DNS propagation timeout after {timeout}s")
