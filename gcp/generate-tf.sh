#!/usr/bin/env bash

# generate-tf.sh
# Script to copy jambonz public machine images to user's GCP project and generate terraform.tfvars
# Usage: ./generate-tf.sh
# Requires: gcloud CLI, yq

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# Backup Function
# ============================================================

# Creates a numbered backup of a file if it exists
# Usage: backup_file_if_exists "/path/to/file"
backup_file_if_exists() {
    local file="$1"

    if [ ! -f "$file" ]; then
        return 0  # No backup needed if file doesn't exist
    fi

    # Find the next available backup number
    local backup_num=1
    while [ -f "${file}.backup.${backup_num}" ]; do
        backup_num=$((backup_num + 1))
    done

    local backup_path="${file}.backup.${backup_num}"

    echo "  Existing terraform.tfvars found. Creating backup..."
    cp "$file" "$backup_path"
    echo "  Backup created: $backup_path"
    echo ""
}

# ============================================================
# Pre-flight Checks
# ============================================================

echo "================================================"
echo "jambonz GCP Terraform Generator"
echo "================================================"
echo ""

# Check if gcloud CLI is installed
if ! command -v gcloud &> /dev/null; then
    echo "ERROR: gcloud CLI not found"
    echo ""
    echo "Please install the Google Cloud SDK:"
    echo "  https://cloud.google.com/sdk/docs/install"
    echo ""
    echo "Installation instructions:"
    echo "  macOS:   brew install google-cloud-sdk"
    echo "  Linux:   curl https://sdk.cloud.google.com | bash"
    echo "  Windows: https://cloud.google.com/sdk/docs/install#windows"
    exit 1
fi

# Check if yq is installed (for parsing YAML)
if ! command -v yq &> /dev/null; then
    echo "ERROR: yq not found"
    echo ""
    echo "This script requires yq to parse YAML files."
    echo "Please install yq:"
    echo "  https://github.com/mikefarah/yq#install"
    echo ""
    echo "Installation instructions:"
    echo "  macOS:   brew install yq"
    echo "  Linux:   wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq"
    exit 1
fi

# Check if GCP credentials are configured
echo "Checking GCP authentication..."
if ! ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>&1); then
    echo "ERROR: Failed to check GCP authentication"
    echo ""
    echo "Please authenticate with GCP:"
    echo "  Run: gcloud auth login"
    echo ""
    echo "Error details:"
    echo "$ACTIVE_ACCOUNT"
    exit 1
fi

if [ -z "$ACTIVE_ACCOUNT" ]; then
    echo "ERROR: No active GCP account found"
    echo ""
    echo "Please authenticate with GCP:"
    echo "  Run: gcloud auth login"
    exit 1
fi

echo "Authenticated as: $ACTIVE_ACCOUNT"
echo ""

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -z "$CURRENT_PROJECT" ] || [ "$CURRENT_PROJECT" = "(unset)" ]; then
    echo "ERROR: No GCP project configured"
    echo ""
    echo "Please set a default project:"
    echo "  Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo "Current GCP project: $CURRENT_PROJECT"
echo ""

# ============================================================
# User Input
# ============================================================

# Deployment size
echo "Select deployment size:"
echo "  1) mini   - Single VM with all components (local MySQL, Redis, monitoring)"
echo "  2) medium - Multi-tier deployment (SBC, Feature Server, Web/Monitoring, Recording)"
echo "  3) large  - Fully separated architecture (SIP, RTP, Web, Monitoring)"
echo ""
read -p "Enter choice [1-3]: " SIZE_CHOICE

case $SIZE_CHOICE in
    1) SIZE="mini" ;;
    2) SIZE="medium" ;;
    3) SIZE="large" ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo "Selected: $SIZE"
echo ""

# Confirm target project
echo "Target GCP project: $CURRENT_PROJECT"
read -p "Is this correct? [Y/n]: " CONFIRM_PROJECT
CONFIRM_PROJECT=${CONFIRM_PROJECT:-Y}

if [[ ! "$CONFIRM_PROJECT" =~ ^[Yy]$ ]]; then
    read -p "Enter the target GCP project ID: " TARGET_PROJECT
    if [ -z "$TARGET_PROJECT" ]; then
        echo "ERROR: Project ID cannot be empty"
        exit 1
    fi
    # Verify the project exists and we have access
    if ! gcloud projects describe "$TARGET_PROJECT" &>/dev/null; then
        echo "ERROR: Cannot access project '$TARGET_PROJECT'"
        echo "Please verify the project ID and your permissions."
        exit 1
    fi
else
    TARGET_PROJECT="$CURRENT_PROJECT"
fi

echo "Target project: $TARGET_PROJECT"
echo ""

# GCP Region selection
echo "Select GCP region for deployment:"
echo ""
echo "Common regions:"
echo "  Americas:      us-central1, us-east1, us-west1, southamerica-east1"
echo "  Europe:        europe-west1, europe-west2, europe-north1"
echo "  Asia Pacific:  asia-east1, asia-southeast1, australia-southeast1"
echo ""
echo "Full list: https://cloud.google.com/compute/docs/regions-zones"
echo ""
read -p "Enter region (e.g., us-central1): " REGION

if [ -z "$REGION" ]; then
    echo "ERROR: Region cannot be empty"
    exit 1
fi

# Validate region exists
if ! gcloud compute regions describe "$REGION" --project="$TARGET_PROJECT" &>/dev/null; then
    echo "ERROR: Region '$REGION' not found or not accessible"
    echo "Please verify the region name."
    exit 1
fi

echo "Selected region: $REGION"
echo ""

# Zone selection
echo "Select zone within $REGION:"
AVAILABLE_ZONES=$(gcloud compute zones list --filter="region:$REGION" --format="value(name)" 2>/dev/null)
echo "Available zones:"
echo "$AVAILABLE_ZONES" | nl
echo ""
read -p "Enter zone (e.g., ${REGION}-a): " ZONE

if [ -z "$ZONE" ]; then
    ZONE="${REGION}-a"
    echo "Using default zone: $ZONE"
fi

# Validate zone exists
if ! gcloud compute zones describe "$ZONE" --project="$TARGET_PROJECT" &>/dev/null; then
    echo "ERROR: Zone '$ZONE' not found or not accessible"
    echo "Please verify the zone name."
    exit 1
fi

echo "Selected zone: $ZONE"
echo ""

# ============================================================
# Image Discovery
# ============================================================

echo "================================================"
echo "Resolving image families to latest images..."
echo "================================================"
echo ""

IMAGE_MAPPINGS_FILE="$SCRIPT_DIR/mappings/gcp-image-mappings.yaml"

if [ ! -f "$IMAGE_MAPPINGS_FILE" ]; then
    echo "ERROR: Cannot find gcp-image-mappings.yaml at $IMAGE_MAPPINGS_FILE"
    exit 1
fi

# Read source project
SOURCE_PROJECT=$(yq eval '.source_project' "$IMAGE_MAPPINGS_FILE")
if [ "$SOURCE_PROJECT" = "null" ] || [ -z "$SOURCE_PROJECT" ]; then
    echo "ERROR: source_project not defined in mappings file"
    exit 1
fi

echo "Source project: $SOURCE_PROJECT"
echo ""

# Read image family names based on deployment size
declare -a IMAGE_TYPES
declare -a IMAGE_FAMILIES
declare -a SOURCE_IMAGES

case $SIZE in
    mini)
        IMAGE_TYPES=("mini_image")
        ;;
    medium)
        IMAGE_TYPES=("sbc_image" "feature_server_image" "web_monitoring_image" "recording_image")
        ;;
    large)
        IMAGE_TYPES=("sip_image" "rtp_image" "web_image" "monitoring_image" "feature_server_image" "recording_image")
        ;;
esac

echo "Resolving image families to latest versions..."
echo ""

JAMBONZ_VERSION=""

for IMAGE_TYPE in "${IMAGE_TYPES[@]}"; do
    # Read the family name from mappings (e.g., sbc_image_family)
    FAMILY_NAME=$(yq eval ".${SIZE}.${IMAGE_TYPE}_family" "$IMAGE_MAPPINGS_FILE")
    if [ "$FAMILY_NAME" = "null" ] || [ -z "$FAMILY_NAME" ]; then
        echo "ERROR: Cannot find ${IMAGE_TYPE}_family for $SIZE deployment in mappings"
        exit 1
    fi
    IMAGE_FAMILIES+=("$FAMILY_NAME")

    echo "  Resolving $IMAGE_TYPE (family: $FAMILY_NAME)..."

    # Resolve family to latest image name
    IMAGE_NAME=$(gcloud compute images describe-from-family "$FAMILY_NAME" \
        --project="$SOURCE_PROJECT" \
        --format="value(name)" 2>&1)

    if [ $? -ne 0 ] || [ -z "$IMAGE_NAME" ]; then
        echo "    ERROR: Could not resolve family '$FAMILY_NAME' in project $SOURCE_PROJECT"
        echo ""
        echo "The image family may not exist or may not be publicly accessible."
        echo "Please verify the family exists:"
        echo "  gcloud compute images describe-from-family $FAMILY_NAME --project=$SOURCE_PROJECT"
        exit 1
    fi

    SOURCE_IMAGES+=("$IMAGE_NAME")

    # Parse version from image name (format: jambonz-{variant}-{version}-debian-12-{timestamp})
    # Example: jambonz-fs-v10-0-3-debian-12-20260130153138 (dots replaced with dashes for GCP)
    # Extract version like "v10-0-3" and convert back to "v10.0.3" for display
    VERSION_TAG=$(echo "$IMAGE_NAME" | sed -n 's/jambonz-[^-]*-\(v[0-9-]*\)-debian.*/\1/p' | sed 's/\([0-9]\)-\([0-9]\)/\1.\2/g')

    if [ -z "$VERSION_TAG" ]; then
        # Try old format without 'v' prefix (e.g., 094)
        VERSION_TAG=$(echo "$IMAGE_NAME" | sed -n 's/.*-\([0-9][0-9]*\)-debian.*/\1/p')
    fi

    if [ -z "$VERSION_TAG" ]; then
        echo "    Warning: Could not parse version from image name"
    else
        if [ -z "$JAMBONZ_VERSION" ]; then
            JAMBONZ_VERSION="$VERSION_TAG"
        fi
    fi

    echo "    Resolved to: $IMAGE_NAME (version: ${VERSION_TAG:-unknown})"
done

echo ""
echo "All source images verified"
if [ -n "$JAMBONZ_VERSION" ]; then
    echo "Detected jambonz version: $JAMBONZ_VERSION"
fi
echo ""

# ============================================================
# Image Copy
# ============================================================

echo "================================================"
echo "Copying images to your project..."
echo "================================================"
echo ""
echo "This will copy ${#IMAGE_TYPES[@]} image(s) to project: $TARGET_PROJECT"
echo "Note: GCP image copy is synchronous - each copy may take 1-5 minutes."
echo ""

START_TIME=$(date +%s)

declare -a NEW_IMAGE_NAMES

INDEX=0
for IMAGE_TYPE in "${IMAGE_TYPES[@]}"; do
    SOURCE_IMAGE="${SOURCE_IMAGES[$INDEX]}"

    echo "[$((INDEX + 1))/${#IMAGE_TYPES[@]}] Copying $IMAGE_TYPE..."
    echo "  Source: $SOURCE_PROJECT/$SOURCE_IMAGE"

    # Check if image already exists in target project
    if gcloud compute images describe "$SOURCE_IMAGE" --project="$TARGET_PROJECT" &>/dev/null; then
        echo "  Image already exists in target project, skipping copy"
        NEW_IMAGE_NAMES+=("$SOURCE_IMAGE")
        INDEX=$((INDEX + 1))
        continue
    fi

    # Copy the image
    COPY_RESULT=$(gcloud compute images create "$SOURCE_IMAGE" \
        --project="$TARGET_PROJECT" \
        --source-image="$SOURCE_IMAGE" \
        --source-image-project="$SOURCE_PROJECT" \
        --labels="jambonz-version=${JAMBONZ_VERSION:-unknown},deployment-size=$SIZE,managed-by=jambonz-terraform,source-project=$SOURCE_PROJECT" \
        --description="Copied from jambonz public image $SOURCE_IMAGE for self-hosting" \
        2>&1)

    COPY_EXIT_CODE=$?

    if [ $COPY_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "ERROR: Failed to copy image $SOURCE_IMAGE"
        echo ""
        echo "Error details:"
        echo "$COPY_RESULT"
        echo ""

        # Check for common errors
        if echo "$COPY_RESULT" | grep -qi "permission"; then
            echo "This may be a permissions issue. Ensure:"
            echo "  1. The source images are publicly accessible"
            echo "  2. You have compute.images.create permission in project $TARGET_PROJECT"
        fi

        exit 1
    fi

    NEW_IMAGE_NAMES+=("$SOURCE_IMAGE")
    echo "  Copied successfully"
    echo ""

    INDEX=$((INDEX + 1))
done

TOTAL_TIME=$(($(date +%s) - START_TIME))
echo "================================================"
echo "All ${#IMAGE_TYPES[@]} image(s) copied successfully!"
echo "Total time: ${TOTAL_TIME}s ($((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s)"
echo "================================================"
echo ""

# ============================================================
# Generate terraform.tfvars
# ============================================================

echo "================================================"
echo "Generating terraform.tfvars..."
echo "================================================"
echo ""

TERRAFORM_DIR="$SCRIPT_DIR/provision-vm-${SIZE}"
OUTPUT_FILE="$TERRAFORM_DIR/terraform.tfvars"

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "ERROR: Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

# Backup existing terraform.tfvars if it exists
backup_file_if_exists "$OUTPUT_FILE"

# Generate the terraform.tfvars file
cat > "$OUTPUT_FILE" << EOF
# Generated by generate-tf.sh on $(date +%Y-%m-%d)
# jambonz version: ${JAMBONZ_VERSION:-unknown}
# Source images from: $SOURCE_PROJECT

# ------------------------------------------------------------------------------
# GCP PROJECT CONFIGURATION
# ------------------------------------------------------------------------------

project_id = "$TARGET_PROJECT"
region     = "$REGION"
zone       = "$ZONE"

# ------------------------------------------------------------------------------
# DEPLOYMENT CONFIGURATION
# ------------------------------------------------------------------------------

name_prefix = "jambonz"
environment = "production"

# ------------------------------------------------------------------------------
# NETWORK CONFIGURATION
# ------------------------------------------------------------------------------

EOF

# Add size-specific VPC CIDR
if [ "$SIZE" = "mini" ]; then
    echo 'vpc_cidr           = "10.0.0.0/16"' >> "$OUTPUT_FILE"
    echo 'public_subnet_cidr = "10.0.0.0/24"' >> "$OUTPUT_FILE"
else
    echo 'vpc_cidr           = "172.20.0.0/16"' >> "$OUTPUT_FILE"
    echo 'public_subnet_cidr = "172.20.10.0/24"' >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" << 'EOF'

# ------------------------------------------------------------------------------
# NETWORK ACCESS CONTROLS
# ------------------------------------------------------------------------------

allowed_ssh_cidr  = ["0.0.0.0/0"]
allowed_http_cidr = ["0.0.0.0/0"]
EOF

# Add size-specific network access controls
if [ "$SIZE" = "mini" ]; then
    echo 'allowed_sip_cidr  = ["0.0.0.0/0"]' >> "$OUTPUT_FILE"
elif [ "$SIZE" = "medium" ]; then
    echo 'allowed_sbc_cidr  = ["0.0.0.0/0"]' >> "$OUTPUT_FILE"
elif [ "$SIZE" = "large" ]; then
    echo 'allowed_sip_cidr  = ["0.0.0.0/0"]' >> "$OUTPUT_FILE"
    echo 'allowed_rtp_cidr  = ["0.0.0.0/0"]' >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" << 'EOF'

# ------------------------------------------------------------------------------
# IMAGE CONFIGURATION (copied to your project)
# ------------------------------------------------------------------------------

EOF

# Add image variables dynamically
INDEX=0
for IMAGE_TYPE in "${IMAGE_TYPES[@]}"; do
    IMAGE_NAME="${NEW_IMAGE_NAMES[$INDEX]}"
    # Convert IMAGE_TYPE to terraform variable format (already correct)
    echo "${IMAGE_TYPE} = \"projects/${TARGET_PROJECT}/global/images/${IMAGE_NAME}\"" >> "$OUTPUT_FILE"
    INDEX=$((INDEX + 1))
done

# Add size-specific configuration
if [ "$SIZE" = "mini" ]; then
cat >> "$OUTPUT_FILE" << 'EOF'

# ------------------------------------------------------------------------------
# MACHINE TYPE CONFIGURATION
# ------------------------------------------------------------------------------

machine_type = "e2-standard-4"

disk_size = 100

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------

ssh_user       = "jambonz"
ssh_public_key = "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY"

# ------------------------------------------------------------------------------
# JAMBONZ CONFIGURATION
# ------------------------------------------------------------------------------

# Leave empty to access by IP address, or set to your domain name
url_portal = "REPLACE_WITH_YOUR_DOMAIN"
EOF
elif [ "$SIZE" = "medium" ]; then
cat >> "$OUTPUT_FILE" << 'EOF'

# ------------------------------------------------------------------------------
# MACHINE TYPE CONFIGURATION
# ------------------------------------------------------------------------------

sbc_machine_type            = "e2-standard-2"
feature_server_machine_type = "e2-standard-2"
web_monitoring_machine_type = "e2-standard-2"
recording_machine_type      = "e2-standard-2"

web_monitoring_disk_size = 200

# ------------------------------------------------------------------------------
# SBC CONFIGURATION
# ------------------------------------------------------------------------------

sbc_count = 1

# ------------------------------------------------------------------------------
# MANAGED INSTANCE GROUP CONFIGURATION
# ------------------------------------------------------------------------------

feature_server_target_size  = 1
feature_server_min_replicas = 1
feature_server_max_replicas = 3

recording_target_size  = 1
recording_min_replicas = 1
recording_max_replicas = 3

scale_in_timeout_seconds = 900

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------

ssh_user       = "jambonz"
ssh_public_key = "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY"

# ------------------------------------------------------------------------------
# DATABASE CONFIGURATION
# ------------------------------------------------------------------------------

mysql_tier      = "db-custom-2-4096"
mysql_disk_size = 20

# ------------------------------------------------------------------------------
# REDIS CONFIGURATION
# ------------------------------------------------------------------------------

redis_memory_size_gb = 1
redis_tier           = "BASIC"

# ------------------------------------------------------------------------------
# JAMBONZ CONFIGURATION
# ------------------------------------------------------------------------------

url_portal               = "REPLACE_WITH_YOUR_DOMAIN"
enable_pcaps             = true
deploy_recording_cluster = true
EOF
elif [ "$SIZE" = "large" ]; then
cat >> "$OUTPUT_FILE" << 'EOF'

# ------------------------------------------------------------------------------
# MACHINE TYPE CONFIGURATION
# ------------------------------------------------------------------------------

sip_machine_type            = "e2-standard-2"
rtp_machine_type            = "e2-standard-2"
web_machine_type            = "e2-standard-4"
monitoring_machine_type     = "e2-standard-4"
feature_server_machine_type = "e2-standard-4"
recording_machine_type      = "e2-standard-2"

monitoring_disk_size = 200

# ------------------------------------------------------------------------------
# SIP/RTP CONFIGURATION
# ------------------------------------------------------------------------------

sip_count = 1
rtp_count = 1

# ------------------------------------------------------------------------------
# MANAGED INSTANCE GROUP CONFIGURATION
# ------------------------------------------------------------------------------

feature_server_target_size  = 1
feature_server_min_replicas = 1
feature_server_max_replicas = 8

recording_target_size  = 1
recording_min_replicas = 1
recording_max_replicas = 8

scale_in_timeout_seconds = 900

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------

ssh_user       = "jambonz"
ssh_public_key = "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY"

# ------------------------------------------------------------------------------
# DATABASE CONFIGURATION
# ------------------------------------------------------------------------------

mysql_tier      = "db-custom-2-4096"
mysql_disk_size = 20

# ------------------------------------------------------------------------------
# REDIS CONFIGURATION
# ------------------------------------------------------------------------------

redis_memory_size_gb = 1
redis_tier           = "BASIC"

# ------------------------------------------------------------------------------
# JAMBONZ CONFIGURATION
# ------------------------------------------------------------------------------

url_portal               = "REPLACE_WITH_YOUR_DOMAIN"
enable_pcaps             = true
deploy_recording_cluster = true
EOF
fi

echo "Generated: $OUTPUT_FILE"
echo ""

# ============================================================
# Success Output
# ============================================================

echo "================================================"
echo "SUCCESS!"
echo "================================================"
echo ""
echo "Copied images (in project $TARGET_PROJECT):"
INDEX=0
for IMAGE_TYPE in "${IMAGE_TYPES[@]}"; do
    IMAGE_NAME="${NEW_IMAGE_NAMES[$INDEX]}"
    echo "  $IMAGE_TYPE: projects/$TARGET_PROJECT/global/images/$IMAGE_NAME"
    INDEX=$((INDEX + 1))
done
echo ""

echo "Generated terraform.tfvars:"
echo "  $OUTPUT_FILE"
echo ""

echo "================================================"
echo "Next Steps"
echo "================================================"
echo ""
echo "1. Edit terraform.tfvars to configure required values:"
echo "   - ssh_public_key: Your SSH public key for VM access"
echo "   - url_portal: Your domain name (e.g., jambonz.example.com)"
echo ""
echo "   nano $OUTPUT_FILE"
echo ""
echo "2. Initialize and deploy with Terraform:"
echo ""
echo "   cd $TERRAFORM_DIR"
echo "   terraform init"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "3. After deployment, configure DNS records as shown in Terraform outputs"
echo ""
echo "================================================"
