#!/usr/bin/env bash

# ==========================================================
# whatelse - Service dependency visibility tool
# Portable across systemd-based Linux distributions
# Developed by @aaronamran with MIT License
# GitHub repository: https://github.com/aaronamran/whatelse/
# Requirements: bash, systemctl, ps, awk, grep, sort
# Optional: lsof (for connection visibility)
# ==========================================================

OUTPUT_FILE=""
SERVICE=""

show_help() {
    cat <<EOF
whatelse - Show service dependencies before stopping
Developed by @aaronamran with MIT License
GitHub repository: https://github.com/aaronamran/whatelse/

Usage:
  sudo whatelse [--output FILE] SERVICE

Description:
  Displays key information about a systemd service before you stop or restart it.

  - Service state:
      Shows whether the service is currently running or inactive.
  - Reverse systemd dependencies:
      Lists other services or units that depend on this service; stopping it may affect them.
  - Target membership:
      Shows which systemd targets include this service (e.g., multi-user.target), 
      helping you understand its role in boot/operation.
  - Socket activation status:
      Indicates if the service is triggered by a socket (may start automatically when needed).
  - Active network connections (if lsof installed):
      Lists listening ports and how many clients are connected to the service.

This tool is read-only and makes no changes to the system.
EOF
}


# -----------------------------
# Argument parsing
# -----------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            SERVICE="$1"
            shift
            ;;
    esac
done

if [[ -z "$SERVICE" ]]; then
    show_help
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root: sudo whatelse <service>"
    exit 1
fi

# Normalize name
[[ "$SERVICE" != *.service ]] && SERVICE="${SERVICE}.service"

# Validate existence
if ! systemctl status "$SERVICE" >/dev/null 2>&1; then
    echo "Service '$SERVICE' not found."
    exit 1
fi

HAS_LSOF=true
if ! command -v lsof >/dev/null 2>&1; then
    HAS_LSOF=false
fi

# -----------------------------
# Collect Information
# -----------------------------
ACTIVE_STATE=$(systemctl is-active "$SERVICE")
ENABLED_STATE=$(systemctl is-enabled "$SERVICE" 2>/dev/null)

REVERSE_DEPS=$(systemctl list-dependencies \
    --reverse \
    --plain \
    --no-pager \
    --no-legend "$SERVICE" 2>/dev/null | grep -v "$SERVICE")

TARGET_MEMBERSHIP=$(systemctl list-dependencies \
    --reverse \
    --plain \
    --no-pager \
    --no-legend "$SERVICE" 2>/dev/null | grep ".target")

SOCKET_UNITS=$(systemctl list-unit-files | grep "^${SERVICE%.service}\.socket")

MAINPID=$(systemctl show "$SERVICE" -p MainPID --value)

# -----------------------------
# Runtime Connections (Optional)
# -----------------------------
CONNECTION_INFO=""
if $HAS_LSOF && [[ "$MAINPID" -gt 0 ]]; then
    PORTS=$(lsof -Pan -p "$MAINPID" -i 2>/dev/null | awk 'NR>1 {print $9}' | sort -u)
    if [[ -n "$PORTS" ]]; then
        while read -r port; do
            COUNT=$(lsof -i "$port" 2>/dev/null | awk 'NR>1' | wc -l)
            CONNECTION_INFO+="  $port ($COUNT connections)\n"
        done <<< "$PORTS"
    fi
fi

# -----------------------------
# Build Output
# -----------------------------
build_output() {
    echo "Service: $SERVICE"
    echo "--------------------------------------------------"
    echo "State:        $ACTIVE_STATE"
    echo "Enabled:      $ENABLED_STATE"
    echo "Main PID:     $MAINPID"
    echo ""

    echo "[Reverse Dependencies]"
    if [[ -z "$REVERSE_DEPS" ]]; then
        echo "  None"
    else
        echo "$REVERSE_DEPS" | awk '{print "  - "$0}'
    fi
    echo ""

    echo "[Target Membership]"
    if [[ -z "$TARGET_MEMBERSHIP" ]]; then
        echo "  None"
    else
        echo "$TARGET_MEMBERSHIP" | awk '{print "  - "$0}'
    fi
    echo ""

    echo "[Socket Activation]"
    if [[ -z "$SOCKET_UNITS" ]]; then
        echo "  No associated socket units"
    else
        echo "$SOCKET_UNITS" | awk '{print "  - "$0}'
    fi
    echo ""

    echo "[Active Connections]"
    if ! $HAS_LSOF; then
        echo "  Skipped (lsof not installed)"
    elif [[ -z "$CONNECTION_INFO" ]]; then
        echo "  None"
    else
        echo -e "$CONNECTION_INFO"
    fi

    echo "--------------------------------------------------"
}

# -----------------------------
# Output Handling
# -----------------------------
if [[ -n "$OUTPUT_FILE" ]]; then
    build_output > "$OUTPUT_FILE"
    echo "Report written to $OUTPUT_FILE"
else
    build_output
fi

exit 0
