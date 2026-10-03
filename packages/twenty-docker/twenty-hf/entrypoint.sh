#!/bin/sh
set -eu

log() { printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
fatal() { log "ERROR: $*" >&2; exit 1; }
app_run() { su-exec 1000:1000 env HOME=/home/node "$@"; }

DATA_DIR=${TWENTY_DATA_DIR:-/data/twenty}
PGDATA="$DATA_DIR/postgres"
STORAGE_DIR="$DATA_DIR/storage"
LOG_DIR="$DATA_DIR/logs"
RUNTIME_DIR="$DATA_DIR/runtime"
SECRETS_DIR="$DATA_DIR/secrets"
PG_CREDENTIAL_FILE="$SECRETS_DIR/postgres-password"
APP_SECRET_FILE="$SECRETS_DIR/app-secret"
ENCRYPTION_KEY_FILE="$SECRETS_DIR/encryption-key"

mkdir -p "$PGDATA" "$STORAGE_DIR" "$LOG_DIR" "$RUNTIME_DIR" "$SECRETS_DIR"
chmod 0700 "$SECRETS_DIR"
chown -R postgres:postgres "$PGDATA" "$RUNTIME_DIR"
chown -R 1000:1000 "$STORAGE_DIR" "$LOG_DIR" "$SECRETS_DIR"

generate_secret() {
  file=$1
  if [ ! -s "$file" ]; then
    umask 077
    od -An -N32 -tx1 /dev/urandom | tr -d ' \n' > "$file"
    chown 1000:1000 "$file"
  fi
}

generate_secret "$PG_CREDENTIAL_FILE"
generate_secret "$APP_SECRET_FILE"
generate_secret "$ENCRYPTION_KEY_FILE"

PG_PASSWORD=$(cat "$PG_CREDENTIAL_FILE")
export APP_SECRET=${APP_SECRET:-$(cat "$APP_SECRET_FILE")}
export ENCRYPTION_KEY=${ENCRYPTION_KEY:-$(cat "$ENCRYPTION_KEY_FILE")}
export PG_DATABASE_URL=${PG_DATABASE_URL:-"postgres://twenty:${PG_PASSWORD}@127.0.0.1:5432/default"}
export REDIS_URL=${REDIS_URL:-redis://127.0.0.1:6379}
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH=${STORAGE_LOCAL_PATH:-$STORAGE_DIR}
export PORT=${PORT:-7860}
export NODE_PORT=${NODE_PORT:-$PORT}
export SERVER_URL=${SERVER_URL:-https://leon4gr45-twenty.hf.space}
export IS_MULTIWORKSPACE_ENABLED=${IS_MULTIWORKSPACE_ENABLED:-false}

# This image deliberately owns its local database and queue endpoints. Refuse
# accidental external overrides instead of silently violating that guarantee.
case "$PG_DATABASE_URL" in *'@127.0.0.1:5432/'*) ;; *) fatal 'PG_DATABASE_URL must use the bundled PostgreSQL at 127.0.0.1:5432' ;; esac
[ "$REDIS_URL" = redis://127.0.0.1:6379 ] || fatal 'REDIS_URL must use the bundled Redis at 127.0.0.1:6379'

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  log "Initializing PostgreSQL data directory at $PGDATA"
  pwfile="$RUNTIME_DIR/initdb-password"
  printf '%s' "$PG_PASSWORD" > "$pwfile"
  chown postgres:postgres "$pwfile"
  chmod 0600 "$pwfile"
  su-exec postgres initdb -D "$PGDATA" --username=twenty --pwfile="$pwfile" --auth-host=scram-sha-256 --auth-local=trust --encoding=UTF8 >/dev/null
  rm -f "$pwfile"
  cat >> "$PGDATA/postgresql.conf" <<EOF
listen_addresses = '127.0.0.1'
port = 5432
unix_socket_directories = '$RUNTIME_DIR'
max_connections = 20
shared_buffers = 48MB
effective_cache_size = 128MB
maintenance_work_mem = 24MB
work_mem = 2MB
wal_buffers = 4MB
max_worker_processes = 2
max_parallel_workers = 1
max_parallel_workers_per_gather = 0
autovacuum_max_workers = 1
dynamic_shared_memory_type = mmap
EOF
fi

PIDS=''
shutdown() {
  trap - TERM INT EXIT
  log 'Stopping local services'
  [ -z "$PIDS" ] || kill -TERM $PIDS 2>/dev/null || true
  for pid in $PIDS; do wait "$pid" 2>/dev/null || true; done
}
trap 'shutdown; exit 143' TERM INT
trap shutdown EXIT

log 'Starting PostgreSQL (localhost only)'
su-exec postgres postgres -D "$PGDATA" &
PG_PID=$!
PIDS="$PG_PID"

i=0
until su-exec postgres pg_isready -h 127.0.0.1 -p 5432 -U twenty >/dev/null 2>&1; do
  kill -0 "$PG_PID" 2>/dev/null || fatal 'PostgreSQL exited during startup'
  i=$((i + 1)); [ "$i" -lt 120 ] || fatal 'PostgreSQL readiness timed out'
  sleep 0.5
done
PGPASSWORD=$PG_PASSWORD su-exec postgres psql -h 127.0.0.1 -U twenty -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='default'" | grep -q 1 || \
  PGPASSWORD=$PG_PASSWORD su-exec postgres createdb -h 127.0.0.1 -U twenty -O twenty default

log 'Starting Redis (localhost only, non-persistent queue/cache)'
redis-server --bind 127.0.0.1 --protected-mode yes --save '' --appendonly no \
  --maxmemory-policy noeviction --dir "$RUNTIME_DIR" &
REDIS_PID=$!
PIDS="$PIDS $REDIS_PID"
i=0
until redis-cli -h 127.0.0.1 ping 2>/dev/null | grep -q PONG; do
  kill -0 "$REDIS_PID" 2>/dev/null || fatal 'Redis exited during startup'
  i=$((i + 1)); [ "$i" -lt 60 ] || fatal 'Redis readiness timed out'
  sleep 0.25
done

cd /app/packages/twenty-server
log 'Running Twenty database initialization/upgrades'
has_schema=$(PGPASSWORD=$PG_PASSWORD psql -h 127.0.0.1 -U twenty -d default -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name='core')")
if [ "$has_schema" != t ]; then app_run yarn database:init:prod; fi
app_run yarn command:prod cache:flush || log 'WARNING: pre-upgrade cache flush failed'
app_run yarn command:prod upgrade || fatal 'Twenty database upgrade failed'
app_run yarn command:prod cache:flush || log 'WARNING: post-upgrade cache flush failed'

log "Starting Twenty server on 0.0.0.0:$NODE_PORT"
app_run node dist/main &
SERVER_PID=$!
PIDS="$PIDS $SERVER_PID"
i=0
until curl -fsS "http://127.0.0.1:$NODE_PORT/healthz" >/dev/null 2>&1; do
  kill -0 "$SERVER_PID" 2>/dev/null || fatal 'Twenty server exited during startup'
  i=$((i + 1)); [ "$i" -lt 240 ] || fatal 'Twenty health check timed out'
  sleep 0.5
done

if [ "${TWENTY_LIGHT_MODE:-false}" = true ]; then
  log 'TWENTY_LIGHT_MODE=true: worker and cron registration are disabled; queued asynchronous features will not run'
else
  log 'Starting Twenty queue worker'
  app_run node dist/queue-worker/queue-worker &
  WORKER_PID=$!
  PIDS="$PIDS $WORKER_PID"
  sleep 2
  kill -0 "$WORKER_PID" 2>/dev/null || fatal 'Twenty worker exited during startup'
  log 'Registering recurring background jobs'
  app_run yarn command:prod cron:register:all || fatal 'Cron registration failed'
fi

log 'Twenty is ready'
while :; do
  for pid in $PIDS; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" || status=$?
      fatal "Essential process $pid exited (status ${status:-0})"
    fi
  done
  sleep 1
done
