# Nakama + PostgreSQL Pelican Bundle

This runs Nakama and PostgreSQL in one Pelican server container.

Persistent data:
- `/home/container/postgres/data`
- `/home/container/nakama/data`
- `/home/container/nakama/modules`

PostgreSQL listens only on `127.0.0.1:5432` inside the container and does not need a Pelican allocation.

## Build the image

Create a GitHub repo such as `pelican-nakama-postgres` and upload:
- `Dockerfile`
- `start.sh`
- `.github/workflows/build.yml`

Push to `main`. The workflow builds:
`ghcr.io/<your-github-username>/pelican-nakama-postgres:latest`

Make the GHCR package public, or configure Wings with credentials for a private registry.

## Import the egg

Before import, replace:
`ghcr.io/YOUR_GITHUB_USERNAME/pelican-nakama-postgres:latest`

with your real GHCR image path.

Then import `egg-nakama-postgres.json` in Pelican.

## Suggested server resources

- CPU: 200%
- RAM: 6144 MiB
- Disk: 50-100 GB
- Primary allocation: 7350
- Additional allocation: 7351

## Secrets

Replace every `CHANGE_ME` value.

For safe values:
`openssl rand -hex 32`

Use a hex value for `POSTGRES_PASSWORD`.

## First boot

The startup script:
1. Initializes PostgreSQL under `/home/container/postgres/data`
2. Starts it on localhost:5432
3. Creates the `nakama` role and database
4. Runs Nakama migrations
5. Starts Nakama

The image pins Nakama 3.40.0.
