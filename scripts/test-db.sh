#!/usr/bin/env bash
set -euo pipefail
URL="${DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
psql "$URL" -v ON_ERROR_STOP=1 -f supabase/tests/foundation.sql
psql "$URL" -v ON_ERROR_STOP=1 -f supabase/tests/acesso-discipuladora.sql
