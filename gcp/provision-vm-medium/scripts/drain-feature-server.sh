#!/bin/bash
# Gracefully drain THIS Feature Server instance and remove it from the MIG
# Must be run ON the Feature Server instance you want to drain
#
# Usage: /usr/local/bin/drain-feature-server.sh [-y]
#   -y  Skip confirmation prompt
# (run as jambonz user - no sudo required)
#
# What it does:
# 1. Checks MIG size (refuses to drain if this would take MIG from 1→0)
# 2. Abandons this instance from the MIG (so MIG won't force-delete it)
# 3. Resizes MIG target to (current - 1) to prevent replacement instance
# 4. Sets the Redis drain key (triggers the existing drain cron script)
# 5. The cron script then: sends SIGUSR1 → waits for processes to exit → self-deletes

set -e

# Parse command line arguments
SKIP_CONFIRM=false
while getopts "y" opt; do
    case $opt in
        y) SKIP_CONFIRM=true ;;
        *) echo "Usage: $0 [-y]"; exit 1 ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get instance metadata from GCP
log_info "Getting instance metadata..."
INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/name)
ZONE=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/zone | awk -F'/' '{print $NF}')
PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/project/project-id)

if [ -z "$INSTANCE_NAME" ] || [ -z "$ZONE" ] || [ -z "$PROJECT_ID" ]; then
    log_error "Failed to get instance metadata. Are you running this on a GCP instance?"
    exit 1
fi

log_info "Instance: $INSTANCE_NAME"
log_info "Zone: $ZONE"
log_info "Project: $PROJECT_ID"

# Check if already draining
if [ -f /tmp/draining ]; then
    log_warn "This instance is already draining. Check /var/log/jambonz-scale-in.log for progress."
    exit 0
fi

# Read Redis config from ecosystem.config.js
ECOSYSTEM_FILE="/home/jambonz/apps/ecosystem.config.js"
if [ ! -f "$ECOSYSTEM_FILE" ]; then
    log_error "Cannot find $ECOSYSTEM_FILE - is this a Feature Server?"
    exit 1
fi

# Extract JAMBONES_REDIS_HOST and JAMBONES_REDIS_PORT from ecosystem.config.js
REDIS_HOST=$(grep "JAMBONES_REDIS_HOST:" "$ECOSYSTEM_FILE" | sed "s/.*JAMBONES_REDIS_HOST: *['\"]\\([^'\"]*\\)['\"].*/\\1/")
REDIS_PORT=$(grep "JAMBONES_REDIS_PORT:" "$ECOSYSTEM_FILE" | sed "s/.*JAMBONES_REDIS_PORT: *\\([0-9]*\\).*/\\1/")

if [ -z "$REDIS_HOST" ]; then
    log_error "Could not find JAMBONES_REDIS_HOST in $ECOSYSTEM_FILE"
    exit 1
fi

if [ -z "$REDIS_PORT" ]; then
    REDIS_PORT=6379
fi

# Determine MIG name (convention: <name-prefix>-fs-mig, instance is <name-prefix>-fs-xxxx)
NAME_PREFIX=$(echo "$INSTANCE_NAME" | sed 's/-fs-.*$//')
MIG_NAME="${NAME_PREFIX}-fs-mig"

log_info "MIG: $MIG_NAME"
log_info "Redis: $REDIS_HOST:$REDIS_PORT"

# Get access token for GCP API calls (needed early for MIG size check)
ACCESS_TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
    http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    log_error "Failed to get access token from metadata service"
    exit 1
fi

# Get current MIG target size
log_info "Checking MIG target size..."
MIG_INFO=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://compute.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/$ZONE/instanceGroupManagers/$MIG_NAME")

CURRENT_SIZE=$(echo "$MIG_INFO" | jq -r '.targetSize // 0')

if [ "$CURRENT_SIZE" -eq 0 ]; then
    log_error "Could not determine MIG target size or MIG not found"
    exit 1
fi

log_info "Current MIG target size: $CURRENT_SIZE"

# Prevent scaling from 1 to 0
if [ "$CURRENT_SIZE" -le 1 ]; then
    log_error "Cannot drain: MIG target size is $CURRENT_SIZE. At least one Feature Server must remain."
    log_error "To remove the last instance, use 'terraform destroy' or delete the MIG manually."
    exit 1
fi

NEW_SIZE=$((CURRENT_SIZE - 1))
log_info "New MIG target size will be: $NEW_SIZE"

# Confirmation prompt
echo ""
log_warn "This will drain and DELETE this instance!"
log_warn "The instance will stop accepting new calls, wait for existing calls to complete, then self-delete."
echo ""

if [ "$SKIP_CONFIRM" = false ]; then
    read -p "Are you sure you want to proceed? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted."
        exit 0
    fi
fi

# Check if instance is in the MIG
log_info "Checking if instance is in MIG..."
MIG_INSTANCES=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://compute.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/$ZONE/instanceGroupManagers/$MIG_NAME/listManagedInstances" \
    | jq -r '.managedInstances[].instance // empty' | xargs -I{} basename {})

if echo "$MIG_INSTANCES" | grep -q "^${INSTANCE_NAME}$"; then
    log_info "Instance is in MIG, abandoning..."

    # Abandon this instance from the MIG
    ABANDON_RESULT=$(curl -s -X POST \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"instances\": [\"zones/$ZONE/instances/$INSTANCE_NAME\"]}" \
        "https://compute.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/$ZONE/instanceGroupManagers/$MIG_NAME/abandonInstances")

    # Check for errors
    ERROR=$(echo "$ABANDON_RESULT" | jq -r '.error.message // empty')
    if [ -n "$ERROR" ]; then
        log_error "Failed to abandon instance: $ERROR"
        exit 1
    fi

    log_info "Instance abandoned from MIG successfully"

    # Resize the MIG to prevent it from spinning up a replacement
    log_info "Resizing MIG from $CURRENT_SIZE to $NEW_SIZE..."
    RESIZE_RESULT=$(curl -s -X POST \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        "https://compute.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/$ZONE/instanceGroupManagers/$MIG_NAME/resize?size=$NEW_SIZE")

    # Check for errors
    ERROR=$(echo "$RESIZE_RESULT" | jq -r '.error.message // empty')
    if [ -n "$ERROR" ]; then
        log_error "Failed to resize MIG: $ERROR"
        log_warn "The instance will still drain, but MIG may spin up a replacement."
        # Don't exit - continue with drain anyway
    else
        log_info "MIG resized to $NEW_SIZE successfully"
    fi
else
    log_warn "Instance not in MIG (may already be abandoned), proceeding with drain..."
fi

# Set the drain key in Redis
log_info "Setting drain key in Redis..."
DRAIN_KEY="drain:$INSTANCE_NAME"
TIMESTAMP=$(date +%s)

redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SET "$DRAIN_KEY" "$TIMESTAMP" EX 900

if [ $? -eq 0 ]; then
    log_info "Drain key set successfully"
else
    log_error "Failed to set drain key in Redis"
    exit 1
fi

echo ""
log_info "Drain initiated for $INSTANCE_NAME"
log_info ""
log_info "The instance will now:"
log_info "  1. Stop accepting new calls (SIGUSR1)"
log_info "  2. Wait for existing calls to complete (up to 15 min)"
log_info "  3. Self-delete via GCP API"
echo ""
log_info "Monitor progress:"
echo "  tail -f /var/log/jambonz-scale-in.log"