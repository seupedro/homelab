#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
RETRIES=5
INTERVAL=10
URL=""
SKIP_TLS=false

# Function to print colored output
print_info() { echo -e "${GREEN}[HEALTH CHECK]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[HEALTH CHECK]${NC} $1"; }
print_error() { echo -e "${RED}[HEALTH CHECK]${NC} $1"; }

# Function to show usage
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Perform HTTP health checks with retries and TLS validation.

Required Options:
  -u, --url URL             URL to check (e.g., https://example.pane.run)

Optional Options:
  -r, --retries RETRIES     Number of retry attempts (default: 5)
  -i, --interval INTERVAL   Seconds between retries (default: 10)
  -s, --skip-tls            Skip TLS certificate validation
  -h, --help                Show this help message

Examples:
  $0 --url https://myapp.pane.run
  $0 -u https://api.pane.run -r 10 -i 15

Exit Codes:
  0 - Health check passed
  1 - Health check failed after all retries
  2 - Invalid arguments

EOF
  exit 2
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--url)
      URL="$2"
      shift 2
      ;;
    -r|--retries)
      RETRIES="$2"
      shift 2
      ;;
    -i|--interval)
      INTERVAL="$2"
      shift 2
      ;;
    -s|--skip-tls)
      SKIP_TLS=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      print_error "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate required parameters
if [[ -z "$URL" ]]; then
  print_error "Missing required parameter: --url"
  usage
fi

# Validate URL format
if ! [[ "$URL" =~ ^https?:// ]]; then
  print_error "Invalid URL format. Must start with http:// or https://"
  exit 2
fi

# Validate retries is a number
if ! [[ "$RETRIES" =~ ^[0-9]+$ ]]; then
  print_error "Invalid retries value. Must be a positive number"
  exit 2
fi

# Validate interval is a number
if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]]; then
  print_error "Invalid interval value. Must be a positive number"
  exit 2
fi

print_info "Starting health check for $URL"
print_info "Retries: $RETRIES, Interval: ${INTERVAL}s"

# Prepare curl options
CURL_OPTS=("-s" "-w" "\nHTTP_CODE:%{http_code}\nTIME_TOTAL:%{time_total}\n" "-o" "/dev/null")

if [[ "$SKIP_TLS" == "true" ]]; then
  CURL_OPTS+=("-k")
  print_warn "TLS certificate validation is disabled"
fi

# Function to perform single health check
perform_check() {
  local attempt=$1

  print_info "Attempt $attempt/$RETRIES..."

  # Perform HTTP request
  local output
  if output=$(curl "${CURL_OPTS[@]}" "$URL" 2>&1); then
    # Extract HTTP code and response time
    local http_code
    local time_total

    http_code=$(echo "$output" | grep "HTTP_CODE:" | cut -d: -f2)
    time_total=$(echo "$output" | grep "TIME_TOTAL:" | cut -d: -f2)

    if [[ -z "$http_code" ]]; then
      print_error "Failed to extract HTTP status code from response"
      return 1
    fi

    # Check if HTTP code is 200
    if [[ "$http_code" == "200" ]]; then
      print_info "✓ HTTP 200 OK (response time: ${time_total}s)"

      # Additional TLS check for HTTPS URLs
      if [[ "$URL" =~ ^https:// ]] && [[ "$SKIP_TLS" == "false" ]]; then
        local domain
        domain=$(echo "$URL" | sed -e 's|^https://||' -e 's|/.*$||' -e 's|:.*$||')

        print_info "Validating TLS certificate for $domain..."

        # Check certificate expiry
        if echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -checkend 86400 > /dev/null 2>&1; then
          print_info "✓ TLS certificate is valid"
          return 0
        else
          print_warn "TLS certificate check failed (may be expiring soon or invalid)"
          # Still return success if HTTP 200 was received
          return 0
        fi
      fi

      return 0
    else
      print_error "HTTP $http_code received (expected 200)"
      return 1
    fi
  else
    print_error "HTTP request failed: $output"
    return 1
  fi
}

# Retry loop
for attempt in $(seq 1 "$RETRIES"); do
  if perform_check "$attempt"; then
    print_info ""
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "✓ Health check PASSED"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info ""
    exit 0
  fi

  # If not the last attempt, wait before retrying
  if [[ $attempt -lt $RETRIES ]]; then
    print_warn "Waiting ${INTERVAL}s before retry..."
    sleep "$INTERVAL"
  fi
done

# All retries exhausted
print_error ""
print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_error "✗ Health check FAILED after $RETRIES attempts"
print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_error ""
exit 1
