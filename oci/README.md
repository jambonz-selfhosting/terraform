# jambonz on Oracle Cloud Infrastructure (OCI)

This directory contains Terraform configurations for deploying jambonz on Oracle Cloud Infrastructure.

## Deployment Options

| Deployment | Description | Use Case |
|------------|-------------|----------|
| [provision-vm-mini](provision-vm-mini/) | Single all-in-one VM | Development, testing, small deployments |
| [provision-vm-medium](provision-vm-medium/) | Multi-VM with managed MySQL/Redis | Production, moderate traffic |
| [provision-vm-large](provision-vm-large/) | Scaled multi-VM cluster | High-volume production |

## OCI Authentication

All Terraform configurations use the OCI Terraform Provider, which requires API key authentication.

### Step 1: Install OCI CLI

```bash
# macOS
brew install oci-cli

# Linux
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"

# Verify installation
oci --version
```

### Step 2: Configure OCI CLI

Run the setup wizard to create your configuration and API key:

```bash
oci setup config
```

This will:
1. Create `~/.oci/config` with your credentials
2. Generate an API key pair (`~/.oci/oci_api_key.pem` and `~/.oci/oci_api_key_public.pem`)
3. Prompt you to upload the public key to OCI Console

When prompted, enter:
- **User OCID**: Found in OCI Console → Identity → Users → (your user) → OCID
- **Tenancy OCID**: Found in OCI Console → Administration → Tenancy Details → OCID
- **Region**: e.g., `us-ashburn-1`, `eu-frankfurt-1`
- **Generate a new API key**: Yes (recommended)

### Step 3: Upload API Public Key

If you generated a new key pair, upload the public key:

1. Go to **OCI Console** → **Identity & Security** → **Domains** → **Default** → **Users**
2. Click on your user
3. Under **Resources**, click **API Keys**
4. Click **Add API Key**
5. Select **Paste Public Key**
6. Paste the contents of `~/.oci/oci_api_key_public.pem`:
   ```bash
   cat ~/.oci/oci_api_key_public.pem
   ```
7. Click **Add**
8. Note the fingerprint shown (should match your `~/.oci/config`)

### Step 4: Create IAM Policy

Your user needs permissions to create OCI resources. Create a policy in the **root compartment**:

**Option A - Via OCI CLI** (recommended):

```bash
# Get your user OCID
USER_OCID=$(grep user ~/.oci/config | head -1 | cut -d= -f2 | tr -d ' ')

# Get your tenancy OCID
TENANCY_OCID=$(grep tenancy ~/.oci/config | head -1 | cut -d= -f2 | tr -d ' ')

# Create the policy
oci iam policy create \
  --compartment-id "$TENANCY_OCID" \
  --name "jambonz-admin-policy" \
  --description "Full admin access for jambonz deployment" \
  --statements "[\"Allow any-user to manage all-resources in tenancy where request.user.id = '$USER_OCID'\"]"
```

**Option B - Via OCI Console**:

1. Go to **Identity & Security** → **Policies**
2. Ensure you're in the **root compartment** (dropdown at left)
3. Click **Create Policy**
4. Name: `jambonz-admin-policy`
5. Description: `Full admin access for jambonz deployment`
6. Toggle to **Show manual editor**
7. Enter:
   ```
   Allow any-user to manage all-resources in tenancy where request.user.id = '<your-user-ocid>'
   ```
8. Click **Create**

**Option C - Minimal permissions** (more restrictive):

For tighter security, use these minimal permissions:

```
Allow any-user to read all-resources in tenancy where request.user.id = '<your-user-ocid>'
Allow any-user to manage virtual-network-family in tenancy where request.user.id = '<your-user-ocid>'
Allow any-user to manage instance-family in tenancy where request.user.id = '<your-user-ocid>'
Allow any-user to manage volume-family in tenancy where request.user.id = '<your-user-ocid>'
Allow any-user to manage object-family in tenancy where request.user.id = '<your-user-ocid>'
Allow any-user to manage mysql-family in tenancy where request.user.id = '<your-user-ocid>'
Allow any-user to manage redis-family in tenancy where request.user.id = '<your-user-ocid>'
```

### Step 5: Verify Authentication

Test that your credentials work:

```bash
# Should return your Object Storage namespace
oci os ns get

# Should list availability domains
oci iam availability-domain list --compartment-id <your-tenancy-ocid>
```

## Terraform Configuration

### Credential Variables

Each Terraform configuration requires these OCI credentials in `terraform.tfvars`:

```hcl
# OCI API Authentication
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaa..."     # From ~/.oci/config
user_ocid        = "ocid1.user.oc1..aaaaaa..."        # From ~/.oci/config
fingerprint      = "aa:bb:cc:dd:ee:ff:00:11:22:33..." # From ~/.oci/config
private_key_path = "~/.oci/oci_api_key.pem"           # Path to your private key
compartment_id   = "ocid1.compartment.oc1..aaaaaa..." # Target compartment (can be tenancy OCID)
region           = "us-ashburn-1"                      # Deployment region
```

**Finding your OCIDs:**

| Value | Location |
|-------|----------|
| `tenancy_ocid` | `~/.oci/config` or OCI Console → Administration → Tenancy Details |
| `user_ocid` | `~/.oci/config` or OCI Console → Identity → Users → (your user) |
| `fingerprint` | `~/.oci/config` or OCI Console → Identity → Users → API Keys |
| `compartment_id` | OCI Console → Identity → Compartments (use tenancy OCID for root) |

### Using ~/.oci/config Values

You can copy values directly from your OCI config file:

```bash
cat ~/.oci/config
```

Example output:
```ini
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaatmif3i77i2k5p45rr73xmneoznrkgo7vgmekvaferybsabiwcwhq
fingerprint=44:40:e6:37:51:d0:f1:e5:b0:92:b5:93:af:6a:06:95
key_file=/Users/yourname/.oci/oci_api_key.pem
tenancy=ocid1.tenancy.oc1..aaaaaaaajro2av74m4dng37ksglvst5sj5m3iskpjzq2nm4fto4c2p7df7hq
region=us-ashburn-1
```

Map these to terraform.tfvars:
- `user` → `user_ocid`
- `fingerprint` → `fingerprint`
- `key_file` → `private_key_path`
- `tenancy` → `tenancy_ocid` (and `compartment_id` if using root compartment)
- `region` → `region`

## jambonz Image Distribution

jambonz images for OCI are distributed via **Pre-Authenticated Request (PAR) URLs** from OCI Object Storage. This approach allows cross-tenancy image sharing without requiring Marketplace listings.

### How It Works

1. The jambonz team exports images to OCI Object Storage
2. PAR URLs are generated with read access
3. Terraform imports the image into your tenancy during deployment
4. The imported image is used to create instances

### Mini Deployment

The mini deployment includes a default PAR URL pointing to the official jambonz mini image. No additional configuration needed.

### Medium/Large Deployments

Medium and large deployments require separate images for each role:
- SBC (drachtio + rtpengine)
- Feature Server (FreeSWITCH)
- Web/Monitoring (portal, API, Grafana, Homer, Jaeger)
- Recording (optional)

Contact [support@jambonz.org](mailto:support@jambonz.org) for PAR URLs for multi-VM deployments.

## Supported Regions

jambonz can be deployed to any OCI region. The PAR URL for mini images is hosted in `us-ashburn-1` but images can be imported to any region.

Common regions:

| Americas | Europe | Asia Pacific |
|----------|--------|--------------|
| us-ashburn-1 | eu-frankfurt-1 | ap-tokyo-1 |
| us-phoenix-1 | eu-amsterdam-1 | ap-sydney-1 |
| us-sanjose-1 | uk-london-1 | ap-singapore-1 |
| ca-toronto-1 | eu-zurich-1 | ap-melbourne-1 |
| sa-saopaulo-1 | eu-madrid-1 | ap-osaka-1 |

See [OCI Regions](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) for the full list.

## Troubleshooting

### 401-NotAuthenticated Error

This error means OCI cannot verify your credentials:

1. **Check API key is uploaded**:
   ```bash
   # Get your fingerprint
   openssl rsa -pubout -in ~/.oci/oci_api_key.pem -outform DER 2>/dev/null | openssl md5 -c
   ```
   Verify this fingerprint exists in OCI Console under your user's API Keys.

2. **Check IAM policy exists**:
   ```bash
   oci iam policy list --compartment-id <tenancy-ocid> --all | grep jambonz
   ```

3. **Test with a simple API call**:
   ```bash
   oci os ns get
   ```
   If this fails, the issue is with your API key. If this works but Terraform fails, the issue is with IAM policies.

### "Shape not found" or Capacity Errors

Try a different availability domain or region:
```hcl
availability_domain_number = 2  # Try AD 2 instead of 1
```

Or change the compute shape:
```hcl
shape = "VM.Standard.E5.Flex"  # Try E5 instead of E4
```

### Image Import Timeout

Large images (15GB+) can take 20-30 minutes to import. The Terraform configuration includes a 30-minute timeout. If you still see timeouts:

1. Check if a partial import exists in OCI Console → Compute → Custom Images
2. Delete any failed imports and retry
3. Ensure your PAR URL hasn't expired

## Related Resources

- [OCI Documentation](https://docs.oracle.com/en-us/iaas/)
- [OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [OCI CLI Reference](https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/)
- [jambonz Documentation](https://docs.jambonz.org/)
