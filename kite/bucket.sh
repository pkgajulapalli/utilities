#!/usr/bin/env bash

set -euo pipefail

BUCKET_DIR="${BUCKET_DIR:-$HOME/.kite-buckets}"
mkdir -p "$BUCKET_DIR"

usage() {
    echo "Usage:"
    echo "  $0 upsert <bucket-name> SYMBOL=WEIGHT [SYMBOL=WEIGHT ...]"
    echo "  $0 get    <bucket-name>"
    echo "  $0 list"
    echo "  $0 delete <bucket-name>"
    exit 1
}

sanitize_name() {
    echo "$1" | tr ' /' '__' | tr -cd '[:alnum:]_.-'
}

validate_weights() {
    local total=0

    for item in "$@"; do
        weight="${item#*=}"

        if [[ "$item" != *=* ]]; then
            echo "ERROR: Invalid allocation: $item"
            exit 1
        fi

        if ! [[ "$weight" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            echo "ERROR: Invalid weight: $item"
            exit 1
        fi

        total=$(awk "BEGIN { printf \"%.10f\", $total + $weight }")
    done

    if awk "BEGIN { exit !($total > 99.999 && $total < 100.001) }"; then
        :
    else
        echo "ERROR: Weights must add up to 100%. Current total: $total%"
        exit 1
    fi
}

upsert_bucket() {
    local name="$1"
    shift

    if [[ $# -eq 0 ]]; then
        echo "ERROR: At least one stock allocation is required."
        exit 1
    fi

    validate_weights "$@"

    local file
    file="$BUCKET_DIR/$(sanitize_name "$name").json"

    local tmp
    tmp=$(mktemp)

    {
        echo "{"
        echo "  \"name\": \"$name\","
        echo "  \"weights\": {"

        local i=0
        local count=$#

        for item in "$@"; do
            symbol="${item%%=*}"
            weight="${item#*=}"

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

    echo "Bucket upserted successfully:"
    cat "$file"
}

get_bucket() {
    local file="$BUCKET_DIR/$(sanitize_name "$1").json"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: Bucket '$1' does not exist."
        exit 1
    fi

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
    local file="$BUCKET_DIR/$(sanitize_name "$1").json"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: Bucket '$1' does not exist."
        exit 1
    fi

    rm "$file"
    echo "Deleted bucket: $1"
}

[[ $# -ge 1 ]] || usage

command="$1"
shift

case "$command" in
    upsert)
        [[ $# -ge 2 ]] || usage
        name="$1"
        shift
        upsert_bucket "$name" "$@"
        ;;

    get)
        [[ $# -eq 1 ]] || usage
        get_bucket "$1"
        ;;

    list)
        [[ $# -eq 0 ]] || usage
        list_buckets
        ;;

    delete)
        [[ $# -eq 1 ]] || usage
        delete_bucket "$1"
        ;;

    *)
        usage
        ;;
esac
