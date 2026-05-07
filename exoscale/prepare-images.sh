#!/usr/bin/env bash

# prepare-images.sh
# Script to register jambonz qcow2 images into your Exoscale account
# Run this once before terraform apply to make templates available
# Usage: ./prepare-images.sh [--version X.Y.Z] [--sos-zone ZONE]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
DEFAULT_VERSION="10.0.4"
SOS_BUCKET="jambonz-images"
SOS_ZONE="ch-gva-2"
S3_FALLBACK_URL="https://jambonz-qcow2-images.s3.us-east-1.amazonaws.com"

ZONES=(
  "ch-gva-2"
  "ch-dk-2"
  "de-fra-1"
  "de-muc-1"
  "at-vie-1"
  "at-vie-2"
  "bg-sof-1"
)

# Temp directory for registration logs
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# ============================================================
# Parse Arguments
# ============================================================

VERSION="$DEFAULT_VERSION"
USE_S3_FALLBACK=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --sos-zone)
      SOS_ZONE="$2"
      shift 2
      ;;
    --from-s3)
      USE_S3_FALLBACK=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--version X.Y.Z] [--sos-zone ZONE] [--from-s3]"
      echo ""
      echo "Register jambonz qcow2 images into your Exoscale account."
      echo ""
      echo "Options:"
      echo "  --version X.Y.Z   Jambonz version to register (default: $DEFAULT_VERSION)"
      echo "  --sos-zone ZONE   SOS zone where images are hosted (default: $SOS_ZONE)"
      echo "  --from-s3         Use AWS S3 as image source instead of Exoscale SOS (slower)"
      echo "  --help, -h         Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage"
      exit 1
      ;;
  esac
done

# Determine image source URL
if [ "$USE_S3_FALLBACK" = true ]; then
  BASE_URL="$S3_FALLBACK_URL"
  IMAGE_SOURCE="AWS S3 (us-east-1) — this will be slow for large images"
else
  BASE_URL="https://sos-${SOS_ZONE}.exo.io/${SOS_BUCKET}"
  IMAGE_SOURCE="Exoscale SOS (${SOS_ZONE})"
fi

# ============================================================
# Pre-flight Checks
# ============================================================

echo "================================================"
echo "jambonz Exoscale Image Preparation"
echo "================================================"
echo ""

# Check exo CLI
if ! command -v exo &> /dev/null; then
  echo "ERROR: Exoscale CLI (exo) not found"
  echo ""
  echo "Please install the Exoscale CLI:"
  echo "  macOS:   brew install exoscale-cli"
  echo "  Linux:   curl -fsSL https://raw.githubusercontent.com/exoscale/cli/master/install.sh | sh"
  echo "  Other:   https://github.com/exoscale/cli/releases"
  echo ""
  echo "After installing, configure your account:"
  echo "  exo config"
  exit 1
fi

# Check curl
if ! command -v curl &> /dev/null; then
  echo "ERROR: curl not found. Please install curl."
  exit 1
fi

# Check exo account
echo "Checking Exoscale credentials..."
if ! ACCOUNT_INFO=$(exo config show 2>&1); then
  echo "ERROR: Exoscale CLI not configured"
  echo ""
  echo "Please configure your Exoscale account:"
  echo "  exo config"
  echo ""
  echo "You'll need your API key and secret from:"
  echo "  https://portal.exoscale.com/iam/api-keys"
  echo ""
  echo "Error details:"
  echo "$ACCOUNT_INFO"
  exit 1
fi

echo "  Exoscale CLI configured"
echo ""

# ============================================================
# User Input
# ============================================================

# Deployment size
echo "Select deployment size:"
echo "  1) mini   - Single VM with all components"
echo "  2) medium - Multi-VM (SBC, Feature Server, Web/Monitoring, Recording, Database)"
echo "  3) large  - Fully separated (SIP, RTP, FS, Web, Monitoring, Recording, Database)"
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

# Zone selection
echo "Select Exoscale zone:"
for i in "${!ZONES[@]}"; do
  echo "  $((i + 1))) ${ZONES[$i]}"
done
echo ""
read -p "Enter choice [1-${#ZONES[@]}]: " ZONE_CHOICE

if [[ "$ZONE_CHOICE" -lt 1 || "$ZONE_CHOICE" -gt "${#ZONES[@]}" ]]; then
  echo "Invalid choice. Please run the script again."
  exit 1
fi

ZONE="${ZONES[$((ZONE_CHOICE - 1))]}"
echo "Selected zone: $ZONE"
echo ""

# ============================================================
# Determine Image Variants
# ============================================================

case $SIZE in
  mini)
    VARIANTS=("mini")
    ;;
  medium)
    VARIANTS=("sip-rtp" "fs" "web-monitoring" "recording" "db")
    ;;
  large)
    VARIANTS=("sip" "rtp" "fs" "web" "monitoring" "recording" "db")
    ;;
esac

echo "================================================"
echo "Configuration"
echo "================================================"
echo "  Size:    $SIZE"
echo "  Zone:    $ZONE"
echo "  Version: v$VERSION"
echo "  Source:  $IMAGE_SOURCE"
echo "  Images:  ${#VARIANTS[@]} template(s) to register"
echo ""

for VARIANT in "${VARIANTS[@]}"; do
  echo "    - jambonz-${VARIANT}-v${VERSION}"
done
echo ""

read -p "Proceed? [Y/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn] ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

# ============================================================
# Check for Existing Templates
# ============================================================

echo "================================================"
echo "Checking for existing templates..."
echo "================================================"
echo ""

VARIANTS_TO_REGISTER=()
ALREADY_REGISTERED=()

for VARIANT in "${VARIANTS[@]}"; do
  TEMPLATE_NAME="jambonz-${VARIANT}-v${VERSION}"

  if exo compute instance-template show "$TEMPLATE_NAME" --zone "$ZONE" &> /dev/null; then
    echo "  $TEMPLATE_NAME: already registered (skipping)"
    ALREADY_REGISTERED+=("$TEMPLATE_NAME")
  else
    echo "  $TEMPLATE_NAME: not found (will register)"
    VARIANTS_TO_REGISTER+=("$VARIANT")
  fi
done

echo ""

if [ ${#VARIANTS_TO_REGISTER[@]} -eq 0 ]; then
  echo "================================================"
  echo "All templates already registered!"
  echo "================================================"
  echo ""
  echo "You can proceed with terraform:"
  echo "  cd exoscale/provision-vm-${SIZE}/"
  echo "  terraform init"
  echo "  terraform plan"
  echo "  terraform apply"
  exit 0
fi

echo "${#VARIANTS_TO_REGISTER[@]} template(s) to register, ${#ALREADY_REGISTERED[@]} already exist"
echo ""

# ============================================================
# Download and Validate All Checksums First
# ============================================================

echo "================================================"
echo "Downloading checksums..."
echo "================================================"
echo ""

CHECKSUM_VALUES=()

for VARIANT in "${VARIANTS_TO_REGISTER[@]}"; do
  TEMPLATE_NAME="jambonz-${VARIANT}-v${VERSION}"
  CHECKSUM_URL="${BASE_URL}/jambonz-${VARIANT}-v${VERSION}.md5sum"

  if ! MD5=$(curl -sf "$CHECKSUM_URL" 2>&1) || [ -z "$MD5" ]; then
    echo "  ERROR: Failed to download checksum for $TEMPLATE_NAME"
    echo "  URL: $CHECKSUM_URL"
    echo "  Please verify the image exists for version $VERSION"
    if [ "$USE_S3_FALLBACK" = false ]; then
      echo ""
      echo "  If images haven't been uploaded to SOS yet, try:"
      echo "    $0 --from-s3    (uses AWS S3 — slower but no SOS setup needed)"
    fi
    exit 1
  fi

  MD5=$(echo "$MD5" | awk '{print $1}')
  CHECKSUM_VALUES+=("$MD5")
  echo "  $TEMPLATE_NAME: $MD5"
done

echo ""
echo "All checksums validated."
echo ""

# ============================================================
# Register Templates (parallel for multi-image deployments)
# ============================================================

echo "================================================"
echo "Registering templates..."
echo "================================================"
echo ""

NUM_TO_REGISTER=${#VARIANTS_TO_REGISTER[@]}

if [ $NUM_TO_REGISTER -eq 1 ]; then
  echo "Registering 1 template. This typically takes 5-20 minutes."
else
  echo "Registering $NUM_TO_REGISTER templates in parallel."
  echo "This typically takes 5-20 minutes (all images download simultaneously)."
fi
echo ""
echo "IMPORTANT: Do not press Ctrl+C! Interrupting may leave templates"
echo "           in a partial state that requires manual cleanup."
echo ""
echo "To monitor progress in another terminal:"
echo "  exo compute instance-template list --zone $ZONE | grep jambonz"
echo ""

START_TIME=$(date +%s)
PIDS=()
PID_VARIANTS=()

# Launch all registrations
for i in "${!VARIANTS_TO_REGISTER[@]}"; do
  VARIANT="${VARIANTS_TO_REGISTER[$i]}"
  TEMPLATE_NAME="jambonz-${VARIANT}-v${VERSION}"
  IMAGE_URL="${BASE_URL}/jambonz-${VARIANT}-v${VERSION}.qcow2"
  MD5="${CHECKSUM_VALUES[$i]}"
  LOG_FILE="${TMPDIR}/${VARIANT}.log"
  EXIT_FILE="${TMPDIR}/${VARIANT}.exit"

  echo "  Starting: $TEMPLATE_NAME"

  # Run registration in background, capture output and exit code
  (
    exo compute instance-template register \
      "$TEMPLATE_NAME" \
      "$IMAGE_URL" \
      "$MD5" \
      --zone "$ZONE" \
      --boot-mode legacy \
      --disable-password \
      --username jambonz \
      --description "jambonz ${VARIANT} v${VERSION}" \
      > "$LOG_FILE" 2>&1
    echo $? > "$EXIT_FILE"
  ) &

  PIDS+=($!)
  PID_VARIANTS+=("$VARIANT")
done

echo ""
echo "All $NUM_TO_REGISTER registration(s) launched."
echo ""

# ============================================================
# Wait for Registrations with Status Updates
# ============================================================

echo "================================================"
echo "Waiting for registrations to complete..."
echo "================================================"
echo ""

# Poll until all background processes finish
while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  ELAPSED_MIN=$((ELAPSED / 60))
  ELAPSED_SEC=$((ELAPSED % 60))

  STILL_RUNNING=0
  COMPLETED=0
  AVAILABLE=0

  echo "[${ELAPSED_MIN}m ${ELAPSED_SEC}s elapsed]"

  for i in "${!PID_VARIANTS[@]}"; do
    VARIANT="${PID_VARIANTS[$i]}"
    PID="${PIDS[$i]}"
    TEMPLATE_NAME="jambonz-${VARIANT}-v${VERSION}"
    EXIT_FILE="${TMPDIR}/${VARIANT}.exit"

    if [ -f "$EXIT_FILE" ]; then
      # Process finished
      EXIT_CODE=$(cat "$EXIT_FILE")
      if [ "$EXIT_CODE" -eq 0 ]; then
        echo "  $TEMPLATE_NAME: registered"
        COMPLETED=$((COMPLETED + 1))
      else
        echo "  $TEMPLATE_NAME: FAILED"
        COMPLETED=$((COMPLETED + 1))
      fi
    else
      # Still running
      echo "  $TEMPLATE_NAME: registering..."
      STILL_RUNNING=$((STILL_RUNNING + 1))
    fi
  done

  echo "  Progress: ${COMPLETED}/${NUM_TO_REGISTER} done, ${STILL_RUNNING} in progress"

  if [ $STILL_RUNNING -eq 0 ]; then
    echo ""
    break
  fi

  echo ""
  sleep 30
done

# Wait for all background processes to fully exit
for PID in "${PIDS[@]}"; do
  wait "$PID" 2>/dev/null || true
done

# ============================================================
# Check Results
# ============================================================

echo "================================================"
echo "Results"
echo "================================================"
echo ""

FAILED_TEMPLATES=()
SUCCEEDED_TEMPLATES=()

for VARIANT in "${VARIANTS_TO_REGISTER[@]}"; do
  TEMPLATE_NAME="jambonz-${VARIANT}-v${VERSION}"
  EXIT_FILE="${TMPDIR}/${VARIANT}.exit"
  LOG_FILE="${TMPDIR}/${VARIANT}.log"

  EXIT_CODE=1
  if [ -f "$EXIT_FILE" ]; then
    EXIT_CODE=$(cat "$EXIT_FILE")
  fi

  if [ "$EXIT_CODE" -eq 0 ]; then
    echo "  $TEMPLATE_NAME: SUCCESS"
    SUCCEEDED_TEMPLATES+=("$TEMPLATE_NAME")
  else
    echo "  $TEMPLATE_NAME: FAILED"
    if [ -f "$LOG_FILE" ]; then
      echo "    Error: $(cat "$LOG_FILE")"
    fi
    FAILED_TEMPLATES+=("$TEMPLATE_NAME")
  fi
done

echo ""

TOTAL_TIME=$(($(date +%s) - START_TIME))
echo "Total time: $((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s"
echo ""

# Handle failures
if [ ${#FAILED_TEMPLATES[@]} -gt 0 ]; then
  echo "================================================"
  echo "WARNING: ${#FAILED_TEMPLATES[@]} template(s) failed to register"
  echo "================================================"
  echo ""
  for TEMPLATE_NAME in "${FAILED_TEMPLATES[@]}"; do
    echo "  - $TEMPLATE_NAME"
  done
  echo ""
  echo "You may need to check:"
  echo "  - Your Exoscale API credentials have template management permissions"
  echo "  - The image URLs are accessible"
  echo "  - Run this script again to retry failed templates"
  echo ""

  if [ ${#SUCCEEDED_TEMPLATES[@]} -eq 0 ]; then
    echo "No templates were registered. Please fix the errors above and try again."
    exit 1
  fi

  echo "Successfully registered ${#SUCCEEDED_TEMPLATES[@]} template(s)."
  echo "Fix the failed templates and run the script again (it will skip already-registered ones)."
  exit 1
fi

# ============================================================
# Success Output
# ============================================================

echo "================================================"
echo "SUCCESS! All ${#SUCCEEDED_TEMPLATES[@]} template(s) registered."
echo "================================================"
echo ""
echo "Registered templates in zone $ZONE:"
for VARIANT in "${VARIANTS[@]}"; do
  echo "  jambonz-${VARIANT}-v${VERSION}"
done
echo ""

echo "Next steps:"
echo ""
echo "  1. Navigate to the terraform directory:"
echo "     cd ${SCRIPT_DIR}/provision-vm-${SIZE}/"
echo ""
echo "  2. Copy and edit the example variables file:"
echo "     cp terraform.tfvars.example terraform.tfvars"
echo "     # Edit terraform.tfvars - set zone to \"$ZONE\" and configure other settings"
echo ""
echo "  3. Initialize and apply terraform:"
echo "     terraform init"
echo "     terraform plan"
echo "     terraform apply"
echo ""
echo "================================================"