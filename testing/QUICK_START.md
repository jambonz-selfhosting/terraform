# Quick Start Guide - Testing Framework

## Setup (One-Time)

### 1. Install Dependencies

```bash
cd testing
pip install -r requirements.txt
```

### 2. Configure DNS Credentials

Edit `config.yaml` and add your DNSMadeEasy credentials:

```yaml
dns:
  provider: dnsmadeeasy
  api_key: "your-api-key-here"
  secret: "your-secret-here"
  api_url: "https://api.dnsmadeeasy.com/V2.0"  # Optional, has default
```

Your SSH key should already be configured in the `ssh` section.

---

## Usage with GCP Deployment

### After `terraform apply`

Get the outputs:

```bash
cd ../gcp/provision-vm-medium
terraform output -json > /tmp/tf-outputs.json

# Or get specific values
PORTAL_URL=$(terraform output -raw portal_url | sed 's/http:\/\///')  # gcp.jambonz.io
WEB_IP=$(terraform output -raw web_monitoring_public_ip)              # 136.115.167.147
SBC_IP=$(terraform output -json sbc_public_ips | jq -r '.[0]')        # 34.44.168.210
```

### Test 1: Verify Startup Scripts

```bash
cd ../../testing

# Test public instances
python test_startup_scripts.py \
  --host $WEB_IP \
  --host $SBC_IP \
  --provider gcp \
  --config config.yaml

# Test private instances (Feature Server, Recording Server)
python test_startup_scripts.py \
  --host 172.20.10.6 \
  --host 172.20.10.4 \
  --jump-host $WEB_IP \
  --provider gcp \
  --config config.yaml
```

Expected result: ✅ All instances pass

### Test 2: Create DNS Records

```bash
# Using url_portal from terraform (recommended)
python test_dns.py create \
  --url-portal $PORTAL_URL \
  --web-ip $WEB_IP \
  --sbc-ip $SBC_IP \
  --config config.yaml

# Or manually specify subdomain
python test_dns.py create \
  --subdomain gcp \
  --base-domain jambonz.io \
  --web-ip $WEB_IP \
  --sbc-ip $SBC_IP \
  --config config.yaml
```

This creates 6 DNS A records:
- gcp.jambonz.io → 136.115.167.147
- api.gcp.jambonz.io → 136.115.167.147
- grafana.gcp.jambonz.io → 136.115.167.147
- homer.gcp.jambonz.io → 136.115.167.147
- public-apps.gcp.jambonz.io → 136.115.167.147
- sip.gcp.jambonz.io → 34.44.168.210

### Test 3: Verify DNS Propagation

```bash
# Wait a bit for DNS to propagate (1-5 minutes usually)
sleep 60

# Test DNS resolution
python test_dns.py test \
  --subdomain gcp \
  --web-ip $WEB_IP \
  --sbc-ip $SBC_IP
```

Expected result: ✅ All 6 records resolve correctly

### Test 4: Full Integration Test

```bash
# Run complete test suite
python test_cloud_init.py \
  --terraform-dir ../gcp/provision-vm-medium \
  --config config.yaml
```

This tests:
- ✅ Startup scripts completed
- ✅ PM2 services running
- ✅ All instances reachable

---

## One-Liner Commands

### Extract values from terraform and test everything

```bash
# Get terraform outputs
cd ../gcp/provision-vm-medium
PORTAL_URL=$(terraform output -raw portal_url | sed 's/http:\/\///')
WEB_IP=$(terraform output -raw web_monitoring_public_ip)
SBC_IP=$(terraform output -json sbc_public_ips | jq -r '.[0]')
cd ../../testing

# Test startup scripts
python test_startup_scripts.py --host $WEB_IP --host $SBC_IP --provider gcp

# Create DNS
python test_dns.py create --url-portal $PORTAL_URL --web-ip $WEB_IP --sbc-ip $SBC_IP

# Wait and test DNS
sleep 60 && python test_dns.py test --subdomain gcp --web-ip $WEB_IP --sbc-ip $SBC_IP
```

---

## Common Scenarios

### Scenario 1: Quick health check after deployment

```bash
# Just verify instances are up and configured
python test_cloud_init.py \
  --terraform-dir ../gcp/provision-vm-medium \
  --config config.yaml
```

### Scenario 2: Re-create DNS records

```bash
# Delete old records
python test_dns.py delete --subdomain gcp --yes

# Create new records
python test_dns.py create \
  --url-portal gcp.jambonz.io \
  --web-ip 136.115.167.147 \
  --sbc-ip 34.44.168.210
```

### Scenario 3: Test different cloud provider

```bash
# For Exoscale
python test_startup_scripts.py \
  --host 185.19.28.42 \
  --provider exoscale \
  --config config.yaml

# For Azure
python test_startup_scripts.py \
  --host 20.10.5.100 \
  --provider azure \
  --config config.yaml
```

### Scenario 4: Deploy + Test + Cleanup

```bash
# Full lifecycle (only if you want auto-cleanup after tests pass)
python test_cloud_init.py \
  --terraform-dir ../gcp/provision-vm-medium \
  --deploy \
  --cleanup-on-success \
  --config config.yaml
```

---

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connectivity first
python -c "
from pathlib import Path
import sys
sys.path.insert(0, str(Path('lib')))
from ssh_helper import test_ssh_connectivity
from config_loader import load_config
config = load_config('config.yaml')
test_ssh_connectivity('136.115.167.147', config['ssh'])
print('✅ SSH works!')
"
```

### DNS Not Propagating

```bash
# Check DNS manually
dig gcp.jambonz.io +short

# Or with nslookup
nslookup gcp.jambonz.io
```

### View Test Logs

```bash
# Watch logs in real-time
tail -f test-cloud-init.log

# Search logs
grep -i error test-cloud-init.log
grep -i failed test-cloud-init.log
```

### List Active Deployments

```bash
python list_deployments.py
```

### Cleanup

```bash
# Just the artifacts
python cleanup_deployment.py --state-file .test-state-gcp-20260121-xxxxx.yaml

# Artifacts + terraform destroy
python cleanup_deployment.py \
  --state-file .test-state-gcp-20260121-xxxxx.yaml \
  --destroy-terraform
```

---

## Tips

### Use Shell Variables

```bash
# Export once
export PORTAL_URL="gcp.jambonz.io"
export WEB_IP="136.115.167.147"
export SBC_IP="34.44.168.210"

# Reuse many times
python test_dns.py create --url-portal $PORTAL_URL --web-ip $WEB_IP --sbc-ip $SBC_IP
python test_dns.py test --subdomain gcp --web-ip $WEB_IP --sbc-ip $SBC_IP
```

### Monitor Progress

```bash
# Terminal 1: Run test
python test_cloud_init.py --terraform-dir ../gcp/provision-vm-medium --deploy

# Terminal 2: Watch logs
tail -f test-cloud-init.log
```

### Save Terraform Outputs

```bash
# Save outputs to file for later reference
terraform output -json > deployment-outputs.json

# Read back later
jq '.portal_url.value' deployment-outputs.json
```

---

## What's Next?

After DNS is working:

1. **Phase 3**: TLS certificates (certbot)
2. **Phase 4**: Webapp configuration (rebuild with https)
3. **Phase 5**: Portal automation (change passwords)
4. **Phase 6**: API provisioning (create test resources)

Each phase will have its own standalone test tool!
