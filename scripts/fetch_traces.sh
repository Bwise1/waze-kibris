#!/usr/bin/env bash
# Pull all field-tester nav traces from Cloudinary into .nav_traces/ so they
# can be analysed locally. Credentials come from the backend's .env (never
# stored in this repo). New files only; already-downloaded trips are skipped.
# All network I/O goes through curl — the system python may lack SSL certs.
set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE="../waze_kibris_api/.env"
export $(grep -E "^CLOUDINARY_(CLOUD_NAME|API_KEY|API_SECRET)=" "$ENV_FILE" | xargs)
OUT=".nav_traces"
mkdir -p "$OUT"
new=0
while read -r public_id url; do
  name="${public_id#nav_traces/}"
  name="${name//\//__}"
  [[ "$name" == *.jsonl ]] || name="$name.jsonl"
  path="$OUT/$name"
  if [[ ! -f "$path" ]]; then
    curl -sf "$url" -o "$path"
    echo "fetched $name ($(wc -c < "$path" | tr -d ' ') bytes)"
    new=$((new + 1))
  fi
done < <(
  curl -s -u "$CLOUDINARY_API_KEY:$CLOUDINARY_API_SECRET" \
    "https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/resources/raw?type=upload&prefix=nav_traces/&max_results=500" |
  python3 -c 'import json,sys
for r in json.load(sys.stdin).get("resources", []):
    print(r["public_id"], r["secure_url"])'
)
echo "$new new trace(s) in $OUT/"
