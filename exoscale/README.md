# Deploying jambonz on Exoscale

## Overview

Exoscale VM deployments use pre-built qcow2 disk images that contain all jambonz components. Unlike AWS or GCP where public AMIs/images can be shared directly, Exoscale requires each user to register VM templates into their own account before they can be used by Terraform. This is a one-time setup step per version per zone.

The workflow is:

1. **Register templates** into your Exoscale account using `prepare-images.sh`
2. **Configure** your deployment by editing `terraform.tfvars`
3. **Deploy** with `terraform apply`

## Prerequisites

- [Exoscale CLI](https://github.com/exoscale/cli) (`exo`) installed and configured
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- An Exoscale account with API credentials

### Configure the Exoscale CLI

```bash
# Install
brew install exoscale-cli    # macOS
# or: https://github.com/exoscale/cli/releases

# Configure with your API key and secret
exo config
```

## Deployment Sizes

| Size | Description | VMs | Images Required |
|------|-------------|-----|-----------------|
| **mini** | All-in-one single VM | 1 | `mini` |
| **medium** | Separate SBC, feature server, web/monitoring, recording | 4+ | `sip-rtp`, `fs`, `web-monitoring`, `recording` |
| **large** | Fully separated SIP, RTP, FS, web, monitoring, recording | 6+ | `sip`, `rtp`, `fs`, `web`, `monitoring`, `recording` |

## Step 1: Register Templates

The `prepare-images.sh` script downloads jambonz qcow2 images from Exoscale SOS (object storage) and registers them as private templates in your account. You only need to do this once per jambonz version per zone.

```bash
cd exoscale/
./prepare-images.sh
```

The script will prompt you to:
1. Select a deployment size (mini, medium, or large)
2. Select the Exoscale zone where you want to deploy

It then checks for existing templates, downloads checksums, and registers any missing templates. For medium and large deployments, multiple templates are registered in parallel.

### Options

Generally, you should run the script with no arguments, however the following options do exist:

```bash
# Register a specific version
./prepare-images.sh --version 10.0.4

# Use AWS S3 as image source instead of Exoscale SOS (slower, but works without SOS setup)
./prepare-images.sh --from-s3

# Specify which SOS zone hosts the images (default: ch-gva-2)
./prepare-images.sh --sos-zone ch-gva-2
```

Registration typically takes 5-20 minutes depending on image size. The script is idempotent -- it skips templates that are already registered.

### Available Zones

- `ch-gva-2` -- Geneva, Switzerland
- `ch-dk-2` -- Zurich, Switzerland
- `de-fra-1` -- Frankfurt, Germany
- `de-muc-1` -- Munich, Germany
- `at-vie-1` -- Vienna, Austria
- `at-vie-2` -- Vienna, Austria
- `bg-sof-1` -- Sofia, Bulgaria

## Step 2: Configure Terraform

```bash
cd exoscale/provision-vm-mini/   # or provision-vm-medium/ or provision-vm-large/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:

- **Exoscale credentials** (mini uses tfvars; medium/large use environment variables)
- **Zone** -- must match the zone where you registered templates
- **SSH public key** -- your public key content for SSH access
- **Network CIDRs** -- restrict SSH/HTTP/SIP access as needed
- **Portal URL** -- the domain name for the jambonz web portal

For medium and large deployments, set your credentials via environment variables:

```bash
export EXOSCALE_API_KEY="your-key"
export EXOSCALE_API_SECRET="your-secret"
```

## Step 3: Deploy

```bash
terraform init
terraform plan     # review what will be created
terraform apply    # create the infrastructure
```

After `terraform apply` completes, the output will show:
- Server IP address(es)
- Portal URL and credentials
- DNS records to create
- SSH connection commands

## Step 4: Post-Deployment

### Create DNS Records

Point the following DNS A records to the server IP shown in the terraform output:

- `your-domain.com`
- `api.your-domain.com`
- `grafana.your-domain.com`
- `homer.your-domain.com`
- `sip.your-domain.com`

### Verify the Deployment

```bash
# From the terraform directory
python ../../test_deployment.py
```

### Configure TLS and Webapp

```bash
python ../../post_install.py --email your-email@example.com
```

## Cleanup

```bash
terraform destroy
```

This removes all Exoscale resources (VMs, security groups, SSH keys, etc.) but does not delete the registered templates. Templates can be reused for future deployments.
