## Standalone Testing Tools

Each phase of the Jambonz deployment testing can be tested independently. This allows you to:

1. **Test individual components** without running the full test suite
2. **Debug specific issues** in isolation
3. **Develop and test new features** incrementally
4. **Run tools manually** for operational tasks

---

## Available Standalone Tools

### 1. Startup Script Verification (`test_startup_scripts.py`)

**Purpose:** Verify that cloud-init or provider-specific startup scripts completed successfully on instances.

**Supports:** GCP (google-startup-scripts), AWS/Azure/Exoscale (cloud-init)

#### Usage Examples:

```bash
# Test public instances
python test_startup_scripts.py \\
  --host 136.115.167.147 \\
  --host 34.44.168.210 \\
  --provider gcp

# Test private instances via jump host
python test_startup_scripts.py \\
  --host 172.20.10.6 \\
  --host 172.20.10.4 \\
  --jump-host 136.115.167.147 \\
  --provider gcp

# Test with custom role names
python test_startup_scripts.py \\
  --host 136.115.167.147 \\
  --role web-monitoring \\
  --provider gcp
```

#### Options:

- `--host`: Instance IP/hostname (can specify multiple times)
- `--jump-host`: Jump host for private instances
- `--provider`: Cloud provider (gcp, aws, azure, exoscale)
- `--config`: Config file path (default: config.yaml)
- `--role`: Instance role name for logging

#### Output:

```
======================================================================
Startup Script Verification Test
======================================================================

Provider: gcp
Instances to test: 2

Testing instance-0 (136.115.167.147)...
  ✅ instance-0: GCP startup scripts completed successfully

Testing instance-1 (34.44.168.210)...
  ✅ instance-1: GCP startup scripts completed successfully

======================================================================
Summary
======================================================================
Total instances: 2
✅ Passed: 2
❌ Failed: 0
```

---

### 2. DNS Record Management (`test_dns.py`)

**Purpose:** Create, test, and delete DNS A records for Jambonz deployments.

**Supports:** DNSMadeEasy API

#### Usage Examples:

```bash
# Create DNS records (deletes existing first)
python test_dns.py create \\
  --subdomain gcp \\
  --web-ip 136.115.167.147 \\
  --sbc-ip 34.44.168.210 \\
  --config config.yaml

# Wait for DNS propagation after creation
python test_dns.py create \\
  --subdomain gcp \\
  --web-ip 136.115.167.147 \\
  --sbc-ip 34.44.168.210 \\
  --wait

# Test existing DNS records
python test_dns.py test \\
  --subdomain gcp \\
  --web-ip 136.115.167.147 \\
  --sbc-ip 34.44.168.210

# List all DNS records
python test_dns.py list --config config.yaml

# List filtered by subdomain
python test_dns.py list --subdomain gcp --config config.yaml

# Delete DNS records for subdomain
python test_dns.py delete --subdomain gcp --config config.yaml

# Delete without confirmation
python test_dns.py delete --subdomain gcp --yes
```

#### Commands:

- `create`: Create DNS A records (deletes existing first)
- `test`: Test if DNS records resolve correctly
- `list`: List existing DNS records
- `delete`: Delete DNS records for a subdomain

#### Options:

- `--subdomain`: Subdomain for deployment (e.g., "gcp", "azure-prod")
- `--web-ip`: Public IP for web/monitoring server
- `--sbc-ip`: Public IP for SBC (can specify multiple)
- `--config`: Config file path (default: config.yaml)
- `--ttl`: DNS TTL in seconds (default: 300)
- `--wait`: Wait for DNS propagation after creation
- `--yes`: Skip confirmation prompts

#### DNS Records Created:

For subdomain `gcp`:

- `gcp.jambonz.io` → web_ip
- `api.gcp.jambonz.io` → web_ip
- `grafana.gcp.jambonz.io` → web_ip
- `homer.gcp.jambonz.io` → web_ip
- `public-apps.gcp.jambonz.io` → web_ip
- `sip.gcp.jambonz.io` → sbc_ip

#### Output:

```
======================================================================
DNS Record Creation
======================================================================

✓ DNS manager initialized (provider: dnsmadeeasy)
  Base domain: jambonz.io

Creating 6 DNS records...

  Creating: gcp.jambonz.io -> 136.115.167.147
    ✅ Created (ID: 12345)
  Creating: api.gcp.jambonz.io -> 136.115.167.147
    ✅ Created (ID: 12346)
  ...

======================================================================
Summary: 6 created, 0 failed
======================================================================
```

---

### 3. Full Cloud-Init Test (`test_cloud_init.py`)

**Purpose:** Complete verification of deployment - discovers instances from Terraform, tests startup scripts and PM2 services.

**This is the main test script** that orchestrates everything.

#### Usage Examples:

```bash
# Test existing deployment
python test_cloud_init.py \\
  --terraform-dir ../gcp/provision-vm-medium \\
  --config config.yaml

# Deploy + test
python test_cloud_init.py \\
  --terraform-dir ../gcp/provision-vm-medium \\
  --deploy \\
  --config config.yaml

# Deploy + test + auto-cleanup on success
python test_cloud_init.py \\
  --terraform-dir ../gcp/provision-vm-medium \\
  --deploy \\
  --cleanup-on-success \\
  --config config.yaml
```

---

## Configuration

All standalone tools use the same `config.yaml` file:

```yaml
# SSH configuration
ssh:
  user: jambonz
  key_path: ~/.ssh/id_rsa
  strict_host_key_checking: false
  timeout: 300

# DNS configuration (for test_dns.py)
dns:
  provider: dnsmadeeasy
  api_key: ${DNSMADEEASY_API_KEY}
  secret: ${DNSMADEEASY_SECRET}
  base_domain: jambonz.io

# Testing behavior
testing:
  log_file: ./test-cloud-init.log
  abort_on_failure: true
```

### Environment Variables

Set sensitive credentials as environment variables:

```bash
export DNSMADEEASY_API_KEY="your-api-key"
export DNSMADEEASY_SECRET="your-secret"
```

---

## Integration with Full Test Suite

Standalone tools can be called from the main test suite:

```python
# In test_cloud_init.py or future orchestration script
from dns_manager import DNSManager

# After terraform apply
dns = DNSManager('dnsmadeeasy', dns_config)

for subdomain, ip in dns_records:
    dns.create_a_record(subdomain, ip)
```

---

## Adding New Standalone Tools

To add a new standalone tool (e.g., for TLS certificates):

1. **Create module** in `lib/` (e.g., `lib/certbot_manager.py`)
2. **Create standalone test** (e.g., `test_certbot.py`)
3. **Make it executable**: `chmod +x test_certbot.py`
4. **Test independently**: `python test_certbot.py --help`
5. **Update this README** with usage examples
6. **Integrate into main suite** when ready

### Template for New Tool:

```python
#!/usr/bin/env python3
"""
Standalone test for [FEATURE].

Usage:
    python test_[feature].py [OPTIONS]
"""

import sys
import click
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "lib"))

from config_loader import load_config
from [feature]_manager import [Feature]Manager

@click.command()
@click.option('--config', default='config.yaml')
def main(config):
    """Test [feature] functionality."""
    config_data = load_config(config)

    # Your test logic here
    pass

if __name__ == '__main__':
    main()
```

---

## Benefits of Standalone Tools

✅ **Independent Testing**: Test each component without full deployment
✅ **Faster Debugging**: Isolate and fix issues quickly
✅ **Operational Use**: Use tools for manual operations (e.g., DNS management)
✅ **Incremental Development**: Build and test features one at a time
✅ **CI/CD Friendly**: Run specific tests in different pipeline stages

---

## Testing Workflow

### Phase 1: Startup Scripts

```bash
# After terraform apply
python test_startup_scripts.py --host [IPs] --provider gcp
```

### Phase 2: DNS Records

```bash
# Create DNS records
python test_dns.py create --subdomain gcp --web-ip X --sbc-ip Y

# Test DNS resolution
python test_dns.py test --subdomain gcp --web-ip X --sbc-ip Y
```

### Phase 3: TLS Certificates (Future)

```bash
# Generate Let's Encrypt certs
python test_certbot.py generate --subdomain gcp --email you@example.com
```

### Phase 4: Full Integration

```bash
# Run complete test suite
python test_cloud_init.py --terraform-dir ../gcp/provision-vm-medium
```

---

## Exit Codes

All standalone tools use consistent exit codes:

- `0`: Success
- `1`: Test failed or error
- `130`: Interrupted by user (Ctrl+C)

This makes them easy to use in shell scripts and CI/CD pipelines.
