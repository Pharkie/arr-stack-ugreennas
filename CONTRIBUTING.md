# Contributing

For contributors, forks, and anyone wanting to understand the project internals.

---

## Project Structure

```
arr-stack-ugreennas/
├── docker-compose.traefik.yml      # Traefik reverse proxy
├── docker-compose.arr-stack.yml    # Main media stack (Jellyfin)
├── docker-compose.utilities.yml    # Optional utilities (monitoring, disk usage)
├── docker-compose.plex-arr-stack.yml  # Plex variant (untested)
├── docker-compose.cloudflared.yml  # Cloudflare tunnel
├── traefik/                        # Traefik configuration
│   ├── traefik.yml                 # Static config
│   └── dynamic/
│       ├── tls.yml                 # TLS settings
│       ├── vpn-services.yml        # Service routing (Jellyfin)
│       ├── vpn-services-plex.yml   # Service routing (Plex variant)
│       └── utilities.yml           # Utilities routing
├── .env.example                    # Environment template
├── .env                            # Your configuration (gitignored)
├── docs/                           # Documentation
│   ├── SETUP.md                    # Complete setup guide
│   └── LEGAL.md                    # Legal notice
├── .claude/
│   ├── instructions.md             # AI assistant instructions
│   ├── config.local.md.example     # Private config template
│   └── config.local.md             # Your private config (gitignored)
├── scripts/                        # Pre-commit hooks
└── README.md
```

---

## Architecture

### Network Topology

```
Internet → Cloudflare Tunnel (or Router Port Forward 80→8080, 443→8443)
                            │
                            ▼
           Traefik (listening on 8080/8443 on NAS)
                            │
                            ├─► Jellyfin, Jellyseerr, Bazarr (Direct)
                            │
                            └─► Gluetun (VPN Gateway)
                                    │
                                    └─► qBittorrent, Sonarr, Radarr, Prowlarr
                                        (Privacy-protected services)
```

### Multi-File Architecture

This project uses **separate Docker Compose files** for each layer:

| File | Layer | Purpose |
|------|-------|---------|
| `docker-compose.traefik.yml` | Infrastructure | Reverse proxy, SSL, networking |
| `docker-compose.cloudflared.yml` | Infrastructure | External access via Cloudflare |
| `docker-compose.arr-stack.yml` | Application | Media services |
| `docker-compose.utilities.yml` | Optional | Monitoring, disk usage tools |

**Why separate files?**
- Independent lifecycle management
- One Traefik can serve multiple stacks
- Easier troubleshooting with isolated logs
- Optional components can be skipped

**Deployment order**: Traefik first (creates network) → cloudflared → arr-stack → utilities (optional).

### Storage Structure

```
/volume1/
├── Media/
│   ├── downloads/    # qBittorrent
│   ├── tv/           # TV shows
│   └── movies/       # Movies
└── docker/
    └── arr-stack/    # Application configs
```

---

## Documentation Strategy

This project separates public documentation from private configuration:

| Type | Location | Git Tracked | Contains |
|------|----------|-------------|----------|
| **Public docs** | `docs/*.md`, `README.md` | Yes | Generic instructions with placeholders |
| **Private config** | `.claude/config.local.md` | No | Actual hostnames, IPs, usernames |
| **Credentials** | `.env` | No | Passwords, API tokens, private keys |

**Setup**: Copy `.claude/config.local.md.example` to `.claude/config.local.md` and fill in your values.

---

## Pre-commit Hooks

This repo includes validation hooks that run on `git commit`:

| Check | Blocks? | Purpose |
|-------|---------|---------|
| Secrets | Yes | Detects real API keys, private keys, bcrypt hashes |
| Env vars | Yes | Ensures compose `${VAR}` are documented in `.env.example` |
| YAML syntax | Yes | Catches invalid YAML before it breaks deployment |
| Port/IP conflicts | Yes | Detects duplicate ports or static IPs |
| Compose drift | Warn | Flags Jellyfin/Plex inconsistencies |
| Hardcoded domain | Warn | Flags your domain in tracked files |
| NAS .env backup | Warn | Checks `.env.nas.backup` matches NAS |
| Uptime monitors | Warn | Checks Uptime Kuma monitors match services |

### Install

```bash
./setup-hooks.sh
```

### Optional: PyYAML for full YAML validation

The YAML syntax check works best with PyYAML installed. Without it, only basic checks (tab detection) run.

```bash
pip3 install --break-system-packages --user pyyaml
```

### Test manually

```bash
./scripts/pre-commit
```

### Uninstall

```bash
rm .git/hooks/pre-commit
```

### SSH-based Checks (NAS .env backup, Uptime monitors)

The last two checks require SSH access to your NAS. They gracefully skip when:
- NAS is not reachable (ping fails)
- SSH port is blocked/closed
- SSH authentication fails

**To enable these checks:**

1. **SSH key authentication** (recommended):
   ```bash
   ssh-copy-id your-user@your-nas.local
   ```

2. **Docker group membership** (for Uptime monitors check):
   ```bash
   # On NAS - allows docker commands without sudo
   sudo usermod -aG docker your-user
   # Log out and back in for group change to take effect
   ```

3. **Alternative: password auth** via `NAS_SSH_PASS` env var (requires `sshpass` installed)

## Structure

```
scripts/
├── pre-commit              # Main hook (symlinked from .git/hooks/)
└── lib/
    ├── check-secrets.sh
    ├── check-env-vars.sh
    ├── check-yaml-syntax.sh
    ├── check-conflicts.sh
    ├── check-compose-drift.sh
    ├── check-hardcoded-domain.sh
    ├── check-env-backup.sh
    └── check-uptime-monitors.sh
```
