# Project Instructions for Claude Code

This file provides context for Claude Code to assist with this project.

## Documentation Strategy

- **Public docs** (tracked): Generic instructions with placeholders (`yourdomain.com`, `YOUR_NAS_IP`)
- **Private config** (`.claude/config.local.md`, gitignored): Actual hostnames, IPs, usernames
- **Credentials** (`.env`, gitignored): Passwords and tokens

**Always read `config.local.md`** for actual deployment values (domain, IPs, NAS hostname).

## Security

**NEVER commit secrets.** Use `${VAR_NAME}` references in compose files, real values in `.env` (gitignored).

Forbidden in tracked files: API keys, passwords, tokens, private keys, public IPs, email addresses.

## File Locations

| Location | Purpose |
|----------|---------|
| Git repo (local) | Development |
| Git repo (NAS: `/volume1/docker/arr-stack/`) | Deployment via `git pull` |

**Deployed via git**: `docker-compose.*.yml`, `traefik/`, `scripts/`, `.claude/instructions.md`
**Gitignored but required on NAS**: `.env` (manual setup), app data directories
**Not needed on NAS**: `docs/`, `.env.example` (but git pull includes them, harmless)

## Deployment Workflow

**The NAS has a git clone of this repo. Deploy via git, not file copy.**

```bash
# 1. Commit and push locally
git add -A && git commit -m "..." && git push

# 2. Pull on NAS
ssh <user>@<nas-host> "cd /volume1/docker/arr-stack && git pull"

# 3. Restart affected services
ssh <user>@<nas-host> "docker restart traefik"  # For routing changes
ssh <user>@<nas-host> "cd /volume1/docker/arr-stack && docker compose -f docker-compose.arr-stack.yml up -d"  # For compose changes
```

## NAS Access

**See `config.local.md` for hostname and username.**

**On any auth failure, immediately ask the user for credentials. Don't retry or guess.**

```bash
# Add user to docker group (one-time setup, avoids needing sudo for docker):
echo 'PASS' | sudo -S usermod -aG docker <user>
# Requires new SSH session to take effect

# SCP doesn't work on UGOS. Use stdin redirect (for rare cases):
sshpass -p 'PASS' ssh <user>@<nas-host> "cat > /path/file" < localfile

# If sudo is needed, pipe password:
sshpass -p 'PASS' ssh <user>@<nas-host> "echo 'PASS' | sudo -S <command>"

# Image updates need pull + recreate (restart keeps old image):
docker compose -f docker-compose.arr-stack.yml pull <service>
docker compose -f docker-compose.arr-stack.yml up -d <service>
```

## Service Networking

VPN services (Sonarr, Radarr, Prowlarr, qBittorrent) use `network_mode: service:gluetun`.

| Route | Use |
|-------|-----|
| VPN → VPN (Sonarr/Radarr → qBittorrent) | `localhost` |
| Non-VPN → VPN (Jellyseerr → Sonarr) | `gluetun` |
| Any → Non-VPN (Any → Jellyfin) | container name |

**Download client config**: Sonarr/Radarr → qBittorrent: Host=`localhost`, Port=`8085` (they share Gluetun's network).

## Traefik Routing

Routes defined in `traefik/dynamic/vpn-services.yml`, NOT Docker labels.

Docker labels are minimal (`traefik.enable=true`, `traefik.docker.network=traefik-proxy`). To add routes, edit `vpn-services.yml`.

**Remote vs Local-only services:**
- **Remote** (via Cloudflare Tunnel): Jellyfin, Jellyseerr, WireGuard, Traefik dashboard
- **Local-only** (NAS_IP:PORT or via WireGuard): Sonarr, Radarr, Prowlarr, qBittorrent, Bazarr, Pi-hole, Uptime Kuma, duc

Why local-only? These services default to "no login from local network". Cloudflare Tunnel traffic appears local, bypassing auth. Use Jellyseerr for remote media requests.

## Cloudflare Tunnel

Dashboard path: **Zero Trust → Networks → Connectors → Cloudflare Tunnels → [tunnel] → Configure → Published application routes**

All routes point to `<NAS_IP>:8080` (Traefik). Traefik routes by Host header. See `config.local.md` for actual IPs and tunnel name.

## Pi-hole DNS (v6+)

Uses `pihole.toml`, NOT `custom.list`.

```bash
# Edit hosts array (~line 129) in container:
docker exec pihole sed -n '129p' /etc/pihole/pihole.toml
# Then: docker restart pihole
```

**TLDs**: `.local` fails in Docker (mDNS reserved). Use `.lan` for local DNS.

**Docker services for VPN-routed containers**: Add to Pi-hole so Prowlarr/Sonarr/Radarr can resolve them:
```
192.168.100.10 flaresolverr
```

## Architecture

- **3 compose files**: traefik (infra), arr-stack (apps), cloudflared (tunnel)
- **Network**: traefik-proxy (192.168.100.0/24), static IPs for all services
- **External access**: Cloudflare Tunnel (bypasses CGNAT)

## Adding Services

1. Add to `docker-compose.arr-stack.yml` with static IP
2. Add route to `traefik/dynamic/vpn-services.yml`
3. If VPN-routed: use `network_mode: service:gluetun`
4. Sync compose + traefik config to NAS

## Service Notes

| Service | Note |
|---------|------|
| Pi-hole | v6 API uses password not separate token |
| Gluetun | VPN gateway. Services using it share IP 192.168.100.3. Uses Pi-hole DNS. `FIREWALL_OUTBOUND_SUBNETS` must include LAN for HA access |
| Cloudflared | SSL terminated at Cloudflare, Traefik receives HTTP |
| wg-easy | Generate hash: `docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'PASSWORD'` |
| FlareSolverr | Cloudflare bypass for Prowlarr. Configure in Prowlarr: Settings → Indexers → add FlareSolverr with Host `flaresolverr` |

## Container Updates

UGOS handles automatic updates natively (no Watchtower needed):
- **Docker → Management → Image update**
- Update detection: enabled
- Update as scheduled: weekly

## Backups

Daily backup to USB stick at `/mnt/arr-backup`. Keeps 7 days of backups.

```bash
# Install backup script
sudo cp scripts/arr-backup.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/arr-backup.sh

# Add cron job (3am daily)
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/arr-backup.sh") | sudo crontab -

# Manual backup
sudo /usr/local/bin/arr-backup.sh

# Check logs
cat /var/log/arr-backup.log
```

Backs up: compose files, .env, traefik config, all app data (Sonarr, Radarr, Prowlarr, qBittorrent, Jellyfin, Jellyseerr, Bazarr, Uptime Kuma).

## Uptime Kuma SQLite

**Query monitors:**
```bash
docker exec uptime-kuma sqlite3 /app/data/kuma.db "SELECT id, name, url FROM monitor"
```

**Update monitor URL:**
```bash
docker exec uptime-kuma sqlite3 /app/data/kuma.db "UPDATE monitor SET url='http://NEW_URL' WHERE id=ID"
docker restart uptime-kuma
```

**Add monitors** (must include `user_id=1`):
```bash
docker exec uptime-kuma sqlite3 /app/data/kuma.db "INSERT INTO monitor (name, type, url, interval, accepted_statuscodes_json, ignore_tls, active, maxretries, user_id) VALUES ('Service Name', 'http', 'http://url', 60, '[\"200-299\"]', 0, 1, 3, 1);"
docker restart uptime-kuma
```

For HTTPS with self-signed cert or 401 auth page: `ignore_tls=1`, `accepted_statuscodes_json='[\"200-299\",\"401\"]'`

**Note:** Services using `network_mode: service:gluetun` (qBittorrent, Sonarr, etc.) should use Gluetun's static IP (`192.168.100.3`) in Uptime Kuma, not the hostname.

## Bash Script Gotchas

**SSH command substitution with `set -e`**: When using `set -e` (exit on error), command substitution causes script exit if the command fails. Add `|| true` to prevent this:

```bash
# WRONG - script exits if SSH fails
result=$(ssh_to_nas "some command")

# RIGHT - gracefully handle SSH failure
result=$(ssh_to_nas "some command") || true
if [[ -z "$result" ]]; then
    echo "SKIP: SSH failed"
    return 0
fi
```

This pattern is used in `scripts/lib/check-env-backup.sh` and `check-uptime-monitors.sh`.

## .env Gotchas

**Bcrypt hashes must be quoted** (they contain `$` which Docker interprets as variables):
```bash
# Wrong
WG_PASSWORD_HASH=$2a$12$abc...
TRAEFIK_DASHBOARD_AUTH=admin:$2y$05$abc...

# Correct
WG_PASSWORD_HASH='$2a$12$abc...'
TRAEFIK_DASHBOARD_AUTH='admin:$2y$05$abc...'
```
