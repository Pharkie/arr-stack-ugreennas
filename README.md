# Media Automation Stack for Ugreen NAS

A complete, production-ready Docker Compose stack for automated media management with VPN routing, SSL certificates, and remote access.

**Specifically designed and tested for Ugreen NAS DXP4800+** with comprehensive documentation covering deployment, configuration, troubleshooting, and production best practices.

> **Note**: Tested on Ugreen NAS DXP4800+. Should work on other Ugreen models and Docker-compatible NAS devices, but may require adjustments.

## Features

- **VPN-routed downloads** via Gluetun + Surfshark
- **Automated SSL/TLS** certificates via Traefik + Cloudflare
- **Media automation** with Sonarr, Radarr, Prowlarr, Bazarr
- **Media streaming** with Jellyfin
- **Request management** with Jellyseerr
- **Remote access** via WireGuard VPN
- **Ad-blocking DNS** with Pi-hole
- **Unified dashboard** with Homarr

## Services Included

| Service | Description | Port/URL |
|---------|-------------|----------|
| **Traefik** | Reverse proxy with automatic SSL | traefik.yourdomain.com |
| **Gluetun** | VPN gateway (Surfshark) | Internal |
| **qBittorrent** | Torrent client (VPN-routed) | qbit.yourdomain.com |
| **Sonarr** | TV show automation | sonarr.yourdomain.com |
| **Radarr** | Movie automation | radarr.yourdomain.com |
| **Prowlarr** | Indexer manager | prowlarr.yourdomain.com |
| **Bazarr** | Subtitle automation | bazarr.yourdomain.com |
| **Jellyfin** | Media server | jellyfin.yourdomain.com |
| **Jellyseerr** | Media requests | jellyseerr.yourdomain.com |
| **Pi-hole** | DNS + Ad-blocking | pihole.yourdomain.com |
| **WireGuard** | VPN server | wg.yourdomain.com |
| **Homarr** | Dashboard | homarr.yourdomain.com |
| **FlareSolverr** | Cloudflare bypass | Internal |
| **Notifiarr** | Notifications | notifiarr.yourdomain.com |

## Quick Start

### Prerequisites

- Ugreen NAS DXP4800+ (tested) or compatible Docker-capable NAS device
- Domain name registered
- Cloudflare account (free tier works)
- Surfshark VPN subscription
- Ports 80, 443, 51820/udp forwarded to NAS

### Installation

1. **Clone repository**:
   ```bash
   git clone https://github.com/yourusername/arr-stack-ugreennas.git
   cd arr-stack-ugreennas
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   nano .env
   ```
   Fill in your domain, API tokens, and credentials.

3. **Set up DNS** (see [DNS Setup Guide](docs/DNS-SETUP.md))

4. **Deploy Traefik**:
   ```bash
   docker compose -f docker-compose.traefik.yml up -d
   ```

5. **Deploy media stack**:
   ```bash
   docker compose -f docker-compose.arr-stack.yml up -d
   ```

## Documentation

📖 **Complete documentation in the [`docs/`](docs/) folder**:

- **[Ugreen NAS Setup Guide](docs/README-UGREEN.md)** - Complete setup guide for new users
- **[Deployment Plan](docs/DEPLOYMENT-PLAN.md)** - Step-by-step deployment checklist
- **[DNS Setup Guide](docs/DNS-SETUP.md)** - Cloudflare DNS configuration
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## Project Structure

```
arr-stack-ugreennas/
├── docker-compose.traefik.yml      # Traefik reverse proxy
├── docker-compose.arr-stack.yml    # Main media stack
├── traefik/                        # Traefik configuration
│   ├── traefik.yml                 # Static config
│   └── dynamic/
│       └── tls.yml                 # TLS settings
├── .env.example                    # Environment template
├── .env                            # Your configuration (gitignored)
├── docs/                           # Documentation
│   ├── README-UGREEN.md
│   ├── DEPLOYMENT-PLAN.md
│   ├── DNS-SETUP.md
│   └── TROUBLESHOOTING.md
└── README.md                       # This file
```

## Architecture

### Network Topology

```
Internet → Port 80/443 → Traefik (Reverse Proxy)
                            │
                            ├─► Jellyfin, Jellyseerr, Bazarr (Direct)
                            │
                            └─► Gluetun (VPN Gateway)
                                    │
                                    └─► qBittorrent, Sonarr, Radarr, Prowlarr
                                        (VPN-routed for privacy)
```

### Three-File Architecture

This project uses **three separate Docker Compose files** (not one):

- **`docker-compose.traefik.yml`** - Infrastructure layer (reverse proxy, SSL, networking)
- **`docker-compose.arr-stack.yml`** - Application layer (media services)
- **`docker-compose.cloudflared.yml`** - Tunnel layer (external access via Cloudflare)

**Why?** This separation provides:
- Independent lifecycle management (update services without affecting Traefik)
- Scalability (one Traefik can serve multiple stacks)
- Clean architecture (infrastructure vs. application vs. tunnel concerns)
- Easier troubleshooting (isolated logs and configs)

**Deployment order matters**: Deploy Traefik first (creates network), then cloudflared, then arr-stack.

See [Architecture section in README-UGREEN.md](docs/README-UGREEN.md#why-three-separate-docker-compose-files) for detailed explanation.

### Storage Structure

```
/volume1/
├── Media/
│   ├── downloads/          # qBittorrent downloads
│   ├── tv/                 # TV shows
│   └── movies/             # Movies
│
└── docker/
    └── arr-stack/          # Application configs
        ├── gluetun-config/
        ├── traefik/
        ├── homarr/
        └── ...
```

## Configuration

### Required Environment Variables

Edit `.env` with your values:

```bash
# Domain
DOMAIN=yourdomain.com

# Cloudflare
CF_DNS_API_TOKEN=your_cloudflare_api_token

# Surfshark VPN
SURFSHARK_USER=your_username
SURFSHARK_PASSWORD=your_password

# Passwords
PIHOLE_UI_PASS=your_pihole_password
WG_PASSWORD_HASH=bcrypt_hash_here
TRAEFIK_DASHBOARD_AUTH=htpasswd_hash_here
```

See [`.env.example`](.env.example) for complete configuration.

## Deployment

For detailed deployment instructions, see:
- **[Deployment Plan](docs/DEPLOYMENT-PLAN.md)** - Step-by-step guide
- **[README-UGREEN.md](docs/README-UGREEN.md)** - Complete setup for new users

### Quick Deploy

```bash
# 1. Create Docker network
docker network create \
  --driver=bridge \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  traefik-proxy

# 2. Deploy Traefik
docker compose -f docker-compose.traefik.yml up -d

# 3. Deploy services (staged)
docker compose -f docker-compose.arr-stack.yml up -d gluetun
docker compose -f docker-compose.arr-stack.yml up -d qbittorrent
docker compose -f docker-compose.arr-stack.yml up -d sonarr radarr prowlarr
docker compose -f docker-compose.arr-stack.yml up -d jellyfin jellyseerr bazarr
docker compose -f docker-compose.arr-stack.yml up -d pihole wg-easy homarr
```

## Updating

```bash
# Pull latest images
docker compose -f docker-compose.arr-stack.yml pull

# Recreate containers
docker compose -f docker-compose.arr-stack.yml up -d
```

## Backup

Important volumes to backup:
- All `*-config` Docker volumes
- `/volume1/docker/arr-stack/` directory
- `/volume1/Media/` directory (optional, can be large)

```bash
# Example: Backup Sonarr config
docker run --rm \
  -v sonarr-config:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/sonarr-config-$(date +%Y%m%d).tar.gz -C /data .
```

## Troubleshooting

Having issues? Check the **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)**.

Common issues:
- VPN not connecting → Check Surfshark credentials
- SSL certificates not working → Verify Cloudflare API token
- Services not accessible → Check port forwarding (80, 443)
- Downloads not working → Verify Gluetun VPN connection

## Security Considerations

- All services use HTTPS with automatic SSL certificates
- Torrent traffic is VPN-routed (prevents IP leaks)
- Pi-hole provides DNS-level ad-blocking
- WireGuard enables secure remote access
- Consider restricting *arr apps to local/VPN access only

## Customization

### Using a Different VPN Provider

Edit `docker-compose.arr-stack.yml`:

```yaml
gluetun:
  environment:
    - VPN_SERVICE_PROVIDER=nordvpn  # or protonvpn, etc.
```

See [Gluetun providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers) for full list.

### Adding Services

1. Add service to `docker-compose.arr-stack.yml`
2. Add Traefik labels for reverse proxy
3. Add DNS record in Cloudflare
4. Deploy: `docker compose -f docker-compose.arr-stack.yml up -d`

## Support & Resources

- **Documentation**: [`docs/`](docs/) folder
- **Gluetun**: https://github.com/qdm12/gluetun
- **Traefik**: https://doc.traefik.io/
- **Servarr Wiki**: https://wiki.servarr.com/
- **LinuxServer.io**: https://docs.linuxserver.io/

## License

This project is provided as-is for personal use. Service-specific licenses apply to individual components.

## Acknowledgments

Built with:
- [Traefik](https://traefik.io/) - Reverse proxy
- [Gluetun](https://github.com/qdm12/gluetun) - VPN gateway
- [LinuxServer.io](https://www.linuxserver.io/) - Container images
- [Servarr](https://wiki.servarr.com/) - Automation suite
- [Jellyfin](https://jellyfin.org/) - Media server

## References

Initial inspiration from:
- [Master the *arr Stack](https://www.youtube.com/watch?v=wMs8Ry9oFdc) - Basic arr stack setup
- [Complete Your arr Stack](https://www.youtube.com/watch?v=oaQD-d2kg-I) - Additional services (Bazarr, Jellyseerr, Notifiarr, FlareSolverr)

**Note**: This project has been significantly extended beyond the original tutorials with:
- Ugreen NAS DXP4800+-specific configuration and testing
- Cloudflare Tunnel support for CGNAT bypass
- Comprehensive documentation for production deployment
- Troubleshooting guides based on real-world deployment
- Security best practices and sanitized configuration examples

---

**Need help?** Start with the [README-UGREEN.md](docs/README-UGREEN.md) guide or check [Troubleshooting](docs/TROUBLESHOOTING.md).
