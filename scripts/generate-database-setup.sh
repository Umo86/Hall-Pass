#!/usr/bin/env bash
# Regenerates database-setup.sql: migrates + seeds a scratch database, dumps
# it, and wraps the dump in the re-runnable preamble and the deny-by-default
# epilogue. Run from the repo root with local Postgres available:
#   bash scripts/generate-database-setup.sh
set -euo pipefail

export PGPASSWORD="${PGPASSWORD:-postgres}"
DB=hallpass_setup
URL="postgres://postgres:postgres@localhost:5432/$DB"
OUT=database-setup.sql

dropdb --if-exists -U postgres -h localhost "$DB"
createdb -U postgres -h localhost "$DB"
DATABASE_URL="$URL" DIRECT_DATABASE_URL="$URL" pnpm db:migrate
DATABASE_URL="$URL" DIRECT_DATABASE_URL="$URL" pnpm db:seed

# Keep the hand-written preamble (everything up to the pg_dump banner) and
# epilogue (from the marker to the end) of the existing file.
PREAMBLE_END=$(grep -n -- "^-- PostgreSQL database dump$" "$OUT" | head -1 | cut -d: -f1)
PREAMBLE_END=$((PREAMBLE_END - 2))
EPILOGUE_START=$(grep -n -- "^-- Hall Pass epilogue" "$OUT" | head -1 | cut -d: -f1)
EPILOGUE_START=$((EPILOGUE_START - 1))

TMP=$(mktemp)
sed -n "1,${PREAMBLE_END}p" "$OUT" > "$TMP"
pg_dump -U postgres -h localhost --no-owner --no-privileges --inserts "$DB" >> "$TMP"
sed -n "${EPILOGUE_START},\$p" "$OUT" >> "$TMP"
mv "$TMP" "$OUT"
dropdb -U postgres -h localhost "$DB"
echo "Wrote $OUT"
