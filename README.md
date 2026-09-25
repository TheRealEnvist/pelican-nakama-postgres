# Nakama + PostgreSQL (Exposed Database)

This version exposes the embedded PostgreSQL instance so another trusted service, such as your API container, can connect directly.

## Ports

Recommended Pelican allocations:

- Primary: `7350` — Nakama API/WebSocket
- Additional: `7351` — Nakama Console
- Additional: `15432` — PostgreSQL

Do NOT use host port 5432 because your Rocky host already uses 5432 for its own PostgreSQL.

## Startup Variables

- `POSTGRES_PORT=15432`
- `POSTGRES_ALLOWED_CIDR=172.16.0.0/12` for Docker containers on the same host
- Use `100.64.0.0/10` if the API connects through Tailscale
- Use your LAN subnet, e.g. `192.168.1.0/24`, if the API connects through LAN
- Avoid `0.0.0.0/0` unless you intentionally want PostgreSQL reachable from any source that can reach the allocation

## API connection string

If your API connects to the node over Tailscale:

`postgresql://nakama:<POSTGRES_PASSWORD>@100.115.175.15:15432/nakama`

If it connects over LAN:

`postgresql://nakama:<POSTGRES_PASSWORD>@192.168.1.22:15432/nakama`

If the API is another Docker/Pelican container on this same host, use whichever node address is reachable from that container plus port 15432.

## Rebuild

Replace `start.sh` in your GitHub image repo with the version in this bundle, keep the Dockerfile/build workflow, commit to `main`, and let GitHub Actions rebuild `ghcr.io/therealenvist/pelican-nakama-postgres:latest`.

Then restart the Pelican Nakama server so Wings pulls the rebuilt image.

## Security

Do not port-forward PostgreSQL to the public internet. Restrict access to your Docker subnet, Tailscale network, or LAN as appropriate.
