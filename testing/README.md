# Jambonz Terraform Testing Framework

Automated testing framework for Jambonz terraform deployments. Verifies cloud-init completion, PM2 services, and provides lifecycle management for test deployments.

## Overview

This framework provides:

- **Modular Testing**: Build and test each component independently
- **Lifecycle Management**: Deploy → Test → Track → Cleanup workflow
- **Real-time Logging**: Monitor test progress with `tail -f`
- **State Tracking**: Track all artifacts for easy cleanup
- **Multi-provider Support**: Works with Exoscale, Azure, GCP, AWS

## Phase 1: Cloud-Init Verification (Current)

Phase 1 focuses on the fundamentals:
- ✅ SSH connectivity to all instances (including via jump hosts)
- ✅ Cloud-init completion verification
- ✅ PM2 service status checks
- ✅ Deployment state tracking
- ✅ Automated cleanup

**Future phases** will add DNS management, TLS certificates, webapp configuration, portal automation, and API provisioning.

## Quick Start

### 1. Installation

```bash
cd testing
pip install -r requirements.txt
```

### 2. Configuration

Copy the example config and customize for your environment:

```bash
cp config.example.yaml config.yaml
```

Edit `config.yaml` and set your SSH key path:

```yaml
ssh:
  user: jambonz
  key_path: ~/.ssh/id_rsa  # Path to your SSH private key
  strict_host_key_checking: false
  timeout: 300

testing:
  log_file: ./test-cloud-init.log
  abort_on_failure: true
```

### 3. Run Tests

#### Option A: Test Existing Deployment

If you've already run `terraform apply` manually:

```bash
python test_cloud_init.py \\
  --terraform-dir ../exoscale/provision-vm-medium \\
  --config config.yaml
```

#### Option B: Deploy + Test

Let the script run `terraform apply` then test:

```bash
python test_cloud_init.py \\
  --terraform-dir ../exoscale/provision-vm-medium \\
  --config config.yaml \\
  --deploy
```

#### Option C: Deploy + Test + Auto-Cleanup

Automatically cleanup if all tests pass:

```bash
python test_cloud_init.py \\
  --terraform-dir ../exoscale/provision-vm-medium \\
  --config config.yaml \\
  --deploy \\
  --cleanup-on-success
```

### 4. Monitor Progress

In another terminal, watch the log file in real-time:

```bash
tail -f testing/test-cloud-init.log
```

### 5. Cleanup

After testing, cleanup all artifacts:

```bash
# Cleanup artifacts only (leave infrastructure running)
python cleanup_deployment.py --state-file .test-state-exoscale-medium-20260119-123456.yaml

# Cleanup artifacts AND destroy terraform infrastructure
python cleanup_deployment.py --state-file .test-state-exoscale-medium-20260119-123456.yaml --destroy-terraform
```

### 6. List Active Deployments

View all active test deployments:

```bash
python list_deployments.py
```

Output:
```
Active Test Deployments:

Deployment ID                        Timestamp            Provider     Status     Cleanup Command
────────────────────────────────────────────────────────────────────────────────────────────────────
exoscale-medium-20260119-150000     2026-01-19 15:00:00  exoscale     ✓ success  cleanup_deployment.py --state-file .test-state-exoscale-medium-20260119-150000.yaml
azure-mini-20260119-140000          2026-01-19 14:00:00  azure        ✗ failed   cleanup_deployment.py --state-file .test-state-azure-mini-20260119-140000.yaml

Total: 2 deployment(s)
```

## Usage Examples

### Example 1: Quick Test of Existing Deployment

```bash
# You've already run terraform apply manually
cd exoscale/provision-vm-medium
terraform apply -var-file=test.tfvars -auto-approve

# Now test it
cd ../../testing
python test_cloud_init.py --terraform-dir ../exoscale/provision-vm-medium

# Output:
# ==============================================================
# Jambonz Cloud-Init Verification Test
# ==============================================================
#
# Provider: exoscale
# Variant: provision-vm-medium
# Terraform directory: ../exoscale/provision-vm-medium
#
# [Discovery Phase]
# Reading terraform outputs...
# ✓ Retrieved 12 terraform outputs
# ✓ Found 3 instance(s) to verify
#
# [Verification Phase]
# Testing instances...
#
# Testing web-monitoring (185.19.28.42)...
# ✓ web-monitoring: cloud-init completed successfully
# ✓ web-monitoring: 4 services online: api-server, webapp, grafana, homer
# ✓ web-monitoring: All checks passed
#
# Testing sbc-0 (185.19.28.99)...
# ✓ sbc-0: cloud-init completed successfully
# ✓ sbc-0: 3 services online: drachtio, rtpengine, sbc-sip-sidecar
# ✓ sbc-0: All checks passed
#
# Testing feature-server-0 (10.0.1.10)...
#   (via jump host 185.19.28.99)
# ✓ feature-server-0: cloud-init completed successfully
# ✓ feature-server-0: 2 services online: feature-server, freeswitch
# ✓ feature-server-0: All checks passed
#
# ==============================================================
# ✅ All tests passed - 3 instance(s) verified
# ==============================================================
#
# Summary:
#   Total instances: 3
#   Passed: 3
#   Failed: 0
#   Duration: 42.3 seconds
#
# State file: .test-state-exoscale-medium-20260119-150000.yaml
# Log file: ./test-cloud-init.log
#
# Deployment left running.
#
# To cleanup this deployment later, run:
#   python cleanup_deployment.py --state-file .test-state-exoscale-medium-20260119-150000.yaml
```

### Example 2: Full Lifecycle (Deploy → Test → Cleanup)

```bash
cd testing

# Deploy, test, and auto-cleanup on success
python test_cloud_init.py \\
  --terraform-dir ../azure/provision-vm-mini \\
  --config config.yaml \\
  --deploy \\
  --cleanup-on-success

# If tests pass, cleanup runs automatically
# If tests fail, deployment remains for debugging
```

### Example 3: Testing Multiple Variants

```bash
cd testing

# Test all variants sequentially
for variant in provision-vm-mini provision-vm-medium; do
  echo "Testing $variant..."
  python test_cloud_init.py \\
    --terraform-dir ../exoscale/$variant \\
    --config config.yaml \\
    --deploy \\
    --cleanup-on-success

  if [ $? -ne 0 ]; then
    echo "Tests failed for $variant - stopping"
    break
  fi
done
```

### Example 4: Using Custom Terraform Vars

```bash
python test_cloud_init.py \\
  --terraform-dir ../exoscale/provision-vm-medium \\
  --config config.yaml \\
  --deploy \\
  --var-file ../exoscale/provision-vm-medium/test.tfvars
```

## Command Reference

### test_cloud_init.py

Main test script for cloud-init verification.

**Options:**
- `--terraform-dir PATH` (required): Path to terraform directory
- `--config PATH`: Path to config file (default: config.yaml)
- `--deploy`: Run terraform apply before testing
- `--cleanup-on-success`: Auto-cleanup if tests pass (requires --deploy)
- `--var-file PATH`: Optional terraform vars file

**Exit codes:**
- 0: All tests passed
- 1: Tests failed
- 130: Interrupted by user

### cleanup_deployment.py

Cleanup deployment artifacts and optionally destroy infrastructure.

**Options:**
- `--state-file PATH` (required): Path to deployment state file
- `--destroy-terraform`: Also run terraform destroy
- `--auto-approve`: Skip confirmation prompts

**Examples:**
```bash
# Cleanup artifacts only
python cleanup_deployment.py --state-file .test-state-xyz.yaml

# Cleanup everything
python cleanup_deployment.py --state-file .test-state-xyz.yaml --destroy-terraform

# Non-interactive cleanup
python cleanup_deployment.py --state-file .test-state-xyz.yaml --destroy-terraform --auto-approve
```

### list_deployments.py

List all active test deployments.

**Options:**
- `--testing-dir PATH`: Directory to search for state files (default: current)

**Example:**
```bash
python list_deployments.py
```

## Configuration

### config.yaml Structure

```yaml
# SSH configuration
ssh:
  user: jambonz                     # SSH username
  key_path: ~/.ssh/id_rsa            # Path to SSH private key
  strict_host_key_checking: false    # Accept new host keys automatically
  timeout: 300                       # SSH command timeout in seconds

# Testing behavior
testing:
  log_file: ./test-cloud-init.log    # Log file path
  abort_on_failure: true             # Stop on first error

# Future phases will add:
# dns:
#   provider: dnsmadeeasy
#   api_key: ${DNSMADEEASY_API_KEY}  # From environment variable
#   secret: ${DNSMADEEASY_SECRET}
#   base_domain: jambonz.io
#
# certbot:
#   email: your-email@example.com
#
# jambonz_test_data:
#   carrier:
#     name: "Test Carrier"
```

### Environment Variables

Use environment variables for sensitive data:

```bash
# Example for future DNS phase
export DNSMADEEASY_API_KEY="your-api-key"
export DNSMADEEASY_SECRET="your-secret"
```

In config.yaml, reference with `${VAR_NAME}`:

```yaml
dns:
  api_key: ${DNSMADEEASY_API_KEY}
  secret: ${DNSMADEEASY_SECRET}
```

## Deployment State Files

Each test run creates a state file that tracks all information about the deployment:

**File naming:** `.test-state-<provider>-<variant>-<timestamp>.yaml`

**Example:** `.test-state-exoscale-medium-20260119-150000.yaml`

**Structure:**
```yaml
deployment_id: exoscale-medium-20260119-150000
timestamp: 2026-01-19T15:00:00Z
terraform_dir: /path/to/terraform/exoscale/provision-vm-medium
provider: exoscale
variant: provision-vm-medium

terraform:
  applied_by_script: true  # Was terraform apply run by the script?
  outputs:
    portal_url: exoscale.jambonz.io
    api_url: https://api.exoscale.jambonz.io
    # ... all terraform outputs

artifacts:
  dns_records: []          # Future: DNS records created
  tls_certificates: []     # Future: TLS certs generated
  api_resources: []        # Future: API resources created
  credentials: {}          # Future: Generated passwords

test_results:
  status: success          # success, failed, partial
  steps_completed:
    - cloud_init_verification
  duration_seconds: 42.3
```

**State files are:**
- Saved in the testing directory
- Added to .gitignore (not committed)
- Required for cleanup operations
- Preserved until explicit cleanup

## Architecture

### Module Structure

```
testing/
├── lib/
│   ├── config_loader.py          # YAML config with env var substitution
│   ├── logger.py                 # Dual logging (file + stdout)
│   ├── terraform_helper.py       # Terraform operations wrapper
│   ├── state_manager.py          # Deployment state tracking
│   ├── ssh_helper.py             # SSH connection wrapper
│   └── cloud_init_checker.py     # Cloud-init verification
│
├── test_cloud_init.py            # Main test script
├── cleanup_deployment.py         # Cleanup script
├── list_deployments.py           # List deployments
│
├── config.example.yaml           # Config template
├── config.yaml                   # User config (gitignored)
├── requirements.txt              # Python dependencies
└── README.md                     # This file
```

### Key Design Principles

1. **Modularity**: Each component is independent and reusable
2. **Testability**: Each tool can be tested on its own
3. **State Management**: Track everything for easy cleanup
4. **Real-time Feedback**: Dual logging for monitoring
5. **Provider Agnostic**: Works across cloud providers

## Troubleshooting

### SSH Connection Failures

**Problem:** Cannot connect to instances

**Solutions:**
1. Check your SSH key path in config.yaml
2. Ensure SSH key matches the one used by terraform
3. Verify security groups allow SSH (port 22)
4. For private instances, ensure jump host is accessible

### Cloud-Init Still Running

**Problem:** Script reports cloud-init not complete

**Solutions:**
1. Wait longer - cloud-init can take 5-10 minutes
2. Check instance console logs in cloud provider
3. SSH manually and check: `cloud-init status`
4. Review cloud-init logs: `cat /var/log/cloud-init-output.log`

### PM2 Services Not Running

**Problem:** Services shown as stopped or not found

**Solutions:**
1. Cloud-init may have failed - check logs
2. Check PM2 status manually: `ssh user@host pm2 list`
3. Restart services: `ssh user@host pm2 restart all`
4. Check application logs: `ssh user@host pm2 logs`

### Terraform Output Parsing Issues

**Problem:** Script can't find instances in terraform outputs

**Solutions:**
1. Check terraform outputs manually: `terraform output -json`
2. Ensure your terraform configuration exports required outputs
3. Look for outputs like: `ssh_commands`, `web_ip`, `sbc_ips`, etc.
4. Update `_identify_instances()` function if needed

### State File Issues

**Problem:** Can't load state file for cleanup

**Solutions:**
1. Check file exists: `ls -la .test-state-*.yaml`
2. Verify file format: `cat .test-state-xyz.yaml`
3. If corrupted, manually cleanup terraform: `terraform destroy`

## Future Phases

The framework is designed to grow incrementally:

### Phase 2: DNS Management
- Create DNS A records via DNSMadeEasy API
- Track records for cleanup
- Wait for DNS propagation

### Phase 3: TLS Certificates
- Run certbot via SSH
- Generate Let's Encrypt certificates
- Verify certificate installation

### Phase 4: Webapp Configuration
- Update .env file (http → https)
- Rebuild webapp (`npm run build`)
- Restart with PM2

### Phase 5: Portal Automation
- Browser automation (Playwright)
- Login and change admin password
- Verify portal accessibility

### Phase 6: API Provisioning
- Use Jambonz REST API
- Create test carriers, accounts, applications
- Track resources for cleanup

### Phase 7: Full Orchestration
- Combine all phases into single workflow
- Configurable step selection
- Comprehensive reporting

Each phase will:
- Add new modules to `lib/`
- Provide standalone test scripts
- Integrate with existing lifecycle management
- Maintain independent testability

## Contributing

When adding new features:

1. Create new modules in `lib/`
2. Add standalone test script (e.g., `test_dns.py`)
3. Update state tracking in `state_manager.py`
4. Add cleanup logic to `cleanup_deployment.py`
5. Update this README
6. Test independently before integration

## Support

For issues or questions:
- Check terraform logs: `terraform show`
- Check test logs: `cat test-cloud-init.log`
- Check state files: `cat .test-state-*.yaml`
- Review cloud provider console logs

## License

This testing framework is part of the Jambonz project.
