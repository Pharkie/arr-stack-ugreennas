# Media Automation Arr Stack

[![GitHub release](https://img.shields.io/github/v/release/Pharkie/arr-stack-ugreennas)](https://github.com/Pharkie/arr-stack-ugreennas/releases)

A Docker Compose stack for automated media management. Request a TV show or movie, and it downloads, organizes, and appears in Jellyfin ready to watch—all routed through a VPN.

Sonarr (TV) and Radarr (movies) handle fetching. Prowlarr manages your indexers. qBittorrent and SABnzbd cover both torrents and Usenet. Bazarr fetches subtitles automatically. Jellyseerr gives family, housemates, or friends a way to browse and request titles.

Gluetun routes downloads through your VPN provider. Traefik manages SSL certificates and local `.lan` domains (`http://sonarr.lan`, `http://jellyfin.lan`—no port numbers to remember). Pi-hole blocks ads, and health checks auto-restart crashed services. WireGuard lets you stream from anywhere—hotel, holiday, wherever—without geo-restrictions. Cloudflare Tunnel handles secure external access to Jellyfin without exposing your home IP.

Developed and tested on Ugreen NAS (DXP4800+) but should work on Synology, QNAP, or any Docker host. Plex variant included; swap VPN providers via environment variables.

> If this project helped you, help others find the repo by giving it a ⭐ or buy me a Ko-fi:
>
> <a href='https://ko-fi.com/X8X01NIXRB' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi6.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

## Legal Notice

This project provides configuration files for **legal, open-source software** designed for managing personal media libraries. All included tools have legitimate purposes - see **[LEGAL.md](docs/LEGAL.md)** for details on intended use, user responsibilities, and disclaimer.

---

## Documentation

| Doc | Purpose |
|-----|---------|
| [Setup Guide](docs/SETUP.md) | Step-by-step deployment |
| [Quick Reference](docs/REFERENCE.md) | URLs, commands, IPs |
| [Updating](docs/UPDATING.md) | Pull updates, redeploy |
| [Backup & Restore](docs/BACKUP.md) | Backup configs, restore |
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

**Core Stack**
- **Media streaming** with Jellyfin (or Plex variant available)
- **Automated downloads** with Sonarr (TV), Radarr (movies), Prowlarr (indexers), Bazarr (subtitles)
- **Request system** via Jellyseerr—let friends/family request titles
- **VPN-protected** downloads via Gluetun (supports 30+ providers)
- **Remote streaming** from anywhere via WireGuard VPN server
- **Ad-blocking DNS** with Pi-hole
- **Automated SSL** via Traefik + Cloudflare

**Operational**
- **Auto-recovery** restarts services when VPN reconnects
- **Backup script** for essential configs (~13MB)
- **Service monitoring** with Uptime Kuma dashboard
- **Torrent scheduler** pauses overnight for disk spin-down

**For Contributors**
- **Pre-commit hooks** validate secrets, YAML, port conflicts
- **Claude Code ready** for AI-assisted deployment
- See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

Documentation, configuration files, and examples in this repository are licensed under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) (Attribution-NonCommercial). Individual software components (Sonarr, Radarr, Jellyfin, etc.) retain their own licenses.

## Acknowledgments

Forked from [TheRealCodeVoyage/arr-stack-setup-with-pihole](https://github.com/TheRealCodeVoyage/arr-stack-setup-with-pihole). Thanks to [@benjamin-awd](https://github.com/benjamin-awd) for VPN config improvements.

---

> If this project helped you, help others find the repo by giving it a ⭐ or buy me a Ko-fi:
>
> <a href='https://ko-fi.com/X8X01NIXRB' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi6.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
