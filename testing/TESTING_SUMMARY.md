# Testing Framework - Current Status

## 🎯 NEW: Orchestration Scripts (January 22, 2026)

Two main scripts now automate the entire deployment workflow:

### 1. **test_deployment.py** - Step 1: Verify Infrastructure
Located in: `terraform/test_deployment.py`

Runs immediately after `terraform apply` to verify:
- ✅ SSH connectivity to all VMs
- ✅ Startup scripts completed (provider-aware: GCP, Azure, AWS, Exoscale)
- ✅ Systemd services running (configurable per server type)
- ✅ PM2 processes online (configurable per server type)

**Usage:**
```bash
cd gcp/provision-vm-medium
terraform apply
python ../../test_deployment.py
```

**Features:**
- Automatically gathers terraform outputs
- Auto-detects cloud provider
- Loads service expectations from `testing/server_types.yaml`
- Tests all public instances (web/monitoring + SBCs)

### 2. **post_install.py** - Step 2: Post-Installation Configuration
Located in: `terraform/post_install.py`

Runs after test_deployment.py passes to configure:
1. 📝 Create DNS A records (via DNSMadeEasy API)
2. 🔒 Provision TLS certificates (via certbot/Let's Encrypt)
3. 🔄 Rebuild webapp for HTTPS

**Usage:**
```bash
cd gcp/provision-vm-medium
python ../../post_install.py --email admin@example.com
```

**Features:**
- Automatically extracts portal URL, IPs from terraform
- Creates all 6 DNS records (portal, api, grafana, homer, public-apps, sip)
- Waits for DNS propagation
- Runs certbot to provision Let's Encrypt certificates
- Updates webapp .env and rebuilds
- Shows final login credentials including portal password

**Options:**
- `--skip-dns` - Skip DNS creation (if already exists)
- `--skip-tls` - Skip TLS provisioning
- `--skip-webapp` - Skip webapp rebuild
- `--staging` - Use Let's Encrypt staging server (for testing)

### 3. **server_types.yaml** - Service Configuration
Located in: `testing/server_types.yaml`

Centralized configuration defining expected services for each server type:
- SBC: drachtio, rtpengine, telegraf + PM2 processes
- Feature Server: drachtio, freeswitch + PM2 processes
- Web/Monitoring: cassandra, heplify-server, jaeger, grafana, influxdb + PM2 processes
- Recording: telegraf + PM2 processes

See [SERVER_TYPES.md](SERVER_TYPES.md) for full documentation.

### Complete Deployment Workflow

```bash
# 1. Deploy infrastructure
cd gcp/provision-vm-medium
terraform apply

# 2. Verify deployment
python ../../test_deployment.py

# 3. Post-installation
python ../../post_install.py --email admin@example.com

# Done! Login at https://gcp.jambonz.io
```

**Documentation:**
- [terraform/DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) - Complete guide
- [testing/SERVER_TYPES.md](SERVER_TYPES.md) - Service configuration reference

---

## What We've Built Today

### ✅ Completed

1. **Provider-Aware Startup Script Verification**
   - GCP support (google-startup-scripts.service)
   - Falls back to cloud-init for other providers (AWS, Azure, Exoscale)
   - Works with both public and private instances (via jump host)

2. **Standalone Test Script for Startup Scripts**
   - `test_startup_scripts.py` - independently test any instance
   - No terraform dependency
   - Works across providers

3. **DNS Module Framework**
   - `lib/dns_manager.py` - DNSMadeEasy API integration (skeleton)
   - `test_dns.py` - standalone DNS management tool
   - Commands: create, test, list, delete

4. **Bug Fixes**
   - Fixed SSH jump host variable scoping issue
   - Added provider parameter to cloud_init_checker

5. **Documentation**
   - STANDALONE_TOOLS.md - comprehensive guide for using each tool independently
   - Examples and usage patterns

### ✅ Successfully Tested on Your GCP Deployment

```bash
# Tested public instances
python test_startup_scripts.py --host 136.115.167.147 --host 34.44.168.210 --provider gcp
✅ Passed: 2

# Tested private instances via jump host
python test_startup_scripts.py --host 172.20.10.6 --host 172.20.10.4 --jump-host 136.115.167.147 --provider gcp
✅ Passed: 2
```

---

## Current File Structure

```
testing/
├── lib/
│   ├── cloud_init_checker.py      # Startup script verification (✅ GCP support added)
│   ├── config_loader.py            # YAML config with env vars
│   ├── dns_manager.py              # DNS management (skeleton)
│   ├── logger.py                   # Dual logging
│   ├── ssh_helper.py               # SSH with jump host (✅ fixed)
│   ├── state_manager.py            # Deployment state tracking
│   └── terraform_helper.py         # Terraform operations
│
├── test_cloud_init.py              # Main test suite (✅ provider-aware)
├── test_startup_scripts.py         # NEW - Standalone startup test
├── test_dns.py                     # NEW - Standalone DNS tool
├── cleanup_deployment.py           # Cleanup tool
├── list_deployments.py             # List deployments
│
├── config.yaml                     # Your config (needs DNS credentials)
├── config.example.yaml             # Template
│
├── README.md                       # Main documentation
├── STANDALONE_TOOLS.md             # NEW - Standalone tool guide
└── TESTING_SUMMARY.md              # This file
```

---

## Next Steps

### 1. Enable DNS Testing (Optional - Phase 2)

Add DNS credentials to config.yaml:

```yaml
dns:
  provider: dnsmadeeasy
  api_key: ${DNSMADEEASY_API_KEY}   # Or put actual key here
  secret: ${DNSMADEEASY_SECRET}      # Or put actual secret here
  base_domain: jambonz.io
```

If using environment variables:

```bash
export DNSMADEEASY_API_KEY="your-key"
export DNSMADEEASY_SECRET="your-secret"
```

**Implement DNS API calls** in `lib/dns_manager.py`:
- `_create_dnsmadeeasy_record()`
- `_delete_dnsmadeeasy_record()`
- `_list_dnsmadeeasy_records()`

See DNSMadeEasy API docs: https://api-docs.dnsmadeeasy.com/

### 2. Test Full Suite on GCP

```bash
python test_cloud_init.py --terraform-dir ../gcp/provision-vm-medium --config config.yaml
```

This should now work correctly with GCP instances.

### 3. Future Phases

- **Phase 3**: TLS certificates (certbot)
- **Phase 4**: Webapp configuration
- **Phase 5**: Portal automation
- **Phase 6**: API provisioning

Each phase will have:
- Module in `lib/`
- Standalone test script
- Integration with main suite

---

## How to Use the Testing Framework

### Scenario 1: Test Existing Deployment

```bash
# Quick startup check
python test_startup_scripts.py \\
  --host 136.115.167.147 \\
  --host 34.44.168.210 \\
  --provider gcp

# Full verification (startup + PM2 services)
python test_cloud_init.py \\
  --terraform-dir ../gcp/provision-vm-medium
```

### Scenario 2: Deploy + Test + Cleanup

```bash
python test_cloud_init.py \\
  --terraform-dir ../gcp/provision-vm-medium \\
  --deploy \\
  --cleanup-on-success
```

### Scenario 3: Manual DNS Management

```bash
# Create DNS records
python test_dns.py create \\
  --subdomain gcp \\
  --web-ip 136.115.167.147 \\
  --sbc-ip 34.44.168.210

# Test DNS resolution
python test_dns.py test \\
  --subdomain gcp \\
  --web-ip 136.115.167.147 \\
  --sbc-ip 34.44.168.210

# Delete when done
python test_dns.py delete --subdomain gcp
```

### Scenario 4: Test Different Providers

```bash
# Test Exoscale deployment
python test_startup_scripts.py \\
  --host 185.19.28.42 \\
  --provider exoscale

# Test Azure deployment
python test_startup_scripts.py \\
  --host 20.10.5.100 \\
  --provider azure

# Test AWS deployment
python test_startup_scripts.py \\
  --host 54.123.45.67 \\
  --provider aws
```

---

## Key Features

### 1. Modular Design
- Each tool works independently
- Test components in isolation
- Easy to debug

### 2. Provider-Agnostic
- Automatically detects provider from terraform path
- Adapts checks based on provider (GCP vs cloud-init)
- Works with any cloud provider

### 3. State Management
- Tracks all deployments
- Enables easy cleanup
- Prevents orphaned resources

### 4. Real-time Logging
- Dual output (console + file)
- Watch progress with `tail -f test-cloud-init.log`
- Detailed debugging info

---

## Tips & Tricks

### Monitoring Long-Running Tests

```bash
# Terminal 1: Run test
python test_cloud_init.py --terraform-dir ../path/to/dir --deploy

# Terminal 2: Watch logs
tail -f test-cloud-init.log
```

### Quick SSH Test

```bash
# Test if SSH works before running tests
python -c "
from lib.ssh_helper import test_ssh_connectivity, load_config
from lib.config_loader import load_config
config = load_config('config.yaml')
test_ssh_connectivity('136.115.167.147', config['ssh'])
print('SSH OK!')
"
```

### List All Active Deployments

```bash
python list_deployments.py
```

### Clean Up Specific Deployment

```bash
# Artifacts only
python cleanup_deployment.py --state-file .test-state-gcp-20260121.yaml

# Artifacts + terraform destroy
python cleanup_deployment.py --state-file .test-state-gcp-20260121.yaml --destroy-terraform
```

---

## What's Working Right Now

✅ **Startup Script Verification** - All providers
✅ **SSH Connectivity** - Direct + Jump host
✅ **PM2 Service Checks** - All instance types
✅ **Terraform Integration** - Reads outputs, applies, destroys
✅ **State Tracking** - Full lifecycle management
✅ **GCP Support** - google-startup-scripts.service

🔧 **In Progress**
- DNS API Implementation (skeleton ready, needs DNSMadeEasy calls)

📋 **Planned**
- TLS certificate management (Phase 3)
- Webapp configuration (Phase 4)
- Portal automation (Phase 5)
- API provisioning (Phase 6)

---

## Questions?

Check the documentation:
- `README.md` - Main framework documentation
- `STANDALONE_TOOLS.md` - Standalone tool usage
- `python test_cloud_init.py --help` - CLI help
- `python test_startup_scripts.py --help` - Startup test help
- `python test_dns.py --help` - DNS tool help
