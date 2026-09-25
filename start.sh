#!/usr/bin/env bash
set -Eeuo pipefail

PGROOT="/home/container/postgres"
PGDATA="${PGROOT}/data"
PGSOCKET="${PGROOT}/run"
PGLOG="${PGROOT}/postgres.log"

POSTGRES_PORT="${POSTGRES_PORT:-15432}"
POSTGRES_ALLOWED_CIDR="${POSTGRES_ALLOWED_CIDR:-172.16.0.0/12}"

mkdir -p "${PGDATA}" "${PGSOCKET}" /home/container/nakama/data /home/container/nakama/modules

POSTGRES_BIN="$(dirname "$(find /usr/lib/postgresql -type f -name postgres -print -quit)")"

if [[ -z "${POSTGRES_BIN}" || ! -x "${POSTGRES_BIN}/postgres" ]]; then
    echo "Could not locate PostgreSQL binaries."
    exit 1
fi

if [[ ! -f "${PGDATA}/PG_VERSION" ]]; then
    echo "Initializing PostgreSQL data directory..."

    "${POSTGRES_BIN}/initdb" \
        -D "${PGDATA}" \
        --username=postgres \
        --encoding=UTF8 \
        --auth-local=trust \
        --auth-host=scram-sha-256

    {
        echo "listen_addresses = '0.0.0.0'"
        echo "port = ${POSTGRES_PORT}"
        echo "unix_socket_directories = '${PGSOCKET}'"
    } >> "${PGDATA}/postgresql.conf"

    {
        echo "host all all 127.0.0.1/32 scram-sha-256"
        echo "host all all ::1/128 scram-sha-256"
        echo "host all all ${POSTGRES_ALLOWED_CIDR} scram-sha-256"
    } >> "${PGDATA}/pg_hba.conf"
else
    sed -i "s/^#\?listen_addresses.*/listen_addresses = '0.0.0.0'/" "${PGDATA}/postgresql.conf" || true

    if grep -qE '^port[[:space:]]*=' "${PGDATA}/postgresql.conf"; then
        sed -i "s/^port[[:space:]]*=.*/port = ${POSTGRES_PORT}/" "${PGDATA}/postgresql.conf"
    else
        echo "port = ${POSTGRES_PORT}" >> "${PGDATA}/postgresql.conf"
    fi

    if ! grep -Fq "host all all ${POSTGRES_ALLOWED_CIDR} scram-sha-256" "${PGDATA}/pg_hba.conf"; then
        echo "host all all ${POSTGRES_ALLOWED_CIDR} scram-sha-256" >> "${PGDATA}/pg_hba.conf"
    fi
fi

cleanup() {
    if "${POSTGRES_BIN}/pg_ctl" -D "${PGDATA}" status >/dev/null 2>&1; then
        "${POSTGRES_BIN}/pg_ctl" -D "${PGDATA}" -m fast stop >/dev/null 2>&1 || true
    fi
}

trap cleanup SIGINT SIGTERM

echo "Starting PostgreSQL on 0.0.0.0:${POSTGRES_PORT}..."
"${POSTGRES_BIN}/pg_ctl" \
    -D "${PGDATA}" \
    -l "${PGLOG}" \
    -o "-k ${PGSOCKET}" \
    start

for _ in $(seq 1 60); do
    if "${POSTGRES_BIN}/pg_isready" -h "${PGSOCKET}" -p "${POSTGRES_PORT}" -U postgres >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! "${POSTGRES_BIN}/pg_isready" -h "${PGSOCKET}" -p "${POSTGRES_PORT}" -U postgres >/dev/null 2>&1; then
    echo "PostgreSQL did not become ready."
    tail -n 100 "${PGLOG}" || true
    exit 1
fi

if ! "${POSTGRES_BIN}/psql" -h "${PGSOCKET}" -p "${POSTGRES_PORT}" -U postgres -d postgres -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='nakama'" | grep -q 1; then
    echo "Creating Nakama PostgreSQL role..."
    "${POSTGRES_BIN}/createuser" -h "${PGSOCKET}" -p "${POSTGRES_PORT}" -U postgres --login nakama
fi

ESCAPED_DB_PASSWORD="${POSTGRES_PASSWORD//\'/\'\'}"

"${POSTGRES_BIN}/psql" \
    -h "${PGSOCKET}" \
    -p "${POSTGRES_PORT}" \
    -U postgres \
    -d postgres \
    -v ON_ERROR_STOP=1 \
    -c "ALTER ROLE nakama WITH LOGIN PASSWORD '${ESCAPED_DB_PASSWORD}';"

if ! "${POSTGRES_BIN}/psql" -h "${PGSOCKET}" -p "${POSTGRES_PORT}" -U postgres -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='nakama'" | grep -q 1; then
    echo "Creating Nakama database..."
    "${POSTGRES_BIN}/createdb" \
        -h "${PGSOCKET}" \
        -p "${POSTGRES_PORT}" \
        -U postgres \
        -O nakama \
        nakama
fi

DATABASE_ADDRESS="nakama:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT}/nakama"

echo "Running Nakama migrations..."
/usr/local/bin/nakama migrate up \
    --database.address "${DATABASE_ADDRESS}"

echo "Starting Nakama..."
/usr/local/bin/nakama \
    --name "${NAKAMA_NAME}" \
    --data_dir "/home/container/nakama/data" \
    --database.address "${DATABASE_ADDRESS}" \
    --socket.address "0.0.0.0" \
    --socket.port "${SERVER_PORT}" \
    --socket.server_key "${SERVER_KEY}" \
    --runtime.path "/home/container/nakama/modules" \
    --runtime.http_key "${RUNTIME_HTTP_KEY}" \
    --session.encryption_key "${SESSION_ENCRYPTION_KEY}" \
    --session.refresh_encryption_key "${SESSION_REFRESH_ENCRYPTION_KEY}" \
    --console.address "0.0.0.0" \
    --console.port "${CONSOLE_PORT}" \
    --console.username "${CONSOLE_USERNAME}" \
    --console.password "${CONSOLE_PASSWORD}" \
    --logger.level "${LOG_LEVEL}" &

NAKAMA_PID=$!

set +e
wait "${NAKAMA_PID}"
EXIT_CODE=$?
set -e

cleanup
exit "${EXIT_CODE}"
