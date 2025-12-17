# Media Automation Stack for Ugreen NAS

A complete, production-ready Docker Compose stack for automated media management with VPN routing, SSL certificates, and remote access.

**Tested on Ugreen NAS DXP4800+** but should work on any Docker host (Synology, QNAP, Linux server, etc.).

## Legal Notice

This project provides configuration files for **legal, open-source software** designed for managing personal media libraries. All included tools have legitimate purposes - see **[LEGAL.md](docs/LEGAL.md)** for details on intended use, user responsibilities, and disclaimer.

---

## Documentation

| Doc | Purpose |
|-----|---------|
| **[Setup Guide](docs/SETUP.md)** | Step-by-step deployment |
| [Quick Reference](docs/REFERENCE.md) | URLs, commands, IPs |
| [Updating](docs/UPDATING.md) | Pull updates, redeploy |
| [Home Assistant](docs/HOME-ASSISTANT.md) | Notifications integration |
| [Legal](docs/LEGAL.md) | Intended use, disclaimer |

<details>
<summary>Using Claude Code for guided setup</summary>

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) can walk you through deployment, executing commands and troubleshooting as you go. Works in terminal, VS Code, or Cursor.

```bash
npm install -g @anthropic-ai/claude-code
cd arr-stack-ugreennas && claude
```

Ask Claude to help deploy the stack - it reads [`.claude/instructions.md`](.claude/instructions.md) automatically.

</details>

---

## Features

- **VPN-protected networking** via Gluetun (supports 30+ providers)
- **Automated SSL/TLS** certificates via Traefik + Cloudflare
- **Media library management** with Sonarr, Radarr, Prowlarr, Bazarr
- **Media streaming** with Jellyfin (or Plex - see below)
- **Request management** with Jellyseerr (or Overseerr for Plex)
- **Remote access** via WireGuard VPN
- **Ad-blocking DNS** with Pi-hole

## Services

### `docker-compose.traefik.yml` - Infrastructure

| Service | Description | Local Port | Domain URL |
|---------|-------------|------------|------------|
| **Traefik** | Reverse proxy with automatic SSL | 8080, 8443, 9090 | traefik.yourdomain.com |

### `docker-compose.cloudflared.yml` - External Access *(optional - for remote access)*

| Service | Description | Local Port | Domain URL |
|---------|-------------|------------|------------|
| **Cloudflared** | Cloudflare Tunnel for remote access | - | Internal |

### `docker-compose.arr-stack.yml` - Media Stack

**User-facing services** (local + remote access if configured):

| Service | Description | Local | Remote (if configured) |
|---------|-------------|-------|------------------------|
| **Jellyfin** | Media streaming server | NAS_IP:8096 | jellyfin.yourdomain.com |
| **Jellyseerr** | Media request system | NAS_IP:5055 | jellyseerr.yourdomain.com |
| **WireGuard** | VPN server for remote access | NAS_IP:51820/udp | wg.yourdomain.com |

**Admin services** (local-only for security):

| Service | Description | Local |
|---------|-------------|-------|
| **Gluetun** | VPN gateway for network privacy | - |
| **qBittorrent** | BitTorrent client (VueTorrent UI) | NAS_IP:8085 |
| **Sonarr** | TV show library management | NAS_IP:8989 |
| **Radarr** | Movie library management | NAS_IP:7878 |
| **Prowlarr** | Search aggregator | NAS_IP:9696 |
| **Bazarr** | Subtitle management | NAS_IP:6767 |
| **Pi-hole** | DNS + Ad-blocking | NAS_IP:8081 |
| **FlareSolverr** | CAPTCHA solver | NAS_IP:8191 |

> **Don't need all these?** Remove any service by deleting its section from the compose file. Core dependency: Gluetun (VPN gateway).
>
> **Prefer Plex?** See `docker-compose.plex-arr-stack.yml` for an untested Plex/Overseerr variant.

### `docker-compose.utilities.yml` - Optional Utilities

| Service | Description | Local | Remote |
|---------|-------------|-------|--------|
| **deunhealth** | Auto-restart services if VPN drops and recovers | - | - |
| **Uptime Kuma** | Service monitoring dashboard | NAS_IP:3001 | Via WireGuard |
| **duc** | Disk usage analyzer (treemap UI) | NAS_IP:8838 | Via WireGuard |
| **qbit-scheduler** | Pauses torrents overnight (20:00-06:00) for disk spin-down | - | - |

## Deployment Options

### Option A: Remote Access (Recommended)

Access your services from anywhere - phone on mobile data, travelling, etc. Requires a cheap domain (~$10/year):
- **Remote access** from anywhere via Cloudflare Tunnel
- **SSL/HTTPS** with automatic certificates
- **Pretty URLs** like `jellyfin.yourdomain.com`
- **WireGuard VPN** for secure access to your home network

**Requirements:** Domain name, Cloudflare account (free), VPN subscription

> **Cloudflare:** This stack is configured for Cloudflare (DNS + Tunnel). Other DNS providers work but you'll need to modify `docker-compose.traefik.yml` and `traefik/traefik.yml`. See [Traefik ACME docs](https://doc.traefik.io/traefik/https/acme/).
>
> **VPN:** Configured for Surfshark but Gluetun supports 30+ providers (NordVPN, PIA, Mullvad, etc.). See [Gluetun providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers).

### Option B: Local Network Only (No Domain)

Skip the domain and access services directly via IP:port. All services work out of the box:
- `http://NAS_IP:8096` → Jellyfin
- `http://NAS_IP:5055` → Jellyseerr
- `http://NAS_IP:8989` → Sonarr
- `http://NAS_IP:7878` → Radarr
- `http://NAS_IP:9696` → Prowlarr
- `http://NAS_IP:8085` → qBittorrent
- `http://NAS_IP:6767` → Bazarr
- `http://NAS_IP:53` → Pi-hole DNS

**What works:** All media automation, VPN-protected downloads, Pi-hole DNS, local streaming

**What you lose:** Remote access, HTTPS, subdomain routing, WireGuard remote VPN

**To deploy local-only:**
1. Skip `docker-compose.traefik.yml` and `docker-compose.cloudflared.yml`
2. Deploy: `docker compose -f docker-compose.arr-stack.yml up -d`
3. Access via `http://NAS_IP:PORT`


## Security

**Many services default to NO authentication!** After deployment, enable authentication on:

| Service | Default Auth | Action Required |
|---------|--------------|-----------------|
| Bazarr | Disabled | Enable Forms auth, regenerate API key |
| Sonarr/Radarr/Prowlarr | Disabled for Local | Set to Forms + Enabled |
| qBittorrent | Bypass localhost | Disable bypass, change default password |

**Cloudflare Tunnel warning**: Tunnel traffic appears as localhost, bypassing "Disabled for Local Addresses" auth.

See [Security Checklist](docs/SETUP.md#59-security-checklist) in Setup Guide for details.

## License

Documentation, configuration files, and examples in this repository are licensed under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) (Attribution-NonCommercial). Individual software components (Sonarr, Radarr, Jellyfin, etc.) retain their own licenses.

## Acknowledgments

Forked from [TheRealCodeVoyage/arr-stack-setup-with-pihole](https://github.com/TheRealCodeVoyage/arr-stack-setup-with-pihole). Thanks to [@benjamin-awd](https://github.com/benjamin-awd) for VPN config improvements.
