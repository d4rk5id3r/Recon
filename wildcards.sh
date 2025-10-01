#!/usr/bin/env bash
set -euo pipefail

# Usage: ./run_subfinder_from_wildcards.sh input_wildcards.txt [output_file]
# Example: ./run_subfinder_from_wildcards.sh wildcards.txt subs-found.txt

INPUT_FILE="${1:-}"
OUTPUT_FILE="${2:-subfinder_results.txt}"

if [[ -z "$INPUT_FILE" ]]; then
  echo "Usage: $0 input_wildcards.txt [output_file]"
  exit 2
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: input file '$INPUT_FILE' not found."
  exit 3
fi

if ! command -v subfinder >/dev/null 2>&1; then
  echo "Error: 'subfinder' is not installed or not in PATH."
  echo "Install it from https://github.com/projectdiscovery/subfinder"
  exit 4
fi

TMP_LIST="$(mktemp)"
trap 'rm -f "$TMP_LIST"' EXIT

# Normalize input:
# - trim whitespace
# - remove blank lines and comments starting with #
# - remove leading "*." or leading "."
# - keep only valid-looking domain lines (simple filter)
# - dedupe
sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' "$INPUT_FILE" \
  | sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' \
  | sed -E 's/^[*\.]+\.?//; s/^\.+//' \
  | grep -E '^[A-Za-z0-9.-]+$' \
  | sort -u \
  > "$TMP_LIST"

if [[ ! -s "$TMP_LIST" ]]; then
  echo "No valid domains found in '$INPUT_FILE' after normalization."
  exit 5
fi

echo "[*] Feeding $(wc -l < "$TMP_LIST") domain(s) to subfinder..."
# Run subfinder. Adjust flags as needed (e.g. -timeout, -sources, -config).
# -silent reduces extra output; remove it if you want progress info on STDOUT.
subfinder -dL "$TMP_LIST" -o "$OUTPUT_FILE" -silent

# Deduplicate final output and keep sorted
if [[ -f "$OUTPUT_FILE" ]]; then
  sort -u "$OUTPUT_FILE" -o "$OUTPUT_FILE"
  echo "[+] Results saved to: $OUTPUT_FILE (unique)"
  echo "[+] Found $(wc -l < "$OUTPUT_FILE") unique subdomain(s)."
else
  echo "Subfinder did not produce an output file."
  exit 6
fi
