#!/bin/bash
# attack.sh — start/stop ShieldX replay demo without manually handling tokens
#
# Usage:
#   ./attack.sh start [csv_path] [speed]
#   ./attack.sh stop
#   ./attack.sh status
#
# Defaults to the DDoS Friday file at speed 15 if no args given.

BASE_URL="http://localhost:8000"
USERNAME="admin"
PASSWORD="changeme123"
DEFAULT_CSV="$(cd "$(dirname "${BASH_SOURCE[0]}")/ml_training/data" 2>/dev/null && pwd)/Friday-WorkingHours-Afternoon-DDos.pcap_ISCX.csv"

get_token() {
  curl -s -X POST "$BASE_URL/api/auth/login" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$USERNAME&password=$PASSWORD" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])"
}

case "$1" in
  start)
    CSV_PATH="${2:-$DEFAULT_CSV}"
    SPEED="${3:-15}"
    TOKEN=$(get_token)
    if [ -z "$TOKEN" ]; then
      echo "Failed to log in. Is the backend running on $BASE_URL?"
      exit 1
    fi
    echo "Starting replay: $CSV_PATH (speed=$SPEED)"
    curl -s -X POST "$BASE_URL/api/monitor/start?mode=replay&csv_path=$CSV_PATH&speed=$SPEED" \
      -H "Authorization: Bearer $TOKEN"
    echo
    ;;
  stop)
    TOKEN=$(get_token)
    if [ -z "$TOKEN" ]; then
      echo "Failed to log in. Is the backend running on $BASE_URL?"
      exit 1
    fi
    echo "Stopping monitoring..."
    curl -s -X POST "$BASE_URL/api/monitor/stop" \
      -H "Authorization: Bearer $TOKEN"
    echo
    ;;
  status)
    TOKEN=$(get_token)
    if [ -z "$TOKEN" ]; then
      echo "Failed to log in. Is the backend running on $BASE_URL?"
      exit 1
    fi
    curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/stats"
    echo
    ;;
  alerts)
    TOKEN=$(get_token)
    LIMIT="${2:-10}"
    curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/alerts?limit=$LIMIT"
    echo
    ;;
  *)
    echo "Usage: $0 {start [csv_path] [speed] | stop | status | alerts [limit]}"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # replay default DDoS file at speed 15"
    echo "  $0 start /path/to/file.csv 30"
    echo "  $0 stop"
    echo "  $0 status"
    echo "  $0 alerts 20"
    exit 1
    ;;
esac
