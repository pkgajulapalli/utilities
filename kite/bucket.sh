```bash
#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Kite Bucket Manager
#
# Commands:
#   ./bucket.sh upsert ...
#   ./bucket.sh get ...
#   ./bucket.sh list
#   ./bucket.sh delete ...
#   ./bucket.sh rebalance <bucket> --dry-run
#
# IMPORTANT:
#   --dry-run NEVER places an order.
#
# Kite Personal API:
#   - Holdings: supported
#   - Funds: supported
#   - Orders: supported
#   - Market data: NOT supported on Personal API
#
# Prices are therefore fetched from Yahoo Finance.
# ============================================================

BUCKET_DIR="${BUCKET_DIR:-$HOME/.kite-buckets}"

KITE_API_KEY="${KITE_API_KEY:-}"
KITE_ACCESS_TOKEN="${KITE_ACCESS_TOKEN:-}"

KITE_BASE_URL="https://api.kite.trade"
YAHOO_BASE_URL="https://query1.finance.yahoo.com/v8/finance/chart"

mkdir -p "$BUCKET_DIR"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_kite_credentials() {
    [[ -n "$KITE_API_KEY" ]] || die "KITE_API_KEY is not set"
    [[ -n "$KITE_ACCESS_TOKEN" ]] || die "KITE_ACCESS_TOKEN is not set"
}

kite_get() {
    local endpoint="$1"

    curl -sf \
        -H "X-Kite-Version: 3" \
        -H "Authorization: token ${KITE_API_KEY}:${KITE_ACCESS_TOKEN}" \
        "${KITE_BASE_URL}${endpoint}"
}

sanitize_name() {
    echo "$1" | tr ' /' '__' | tr -cd '[:alnum:]_.-'
}

bucket_file() {
    echo "$BUCKET_DIR/$(sanitize_name "$1").json"
}

# ------------------------------------------------------------
# Bucket validation
# ------------------------------------------------------------

validate_weights() {
    local total=0

    for item in "$@"; do

        [[ "$item" == *=* ]] ||
            die "Invalid allocation: $item"

        local weight="${item#*=}"

        [[ "$weight" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
            die "Invalid weight: $item"

        total=$(awk \
            -v a="$total" \
            -v b="$weight" \
            'BEGIN { printf "%.10f", a + b }')
    done

    if ! awk -v total="$total" \
        'BEGIN { exit !(total > 99.999 && total < 100.001) }'
    then
        die "Weights must add up to 100%. Current total: $total%"
    fi
}

# ------------------------------------------------------------
# Bucket operations
# ------------------------------------------------------------

upsert_bucket() {

    local name="$1"
    shift

    [[ $# -gt 0 ]] ||
        die "At least one stock allocation is required"

    validate_weights "$@"

    local file
    file="$(bucket_file "$name")"

    local tmp
    tmp="$(mktemp)"

    {
        echo "{"
        echo "  \"name\": \"$name\","
        echo "  \"weights\": {"

        local i=0
        local count=$#

        for item in "$@"; do

            local symbol="${item%%=*}"
            local weight="${item#*=}"

            ((i+=1))

            if [[ $i -lt $count ]]; then
                echo "    \"$symbol\": $weight,"
            else
                echo "    \"$symbol\": $weight"
            fi
        done

        echo "  }"
        echo "}"

    } > "$tmp"

    mv "$tmp" "$file"

    echo "Bucket upserted:"
    cat "$file"
}

get_bucket() {

    local file
    file="$(bucket_file "$1")"

    [[ -f "$file" ]] ||
        die "Bucket '$1' does not exist"

    cat "$file"
}

list_buckets() {

    if ! compgen -G "$BUCKET_DIR/*.json" > /dev/null; then
        echo "No buckets found."
        return
    fi

    for file in "$BUCKET_DIR"/*.json; do
        basename "$file" .json
    done
}

delete_bucket() {

    local file
    file="$(bucket_file "$1")"

    [[ -f "$file" ]] ||
        die "Bucket '$1' does not exist"

    rm "$file"

    echo "Deleted bucket: $1"
}

# ------------------------------------------------------------
# Kite API
# ------------------------------------------------------------

get_holdings() {

    require_kite_credentials

    kite_get "/portfolio/holdings"
}

get_margins() {

    require_kite_credentials

    kite_get "/user/margins"
}

# ------------------------------------------------------------
# Yahoo price lookup
# ------------------------------------------------------------

get_price() {

    local symbol="$1"

    # NSE symbol for Yahoo
    local yahoo_symbol="${symbol}.NS"

    local response

    response="$(
        curl -sf \
        "${YAHOO_BASE_URL}/${yahoo_symbol}?interval=1d&range=1d"
    )" || {
        echo "0"
        return
    }

    echo "$response" |
        sed -n 's/.*"regularMarketPrice":\([0-9.]*\).*/\1/p' |
        head -1
}

# ------------------------------------------------------------
# Rebalance calculation
# ------------------------------------------------------------

rebalance_bucket() {

    local bucket_name="$1"

    shift

    local dry_run=false

    while [[ $# -gt 0 ]]; do

        case "$1" in

            --dry-run)
                dry_run=true
                ;;

            *)
                die "Unknown option: $1"
                ;;

        esac

        shift
    done

    [[ "$dry_run" == true ]] ||
        die "Only --dry-run is currently supported"

    local file
    file="$(bucket_file "$bucket_name")"

    [[ -f "$file" ]] ||
        die "Bucket '$bucket_name' does not exist"

    require_kite_credentials

    command -v jq >/dev/null ||
        die "jq is required. Install with: brew install jq"

    echo
    echo "============================================"
    echo "KITE BUCKET REBALANCE"
    echo "============================================"
    echo
    echo "Bucket: $bucket_name"
    echo "Mode:   DRY RUN"
    echo

    # --------------------------------------------------------
    # Get Kite holdings
    # --------------------------------------------------------

    echo "Fetching holdings from Kite..."

    local holdings
    holdings="$(get_holdings)"

    echo "Holdings fetched."
    echo

    # --------------------------------------------------------
    # Get available cash
    # --------------------------------------------------------

    echo "Fetching available funds..."

    local margins
    margins="$(get_margins)"

    local cash

    cash="$(
        echo "$margins" |
        jq -r '.data.equity.available.cash // 0'
    )"

    echo "Available cash: ₹$cash"
    echo

    # --------------------------------------------------------
    # Calculate current bucket value
    #
    # This version assumes the bucket contains stocks that
    # are exclusively assigned to this bucket.
    # --------------------------------------------------------

    local total_value=0

    echo "Fetching market prices..."
    echo

    local rows=""

    while IFS= read -r item; do

        local symbol
        symbol="$(echo "$item" | cut -d'|' -f1)"

        local target_weight
        target_weight="$(echo "$item" | cut -d'|' -f2)"

        local quantity

        quantity="$(
            echo "$holdings" |
            jq -r --arg s "$symbol" '
                [.data[] | select(.tradingsymbol == $s)]
                | if length > 0
                  then .[0].quantity
                  else 0
                  end
            '
        )"

        local price
        price="$(get_price "$symbol")"

        if [[ -z "$price" || "$price" == "0" ]]; then
            echo "WARNING: Could not get price for $symbol"
            continue
        fi

        local value

        value="$(
            awk \
            -v q="$quantity" \
            -v p="$price" \
            'BEGIN { printf "%.2f", q * p }'
        )"

        total_value="$(
            awk \
            -v a="$total_value" \
            -v b="$value" \
            'BEGIN { printf "%.2f", a + b }'
        )"

        rows="${rows}${symbol}|${target_weight}|${quantity}|${price}|${value}"$'\n'

    done < <(
        jq -r '.weights | to_entries[] | "\(.key)|\(.value)"' "$file"
    )

    # Add cash to portfolio value.
    total_value="$(
        awk \
        -v a="$total_value" \
        -v b="$cash" \
        'BEGIN { printf "%.2f", a + b }'
    )"

    echo "============================================"
    echo "PORTFOLIO"
    echo "============================================"
    echo
    printf "%-15s %10s %10s %12s %15s\n" \
        "SYMBOL" "TARGET" "QTY" "PRICE" "VALUE"

    printf "%-15s %10s %10s %12s %15s\n" \
        "---------------" \
        "----------" \
        "----------" \
        "------------" \
        "---------------"

    while IFS='|' read -r symbol target quantity price value; do

        [[ -n "$symbol" ]] || continue

        printf "%-15s %9s%% %10s %12s %15s\n" \
            "$symbol" \
            "$target" \
            "$quantity" \
            "₹$price" \
            "₹$value"

    done <<< "$rows"

    echo
    echo "Total portfolio value: ₹$total_value"
    echo

    # --------------------------------------------------------
    # Calculate trades
    # --------------------------------------------------------

    echo "============================================"
    echo "PROPOSED TRADES"
    echo "============================================"
    echo

    printf "%-15s %-8s %12s %12s %12s\n" \
        "SYMBOL" \
        "ACTION" \
        "CURRENT QTY" \
        "TARGET QTY" \
        "DELTA"

    printf "%-15s %-8s %12s %12s %12s\n" \
        "---------------" \
        "--------" \
        "------------" \
        "------------" \
        "------------"

    while IFS='|' read -r symbol target quantity price value; do

        [[ -n "$symbol" ]] || continue

        local target_value

        target_value="$(
            awk \
            -v total="$total_value" \
            -v weight="$target" \
            'BEGIN {
                printf "%.2f", total * weight / 100
            }'
        )"

        local target_qty

        target_qty="$(
            awk \
            -v value="$target_value" \
            -v price="$price" \
            'BEGIN {
                if (price > 0)
                    printf "%d", int(value / price)
                else
                    print 0
            }'
        )"

        local delta=$((target_qty - quantity))

        if [[ "$delta" -gt 0 ]]; then

            printf "%-15s %-8s %12s %12s %12s\n" \
                "$symbol" \
                "BUY" \
                "$quantity" \
                "$target_qty" \
                "+$delta"

        elif [[ "$delta" -lt 0 ]]; then

            printf "%-15s %-8s %12s %12s %12s\n" \
                "$symbol" \
                "SELL" \
                "$quantity" \
                "$target_qty" \
                "$delta"

        else

            printf "%-15s %-8s %12s %12s %12s\n" \
                "$symbol" \
                "HOLD" \
                "$quantity" \
                "$target_qty" \
                "0"

        fi

    done <<< "$rows"

    echo
    echo "============================================"
    echo "DRY RUN COMPLETE"
    echo "============================================"
    echo
    echo "NO ORDERS WERE PLACED."
    echo
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

[[ $# -ge 1 ]] ||
    die "Usage: $0 {upsert|get|list|delete|rebalance}"

command="$1"
shift

case "$command" in

    upsert)
        [[ $# -ge 2 ]] ||
            die "Usage: $0 upsert <bucket> SYMBOL=WEIGHT ..."

        name="$1"
        shift

        upsert_bucket "$name" "$@"
        ;;

    get)
        [[ $# -eq 1 ]] ||
            die "Usage: $0 get <bucket>"

        get_bucket "$1"
        ;;

    list)
        [[ $# -eq 0 ]] ||
            die "Usage: $0 list"

        list_buckets
        ;;

    delete)
        [[ $# -eq 1 ]] ||
            die "Usage: $0 delete <bucket>"

        delete_bucket "$1"
        ;;

    rebalance)
        [[ $# -ge 1 ]] ||
            die "Usage: $0 rebalance <bucket> --dry-run"

        bucket="$1"
        shift

        rebalance_bucket "$bucket" "$@"
        ;;

    *)
        die "Unknown command: $command"
        ;;

esac
```
