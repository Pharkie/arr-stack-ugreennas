# Setup Guide

Complete setup guide for the media automation stack. Works on any Docker host with platform-specific notes in collapsible sections.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Stack Overview](#stack-overview)
- [Step 1: Create Directories and Clone/Fork Repository](#step-1-create-directories-and-clonefork-repository)
- [Step 2: Configure Settings](#step-2-configure-settings)
- [Step 3: Start the Stack](#step-3-start-the-stack)
- [Step 4: Configure Each App](#step-4-configure-each-app)
- [Step 5: Test](#step-5-test)
- [External Access (Optional)](#external-access-optional)
- [Backup](#backup)
- [Optional Utilities](#optional-utilities)

**See also:** [Quick Reference](REFERENCE.md) · [Upgrading](UPGRADING.md) · [Home Assistant Integration](HOME-ASSISTANT.md)

---

## Prerequisites

### Hardware
- Docker host (NAS, server, Raspberry Pi 4+, etc.)
- Minimum 4GB RAM (8GB+ recommended)
- Storage for media files
- Support for `/dev/net/tun` (for VPN)

### Software
- Docker Engine 20.10+
- Docker Compose v2.0+
- Git (for deployment)
- SSH access to your host

### Required Services
- **VPN Subscription** - Any provider supported by [Gluetun](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers) (Surfshark, NordVPN, PIA, Mullvad, ProtonVPN, etc.)

### For Usenet downloads (optional)
- **Usenet Provider** (~$4-6/month) - Frugal Usenet, Newshosting, Eweka, etc.
- **Usenet Indexer** - NZBGeek (~$12/year) or DrunkenSlug (free tier)

> **Why Usenet?** More reliable than public torrents (no fakes), faster downloads, SSL-encrypted (no VPN needed). See [SABnzbd setup](#55-sabnzbd-usenet-downloads-optional).

### For remote access (optional)
- **Domain Name** (~$8-10/year)
- **Cloudflare Account** (free tier)

---

## Stack Overview

The stack is split into four Docker Compose files so you can deploy only what you need. See [Quick Reference](REFERENCE.md) for .lan URLs and network details.

| File | Purpose | Required? |
|------|---------|-----------|
| `docker-compose.traefik.yml` | Reverse proxy, SSL certificates, .lan domains | Yes |
| `docker-compose.arr-stack.yml` | Media stack (Jellyfin, *arr apps, downloads) | Yes |
| `docker-compose.cloudflared.yml` | Remote access via Cloudflare Tunnel | Optional |
| `docker-compose.utilities.yml` | Monitoring, auto-recovery, disk usage | Optional |

> **Prefer Plex?** Use `docker-compose.plex-arr-stack.yml` instead of `arr-stack` (untested).

### `docker-compose.traefik.yml`

| Service | Description | Port |
|---------|-------------|------|
| **Traefik** | Reverse proxy, SSL, .lan domains | 8080, 8443 |

### `docker-compose.arr-stack.yml`

| Service | Description | Port |
|---------|-------------|------|
| **Jellyfin** | Media streaming | 8096 |
| **Jellyseerr** | Request system | 5055 |
| **Sonarr** | TV management | 8989 |
| **Radarr** | Movie management | 7878 |
| **Prowlarr** | Indexer manager | 9696 |
| **qBittorrent** | Torrent client | 8085 |
| **SABnzbd** | Usenet client | 8082 |
| **Bazarr** | Subtitles | 6767 |
| **Gluetun** | VPN gateway | - |
| **Pi-hole** | DNS/ad-blocking | 8081 |
| **WireGuard** | VPN server for remote access | 51820/udp |
| **FlareSolverr** | CAPTCHA bypass | 8191 |

> **Don't need all these?** Remove any service from the compose file. Core dependency: Gluetun.

### `docker-compose.utilities.yml`

| Service | Description | Port |
|---------|-------------|------|
| **deunhealth** | Auto-restart on VPN reconnect | - |
| **Uptime Kuma** | Monitoring dashboard | 3001 |
| **duc** | Disk usage treemap | 8838 |
| **qbit-scheduler** | Pause torrents overnight | - |

---

## Step 1: Create Directories and Clone/Fork Repository

Create media folders and get the repository onto your Docker host.

**Clone or Fork?**
- **Clone** (simpler): Just want to use the stack, pull updates occasionally
- **Fork** (recommended): Plan to add your own services (e.g., Audiobookshelf, Nextcloud), want to contribute improvements back, or keep your own version

To fork: Click "Fork" on GitHub, then clone your fork instead of this repo.

<details>
<summary><strong>Ugreen NAS (UGOS)</strong></summary>

Folders created via SSH don't appear in UGOS Files app. Create top-level folders via GUI for visibility.

1. Open UGOS web interface → **Files** app
2. Create shared folders: **Media**, **docker**
3. Inside **Media**, create subfolders: **downloads**, **tv**, **movies**
4. Via SSH, install git and clone:

```bash
ssh your-username@nas-ip

# Install git (Ugreen NAS uses Debian)
sudo apt-get update && sudo apt-get install -y git

# Clone the repo
cd /volume1/docker
sudo git clone https://github.com/Pharkie/arr-stack-ugreennas.git arr-stack  # or your fork
sudo chown -R 1000:1000 /volume1/docker/arr-stack

# Prepare Traefik certificate storage
sudo touch /volume1/docker/arr-stack/traefik/acme.json
sudo chmod 600 /volume1/docker/arr-stack/traefik/acme.json
```

**Note:** Use `sudo` for Docker commands on Ugreen NAS. Service configs are stored in Docker named volumes (auto-created on first run).

</details>

<details>
<summary><strong>Synology / QNAP</strong></summary>

Use File Station to create:
- **Media** shared folder with subfolders: downloads, tv, movies
- **docker** shared folder

Then via SSH:
```bash
ssh your-username@nas-ip

# Install git if not present (Synology)
sudo synopkg install Git

# Clone the repo
cd /volume1/docker
sudo git clone https://github.com/Pharkie/arr-stack-ugreennas.git arr-stack  # or your fork
sudo chown -R 1000:1000 /volume1/docker/arr-stack

# Prepare Traefik certificate storage
sudo touch /volume1/docker/arr-stack/traefik/acme.json
sudo chmod 600 /volume1/docker/arr-stack/traefik/acme.json
```

</details>

<details>
<summary><strong>Linux Server / Generic</strong></summary>

```bash
# Install git if needed
sudo apt-get update && sudo apt-get install -y git

# Create media directories
sudo mkdir -p /srv/media/{downloads,tv,movies}
sudo chown -R 1000:1000 /srv/media

# Clone the repo
cd /srv/docker
sudo git clone https://github.com/Pharkie/arr-stack-ugreennas.git arr-stack  # or your fork
sudo chown -R 1000:1000 /srv/docker/arr-stack

# Prepare Traefik certificate storage
sudo touch /srv/docker/arr-stack/traefik/acme.json
sudo chmod 600 /srv/docker/arr-stack/traefik/acme.json
```

**Note:** Adjust paths in docker-compose files if using different locations. Service configs are stored in Docker named volumes (auto-created on first run).

</details>

> **Note:** From this point forward, all commands should be run **on your NAS via SSH** unless otherwise noted. If you closed your terminal, reconnect with `ssh your-username@nas-ip` and `cd` to your deployment directory.

### Expected Structure

```
/volume1/  (or /srv/)
├── Media/
│   ├── downloads/    # qBittorrent downloads
│   ├── tv/           # TV shows (Sonarr → Jellyfin)
│   └── movies/       # Movies (Radarr → Jellyfin)
└── docker/
    └── arr-stack/
        ├── traefik/              # User-edited config (bind mount)
        │   ├── traefik.yml
        │   ├── acme.json         # SSL certificates (chmod 600)
        │   └── dynamic/
        │       └── tls.yml
        └── cloudflared/          # User-edited config (bind mount)
            └── config.yml
```

> **Note:** Service data (Sonarr, Radarr, Jellyfin, etc.) is stored in Docker named volumes, automatically managed by Docker. Only `traefik/` and `cloudflared/` are local directories for user-edited configuration.

---

## Step 2: Configure Settings

### 2.1 Create .env For Your Config

```bash
cp .env.example .env
```

### 2.2 Media Storage Path

Set `MEDIA_ROOT` in `.env` to match your media folder location:

```bash
# Examples:
MEDIA_ROOT=/volume1/Media     # Ugreen, Synology
MEDIA_ROOT=/share/Media       # QNAP
MEDIA_ROOT=/srv/media         # Linux server
```

This path should contain (or will contain) your `downloads`, `tv`, and `movies` subfolders.

### 2.3 Configure VPN

Add your VPN credentials to `.env`. Gluetun supports 30+ providers—find yours below:

<details>
<summary><strong>Surfshark (WireGuard)</strong></summary>

| Step | Screenshot |
|:-----|:-----------|
| 1. Go to [my.surfshark.com](https://my.surfshark.com/) → VPN → Manual Setup → Router → WireGuard | <img src="images/Surfshark/1.png" width="700"> |
| 2. Select **"I don't have a key pair"** | <img src="images/Surfshark/2.png" width="700"> |
| 3. Under Credentials, enter a name (e.g., `ugreen-nas`) | <img src="images/Surfshark/3.png" width="700"> |
| 4. Click **"Generate a new key pair"** and copy both keys to your notes | <img src="images/Surfshark/4.png" width="700"> |
| 5. Click **"Choose location"** and select a server (e.g., United Kingdom) | <img src="images/Surfshark/5.png" width="700"> |
| 6. Click the **Download** arrow to get the `.conf` file | <img src="images/Surfshark/6.png" width="700"> |

7. Open the downloaded `.conf` file and note the `Address` value:
   ```ini
   [Interface]
   Address = 10.14.0.2/16          ← Copy this
   PrivateKey = (already copied)
   ```

8. Add to `.env`:
   ```bash
   VPN_SERVICE_PROVIDER=surfshark
   VPN_TYPE=wireguard
   WIREGUARD_PRIVATE_KEY=your_private_key_here
   WIREGUARD_ADDRESSES=10.14.0.2/16
   VPN_COUNTRIES=United Kingdom
   ```

> **Note:** `VPN_COUNTRIES` in your `.env` maps to Gluetun's `SERVER_COUNTRIES` env var (a fixed name we can't change). We use the clearer name in `.env`.

</details>

<details>
<summary><strong>Other Providers (NordVPN, PIA, Mullvad, etc.)</strong></summary>

See the Gluetun wiki for your provider:
- [NordVPN](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/nordvpn.md)
- [Private Internet Access](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/private-internet-access.md)
- [Mullvad](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/mullvad.md)
- [ProtonVPN](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/protonvpn.md)
- [All providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)

Update `.env` with your provider's required variables.

</details>

> **Don't want Pi-hole?** Change `DNS_ADDRESS=172.20.0.5` to `DNS_ADDRESS=1.1.1.1` in `docker-compose.arr-stack.yml`.

### 2.4 Create Passwords

**Pi-hole Password:**

Invent a password. Or, to generate a random one:
```bash
openssl rand -base64 24
```
Add to `.env`: `PIHOLE_UI_PASS=your_password`

**WireGuard Password Hash** (for remote VPN access):

Invent a password for the WireGuard admin UI and note it down, then generate its hash:
```bash
docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'your_chosen_password'
```
Copy the `$2a$12$...` hash output and add to `.env`:
```bash
WG_PASSWORD_HASH=$2a$12$your_generated_hash
```

**Traefik Dashboard Auth** (if using external access):

Invent a password for the Traefik dashboard and note it down, then generate the auth string:
```bash
docker run --rm httpd:alpine htpasswd -nb admin 'your_chosen_password' | sed -e s/\\$/\\$\\$/g
```
Add the output to `.env`: `TRAEFIK_DASHBOARD_AUTH=admin:$$apr1$$...`

**Important:** The `.env` file contains secrets - never commit it to git.

---

## Step 3: Start the Stack

### 3.1 Create Docker Network

> **Retrying after a failed deployment?** Clean up orphaned networks first:
> ```bash
> # Check for orphaned networks
> ./scripts/check-network.sh
>
> # Or clean all unused networks
> docker network prune
> ```

```bash
docker network create \
  --driver=bridge \
  --subnet=172.20.0.0/24 \
  --gateway=172.20.0.1 \
  traefik-proxy
```

### 3.2 Deploy

```bash
# Deploy Traefik (reverse proxy)
docker compose -f docker-compose.traefik.yml up -d

# Deploy media stack
docker compose -f docker-compose.arr-stack.yml up -d
```

> **Want external access?** See [External Access](#external-access-optional) after completing setup.

### 3.3 Verify Deployment

```bash
# Check all containers are running
docker ps

# Check VPN connection
docker logs gluetun | grep -i "connected"

# Verify VPN IP (should NOT be your home IP)
docker exec gluetun wget -qO- ifconfig.me
```

---

## Step 4: Configure Each App

Your stack is running! Now configure each app to work together. They're roughly ordered by dependency.

> **VPN Network Sharing:** Sonarr, Radarr, Prowlarr, and qBittorrent share Gluetun's network (for VPN protection). They reach each other via `localhost`. Services outside gluetun (Jellyseerr, Bazarr) reach them via `gluetun` hostname or `172.20.0.3`. See [Quick Reference](REFERENCE.md) for details.

### 4.1 qBittorrent

Torrent download client.

1. **Access:** `http://HOST_IP:8085`
2. **Get temporary password** (qBittorrent 4.6.1+ generates a random password):
   ```bash
   # Run this on your NAS via SSH:
   docker logs qbittorrent 2>&1 | grep "temporary password"
   ```
   Look for: `A temporary password is provided for this session: <password>`

   <details>
   <summary><strong>Ugreen NAS:</strong> Using UGOS Docker GUI instead</summary>

   You can also find the password in the UGOS web interface:
   1. Open Docker → Container → qbittorrent → Log tab
   2. Search for "password"

   ![UGOS Docker logs](images/qbit/1.png)

   </details>

3. **Login:** Username `admin`, password from step 2
4. **Change password immediately:** Tools → Options → Web UI → Authentication
5. **Create categories:** Right-click categories → Add
   - `sonarr` → Save path: `/downloads/sonarr`
   - `radarr` → Save path: `/downloads/radarr`

> **Mobile access?** The default UI is poor on mobile. [VueTorrent](https://github.com/VueTorrent/VueTorrent) is pre-installed—enable it at Tools → Options → Web UI → Use alternative WebUI → `/vuetorrent`.

### 4.2 SABnzbd (Usenet Downloads)

SABnzbd provides Usenet downloads as an alternative/complement to qBittorrent.

> **Note:** Usenet is routed through VPN for consistency and an extra layer of security.

1. **Access:** `http://HOST_IP:8082`
2. **Run Quick-Start Wizard** with your Usenet provider details:

   **Popular providers:**
   | Provider | Price | Server |
   |----------|-------|--------|
   | Frugal Usenet | $4/mo | `news.frugalusenet.com` |
   | Newshosting | $6/mo | `news.newshosting.com` |
   | Eweka | €4/mo | `news.eweka.nl` |

   **Wizard settings:**
   - Host: (from table above)
   - Username: (your account email)
   - Password: (your account password)
   - SSL: ✓ checked
   - Click **Advanced Settings**:
     - Port: `563`
     - Connections: `20-60` (depends on plan)
   - Click **Test Server** → **Next**

3. **Configure Folders:** Config (⚙️) → Folders → set **absolute paths**:
   - **Temporary Download Folder:** `/incomplete-downloads`
   - **Completed Download Folder:** `/downloads`
   - Save Changes

   > **Important:** Don't use relative paths like `Downloads/complete` - Sonarr/Radarr won't find them.

4. **Get API Key:** Config (⚙️) → General → Copy **API Key**

5. **Add Usenet indexer to Prowlarr** (next section):
   - NZBGeek ($12/year): https://nzbgeek.info
   - DrunkenSlug (free tier): https://drunkenslug.com

### 4.3 Prowlarr (Indexer Manager)

Manages torrent/Usenet indexers and syncs them to Sonarr/Radarr.

1. **Access:** `http://HOST_IP:9696`
2. **Add Torrent Indexers:** Indexers (left sidebar) → + button → search by name
3. **Add Usenet Indexer** (if using SABnzbd):
   - **Indexers** (left sidebar, NOT Settings → Indexer Proxies) → + button
   - Search by indexer name (e.g., "NZBGeek", "DrunkenSlug", "NZBFinder")
   - API Key: (from your indexer account → API section)
   - **Tags:** leave blank (syncs to all apps)
   - **Indexer Proxy:** leave blank (not needed for Usenet)
   - Test → Save

   > **Tested with:** NZBGeek (~$12/year, reliable). Free alternatives: DrunkenSlug, NZBFinder.

4. **Add FlareSolverr** (for protected torrent sites):
   - Settings → Indexers → Add FlareSolverr
   - Host: `http://flaresolverr.lan:8191` (or `http://172.20.0.10:8191` if hostname fails)
   - Tag: `flaresolverr`
   - **Note:** FlareSolverr doesn't bypass all Cloudflare protections - some indexers may still fail. Non-protected indexers are more reliable.
5. **Connect to Sonarr:**
   - Settings → Apps → Add → Sonarr
   - Sonarr Server: `http://localhost:8989` (they share gluetun's network)
   - API Key: (from Sonarr → Settings → General → Security)
6. **Connect to Radarr:** Same process with `http://localhost:7878`
7. **Sync:** Settings → Apps → Sync App Indexers

### 4.4 Sonarr (TV Shows)

Automatically searches, downloads, and organizes TV shows.

1. **Access:** `http://HOST_IP:8989`
2. **Add Root Folder:** Settings → Media Management → `/tv`
3. **Add Download Client(s):** Settings → Download Clients

   **qBittorrent (torrents):**
   - Add → qBittorrent
   - Host: `localhost` (Sonarr & qBittorrent share gluetun's network)
   - Port: `8085`
   - Category: `sonarr`

   **SABnzbd (Usenet):** *(if configured)*
   - Add → SABnzbd
   - Host: `localhost` (SABnzbd also runs via gluetun)
   - Port: `8080`
   - API Key: (from SABnzbd Config → General)
   - Category: `tv` (default category in SABnzbd)

### 4.5 Radarr (Movies)

Automatically searches, downloads, and organizes movies.

1. **Access:** `http://HOST_IP:7878`
2. **Add Root Folder:** Settings → Media Management → `/movies`
3. **Add Download Client(s):** Settings → Download Clients

   **qBittorrent (torrents):**
   - Add → qBittorrent
   - Host: `localhost` (Radarr & qBittorrent share gluetun's network)
   - Port: `8085`
   - Category: `radarr`

   **SABnzbd (Usenet):** *(if configured)*
   - Add → SABnzbd
   - Host: `localhost` (SABnzbd also runs via gluetun)
   - Port: `8080`
   - API Key: (from SABnzbd Config → General)
   - Category: `movies` (default category in SABnzbd)

### 4.6 Prefer Usenet over Torrents (Optional)

If you have both qBittorrent and SABnzbd configured, Sonarr/Radarr will grab whichever is available first. To prefer Usenet (faster, no seeding):

1. Settings → Profiles → Delay Profiles
2. Click the **wrench/spanner icon** on the existing profile (don't click +)
3. Set: **Usenet Delay:** `0` minutes, **Torrent Delay:** `30` minutes
4. Save

This gives Usenet a 30-minute head start before considering torrents.

> **Note:** Repeat in both Sonarr and Radarr if you want consistent behavior.

### 4.7 Jellyfin (Media Server)

Streams your media library to any device.

1. **Access:** `http://HOST_IP:8096`
2. **Initial Setup:** Create admin account
3. **Add Libraries:**
   - Movies: Content type "Movies", Folder `/media/movies`
   - TV Shows: Content type "Shows", Folder `/media/tv`

### 4.8 Jellyseerr (Request Manager)

Lets users browse and request movies/TV shows.

1. **Access:** `http://HOST_IP:5055`
2. **Sign in with Jellyfin:**
   - Jellyfin URL: `http://jellyfin:8096`
   - Enter Jellyfin credentials
3. **Configure Services:**
   - Settings → Services → Add Sonarr: `http://gluetun:8989` (Sonarr runs via gluetun)
   - Settings → Services → Add Radarr: `http://gluetun:7878` (Radarr runs via gluetun)

### 4.9 Bazarr (Subtitles)

Automatically downloads subtitles for your media.

1. **Access:** `http://HOST_IP:6767`
2. **Enable Authentication:** Settings → General → Security → Forms
3. **Connect to Sonarr:** Settings → Sonarr → `http://gluetun:8989` (Sonarr runs via gluetun)
4. **Connect to Radarr:** Settings → Radarr → `http://gluetun:7878` (Radarr runs via gluetun)
5. **Add Providers:** Settings → Providers (OpenSubtitles, etc.)

### 4.10 Pi-hole (DNS)

**Why Pi-hole in this stack?**
- **DNS for VPN-routed services** — Prowlarr, Sonarr, Radarr etc. use Gluetun's network and need Pi-hole to resolve local hostnames
- **Optional .lan domains** — access services via `http://sonarr.lan` instead of `http://192.168.0.10:8989`
- **Optional network-wide DNS** — set your router to use Pi-hole for all devices (ad-blocking bonus)

**Setup:**

1. **Access:** `http://HOST_IP:8081/admin`
2. **Login:** Use password from `PIHOLE_UI_PASS` (password only, no username)
3. **Upstream DNS:** Settings → DNS → pick upstream servers (1.1.1.1, 8.8.8.8, etc.). Pi-hole forwards queries there. Note: your upstream provider sees all non-blocked queries.

**Optional: Network-wide DNS.** Set your router's DHCP DNS to your NAS IP.

### 4.11 Local DNS (.lan domains) — Optional

Access services without remembering port numbers: `http://sonarr.lan` instead of `http://10.10.0.10:8989`.

This works by giving Traefik its own IP on your LAN via macvlan (a Docker network type that assigns a real LAN IP to a container). DNS resolves `.lan` domains to that IP.

**Step 1: Configure macvlan settings in .env**

These are already in `.env` (from `.env.example`). Edit the values for your network:

```bash
TRAEFIK_LAN_IP=10.10.0.11    # Unused IP in your LAN range
LAN_INTERFACE=eth0            # Network interface (check with: ip link show)
LAN_SUBNET=10.10.0.0/24       # Your LAN subnet
LAN_GATEWAY=10.10.0.1         # Your router IP
```

**Step 2: Reserve the IP in your router**

The container uses a static IP with a fake MAC address (`TRAEFIK_LAN_MAC` in `.env`, default `02:42:0a:0a:00:0b`). Your router doesn't know about it, so add a DHCP reservation to prevent it assigning that IP to another device.

<details>
<summary>Router-specific instructions</summary>

- **MikroTik:** `/ip dhcp-server lease add address=10.10.0.11 mac-address=02:42:0a:0a:00:0b comment="Traefik macvlan" server=dhcp1`
- **UniFi:** Settings → Networks → DHCP → Static IP → Add `02:42:0a:0a:00:0b` → your `TRAEFIK_LAN_IP`
- **pfSense/OPNsense:** Services → DHCP → Static Mappings → Add
- **Consumer routers:** Look for "DHCP Reservation" or "Address Reservation"

</details>

**Step 3: Deploy Traefik with macvlan (on NAS via SSH)**
```bash
cd /volume1/docker/arr-stack

# Pull latest config
git pull origin main

# Restart Traefik with new macvlan network
docker compose -f docker-compose.traefik.yml down
docker compose -f docker-compose.traefik.yml up -d
```

**Step 4: Configure DNS**
```bash
# Create DNS config pointing to Traefik's IP
sed "s/TRAEFIK_LAN_IP/10.10.0.11/g" pihole/02-local-dns.conf.example > pihole/02-local-dns.conf

# Enable dnsmasq.d configs in Pi-hole v6 (one-time)
docker exec pihole sed -i 's/etc_dnsmasq_d = false/etc_dnsmasq_d = true/' /etc/pihole/pihole.toml

# Restart Pi-hole to load new config
docker compose -f docker-compose.arr-stack.yml restart pihole
```

**Step 5: Set router DNS**

Configure your router's DHCP to advertise your NAS IP as DNS server. All devices will then use Pi-hole for DNS.

> **Note:** Due to a macvlan limitation, `.lan` domains don't work from the NAS itself (e.g., via SSH). They work from all other devices.

See [REFERENCE.md](REFERENCE.md#local-access-lan-domains) for the full list of `.lan` URLs.

---

## Step 5: Test

### VPN Test

Run on NAS via SSH:
```bash
docker exec gluetun wget -qO- ifconfig.me       # Should show VPN IP, not your home IP
docker exec qbittorrent wget -qO- ifconfig.me   # Same - confirms qBit uses VPN
```

### Service Integration Test
1. Sonarr/Radarr: Settings → Download Clients → Test
2. Add a TV show or movie (noting legal restrictions) → verify it appears in qBittorrent
3. After download completes → verify it moves to library
4. Jellyfin → verify media appears in library

---

## Setup Done!

Now:

1. **Add content:** Search for TV shows in Sonarr, movies in Radarr
2. **Deploy utilities** (optional): See below
3. **Bookmark:** [Quick Reference](REFERENCE.md) for URLs, commands, and network info

**Other docs:** [Upgrading](UPGRADING.md) · [Home Assistant Integration](HOME-ASSISTANT.md)

Issues? [Report on GitHub](https://github.com/Pharkie/arr-stack-ugreennas/issues).

---

## External Access (Optional)

<details>
<summary><strong>Cloudflare Tunnel Setup</strong></summary>

Cloudflare Tunnel connects outbound from your server, bypassing port forwarding and ISP restrictions. This setup uses the CLI and a local config file (not the Cloudflare web dashboard) for wildcard DNS routing - only 2 DNS records for all services.

**1. Login to Cloudflare (run on NAS via SSH):**

```bash
cd /volume1/docker/arr-stack
mkdir -p cloudflared && chmod 777 cloudflared
docker run --rm -v ./cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared tunnel login
```

This prints a URL. Open it in your browser, select your domain, and authorize. The running cloudflared process receives the cert via callback and saves it automatically (the browser shouldn't offer any download).

**2. Create the tunnel:**

```bash
docker run --rm -v ./cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared tunnel create nas-tunnel
```

Note the tunnel ID (e.g., `6271ac25-f8ea-4cd3-b269-ad9778c61272`).

**3. Rename credentials and create config:**

```bash
# Rename credentials file
mv cloudflared/*.json cloudflared/credentials.json

# Create config (replace TUNNEL_ID and DOMAIN)
cat > cloudflared/config.yml << 'EOF'
tunnel: YOUR_TUNNEL_ID
credentials-file: /home/nonroot/.cloudflared/credentials.json

ingress:
  - hostname: "*.yourdomain.com"
    service: http://traefik:80
  - hostname: yourdomain.com
    service: http://traefik:80
  - service: http_status:404
EOF
```

**4. Add DNS routes:**

```bash
docker run --rm -v ./cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared tunnel route dns nas-tunnel "*.yourdomain.com"
docker run --rm -v ./cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared tunnel route dns nas-tunnel yourdomain.com
```

</details>

### Update Traefik Config

Copy the example configs and customize with your domain:

```bash
# Copy example configs
cp traefik/traefik.yml.example traefik/traefik.yml
cp traefik/dynamic/vpn-services.yml.example traefik/dynamic/vpn-services.yml
# Or for Plex:
# cp traefik/dynamic/vpn-services-plex.yml.example traefik/dynamic/vpn-services-plex.yml
```

Edit `traefik/traefik.yml` and replace `yourdomain.com` with your actual domain (3 places):

```yaml
# Line 31-33: SSL certificate domains
domains:
  - main: yourdomain.com      # ← your domain
    sans:
      - "*.yourdomain.com"    # ← your domain

# Line 39: Let's Encrypt email
email: admin@yourdomain.com   # ← your email
```

Edit `traefik/dynamic/vpn-services.yml` and replace the Host rules:

```yaml
# Replace yourdomain.com with your actual domain
jellyfin:
  rule: "Host(`jellyfin.yourdomain.com`)"  # ← your domain
jellyseerr:
  rule: "Host(`jellyseerr.yourdomain.com`)"  # ← your domain
wg:
  rule: "Host(`wg.yourdomain.com`)"  # ← your domain
```

> **Note:** The `.yml` files are gitignored. Your customized configs won't be overwritten when you `git pull` updates.

### Deploy External Access

```bash
# Deploy Cloudflare Tunnel
docker compose -f docker-compose.cloudflared.yml up -d
```

### Test External Access

From your phone on cellular data (not WiFi):
- Visit `https://jellyfin.yourdomain.com`
- Check SSL certificate is valid (padlock icon)

---

## Backup

Service configs are stored in Docker named volumes. Run periodic backups:

```bash
./scripts/backup-volumes.sh --tar
```

Creates a ~13MB tarball of essential configs (VPN settings, indexers, request history, etc.).

See **[Backup & Restore](BACKUP.md)** for full details on what's backed up, restore procedures, and automation.

---

## Optional Utilities

Deploy additional utilities for monitoring and NAS optimization:

```bash
docker compose -f docker-compose.utilities.yml up -d
```

| Service | Description | Access |
|---------|-------------|--------|
| **deunhealth** | Auto-restarts services when VPN recovers | Internal |
| **Uptime Kuma** | Service monitoring dashboard | http://HOST_IP:3001 |
| **duc** | Disk usage analyzer (treemap UI) | http://HOST_IP:8838 |
| **qbit-scheduler** | Pauses torrents overnight for disk spin-down | Internal |

### qbit-scheduler Setup

Pauses all torrents at 20:00 and resumes at 06:00, allowing NAS disks to spin down overnight.

**Requirements:** Add qBittorrent credentials to `.env`:
```bash
QBIT_USER=admin
QBIT_PASSWORD=your_qbittorrent_password
```

**Manual control:**
```bash
docker exec qbit-scheduler /app/pause-resume.sh pause   # Stop all torrents
docker exec qbit-scheduler /app/pause-resume.sh resume  # Start all torrents
```

**View logs:**
```bash
docker logs qbit-scheduler
```

---

## Adding More Services

The *arr ecosystem includes other apps you can add using the same pattern:

- **Lidarr** - Music (port 8686)
- **Readarr** - Ebooks (port 8787)

<details>
<summary>Example: Adding Lidarr</summary>

1. Add to `docker-compose.arr-stack.yml` volumes section:
   ```yaml
   lidarr-config:
   ```

2. Add port to gluetun:
   ```yaml
   - "8686:8686"   # Lidarr
   ```

3. Add the service:
   ```yaml
   lidarr:
     image: lscr.io/linuxserver/lidarr:latest
     container_name: lidarr
     network_mode: "service:gluetun"
     depends_on:
       gluetun:
         condition: service_healthy
     environment:
       - PUID=1000
       - PGID=1000
       - TZ=${TZ:-Europe/London}
     volumes:
       - lidarr-config:/config
       - ${MEDIA_ROOT:-/volume1/Media}/music:/music
       - ${MEDIA_ROOT:-/volume1/Media}/downloads:/downloads
     restart: unless-stopped
   ```

4. Redeploy: `docker compose -f docker-compose.arr-stack.yml up -d`

</details>
