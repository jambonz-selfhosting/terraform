#!/bin/bash
# Query DNSMadeEasy API for DNS records
# Usage: ./query_dme.sh [domain]

# Configuration from config.yaml
API_KEY="eea056b8-f2ae-46c1-aa91-435b0e689306"
SECRET="81e9d72f-0280-40a8-bded-6dc252f39102"
API_URL="https://api.dnsmadeeasy.com/V2.0"

# Domain to query (default: jambonz.io)
DOMAIN="${1:-jambonz.io}"

# Generate authentication headers
REQUEST_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S GMT")
HMAC=$(echo -n "$REQUEST_DATE" | openssl dgst -sha1 -hmac "$SECRET" | awk '{print $2}')

echo "Querying DNSMadeEasy for domain: $DOMAIN"
echo ""

# Step 1: Get domain ID
echo "Step 1: Getting domain ID..."
DOMAIN_RESPONSE=$(curl -s -X GET \
  -H "x-dnsme-apiKey: $API_KEY" \
  -H "x-dnsme-requestDate: $REQUEST_DATE" \
  -H "x-dnsme-hmac: $HMAC" \
  "$API_URL/dns/managed/name?domainname=$DOMAIN")

DOMAIN_ID=$(echo "$DOMAIN_RESPONSE" | jq -r '.id')

if [ "$DOMAIN_ID" == "null" ] || [ -z "$DOMAIN_ID" ]; then
    echo "❌ Domain not found: $DOMAIN"
    echo "Response: $DOMAIN_RESPONSE"
    exit 1
fi

echo "✓ Domain ID: $DOMAIN_ID"
echo ""

# Step 2: Get all DNS records for this domain
echo "Step 2: Fetching DNS records..."

# Need fresh timestamp for second request
REQUEST_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S GMT")
HMAC=$(echo -n "$REQUEST_DATE" | openssl dgst -sha1 -hmac "$SECRET" | awk '{print $2}')

RECORDS_RESPONSE=$(curl -s -X GET \
  -H "x-dnsme-apiKey: $API_KEY" \
  -H "x-dnsme-requestDate: $REQUEST_DATE" \
  -H "x-dnsme-hmac: $HMAC" \
  "$API_URL/dns/managed/$DOMAIN_ID/records")

# Check if we got records
RECORD_COUNT=$(echo "$RECORDS_RESPONSE" | jq -r '.data | length')

if [ "$RECORD_COUNT" == "null" ] || [ "$RECORD_COUNT" == "0" ]; then
    echo "No records found (or API error)"
    echo "Response: $RECORDS_RESPONSE"
    exit 1
fi

echo "✓ Found $RECORD_COUNT total record(s)"
echo ""

# Step 3: Filter for our jambonz records (gcp subdomain)
echo "Step 3: Filtering for gcp.jambonz.io related records..."
echo ""
echo "A Records:"
echo "=========================================="

echo "$RECORDS_RESPONSE" | jq -r '.data[] |
  select(.type == "A") |
  select(.name | contains("gcp")) |
  "  \(.name).\('"$DOMAIN"') -> \(.value) (TTL: \(.ttl)s, ID: \(.id))"'

# If you want to see ALL records (not just gcp)
echo ""
echo "All A Records for $DOMAIN:"
echo "=========================================="
echo "$RECORDS_RESPONSE" | jq -r '.data[] |
  select(.type == "A") |
  "  \(.name).\('"$DOMAIN"') -> \(.value) (TTL: \(.ttl)s, ID: \(.id))"'

echo ""
echo "Full JSON response saved to: /tmp/dme-records.json"
echo "$RECORDS_RESPONSE" | jq '.' > /tmp/dme-records.json
