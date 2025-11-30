# Complete Media Automation Stack for Ugreen NAS

A production-ready Docker Compose stack for media automation, featuring VPN routing, reverse proxy with SSL, and comprehensive media management tools.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Service Configuration](#service-configuration)
- [Maintenance](#maintenance)
- [FAQ](#faq)

---

## Overview

This stack provides a complete media automation solution with:
- **VPN-routed downloading** (Gluetun + Surfshark)
- **SSL/TLS certificates** (Traefik + Cloudflare)
- **Media management** (Sonarr, Radarr, Prowlarr, Bazarr)
- **Media streaming** (Jellyfin)
- **Request management** (Jellyseerr)
- **Remote access** (WireGuard VPN)
- **Ad-blocking DNS** (Pi-hole)
- **Unified dashboard** (Homarr)

### Services Included

| Service | Purpose | External URL | Local URL |
|---------|---------|--------------|-----------|
| **Traefik** | Reverse proxy + SSL | traefik.yourdomain.com | - |
| **Gluetun** | VPN gateway | (Internal) | - |
| **qBittorrent** | Download client | qbit.yourdomain.com | - |
| **Sonarr** | TV show management | sonarr.yourdomain.com | - |
| **Radarr** | Movie management | radarr.yourdomain.com | - |
| **Prowlarr** | Indexer manager | prowlarr.yourdomain.com | - |
| **Bazarr** | Subtitle management | bazarr.yourdomain.com | - |
| **Jellyfin** | Media server | jellyfin.yourdomain.com | your-nas.local:8096 |
| **Jellyseerr** | Request management | jellyseerr.yourdomain.com | your-nas.local:5055 |
| **Pi-hole** | DNS + Ad blocking | pihole.yourdomain.com | your-nas.local:80 |
| **WireGuard** | VPN server | wg.yourdomain.com | - |
| **Homarr** | Dashboard | homarr.yourdomain.com | your-nas.local:3000 |
| **FlareSolverr** | Cloudflare bypass | flaresolverr.yourdomain.com | - |
| **Notifiarr** | Notifications | notifiarr.yourdomain.com | - |

### Local Network Access

For devices on your home network (FireTV, phones, tablets), use the local URLs for faster access:

| Service | Local URL | Notes |
|---------|-----------|-------|
| **Jellyfin** | `http://your-nas.local:8096` | Media streaming |
| **Jellyseerr** | `http://your-nas.local:5055` | Request content |
| **Homarr** | `http://your-nas.local:3000` | Dashboard |
| **Pi-hole** | `http://your-nas.local:80` | DNS admin |

**Why use local URLs?**
- ✅ Faster (no internet round-trip via Cloudflare)
- ✅ Works even if internet/Cloudflare is down
- ✅ mDNS names work on macOS, iOS, Android, FireTV, Linux

**Note:** Replace `your-nas.local` with your NAS hostname if different.

---

## Features

### Security
- All services behind SSL/TLS (automatic certificates via Let's Encrypt)
- VPN routing for torrenting services (prevent IP leaks)
- Pi-hole for ad-blocking and DNS security
- WireGuard for secure remote access
- Security headers via Traefik middleware

### Automation
- Automatic TV show and movie downloads
- Subtitle downloads (Bazarr)
- Media requests via Jellyseerr
- Automatic indexer management (Prowlarr)
- Cloudflare bypass for protected indexers (FlareSolverr)

### Reliability
- Health checks for all services
- Automatic restart policies
- Centralized logging
- Volume-based persistent storage

---

## Architecture

### Network Topology

```
Internet
    │
    ├─── Port 80/443 ──────────► Traefik (Reverse Proxy)
    │                                │
    │                                ├─► traefik-proxy network (192.168.100.0/24)
    │                                │   │
    │                                │   ├─► Jellyfin (.4)
    │                                │   ├─► Pi-hole (.5)
    │                                │   ├─► WireGuard (.6)
    │                                │   ├─► Homarr (.7)
    │                                │   └─► Other services
    │                                │
    │                                └─► Gluetun (.3) ◄─── VPN Connection (Surfshark)
    │                                        │
    │                                        └─► qBittorrent, Sonarr, Radarr, Prowlarr
    │                                            (network_mode: service:gluetun)
    │
    └─── Port 51820/udp ───────────► WireGuard VPN Server
```

### Why Two Separate Docker Compose Files?

You'll notice this project uses **two separate compose files**:
1. `docker-compose.traefik.yml` - Infrastructure layer
2. `docker-compose.arr-stack.yml` - Application layer

**This is intentional and follows best practices.** Here's why:

#### 1. **Independent Lifecycle Management**
- Restart/update media services without affecting the reverse proxy
- Update Traefik without touching your media stack
- If arr-stack crashes, Traefik stays running for other potential services

#### 2. **Scalability & Reusability**
Traefik can serve multiple stacks on the same server:
```
traefik (shared reverse proxy)
    ↓
    ├── arr-stack (media automation)
    ├── monitoring-stack (Grafana, Prometheus) ← Future addition
    ├── home-automation (Home Assistant)        ← Future addition
    └── other-services                          ← Future addition
```

All using the same Traefik instance, same SSL certificates, same domain!

#### 3. **Clean Separation of Concerns**
- **Infrastructure Layer** (Traefik): Handles SSL, routing, network
- **Application Layer** (arr-stack): Handles your actual services

This is standard practice in production environments.

#### 4. **Easier Troubleshooting**
- Problem with downloads? Check arr-stack logs
- Problem with SSL/routing? Check Traefik logs
- Clear separation makes debugging simpler

#### 5. **Network Management**
- Traefik compose file **creates** the `traefik-proxy` network
- arr-stack compose file **uses** it (via `external: true`)
- Other future stacks can join the same network

#### Deployment Order Matters
Because of this separation:
1. **Deploy Traefik first** (creates network, sets up SSL)
2. **Deploy arr-stack second** (joins network, uses Traefik)

**Alternative**: You could combine them into one file, but you'd lose the flexibility and would need to restart everything together. The two-file approach is more maintainable and follows industry best practices.

### Storage Structure

```
/volume1/
├── Media/
│   ├── downloads/          # qBittorrent downloads
│   ├── tv/                 # TV shows (Sonarr → Jellyfin)
│   └── movies/             # Movies (Radarr → Jellyfin)
│
└── docker/
    └── arr-stack/
        ├── gluetun-config/
        ├── jellyseerr/config/
        ├── bazarr/config/
        ├── notifiarr/
        ├── homarr/
        │   ├── configs/
        │   ├── icons/
        │   └── data/
        └── traefik/
            ├── traefik.yml
            ├── acme.json
            └── dynamic/
                └── tls.yml
```

---

## Prerequisites

### Hardware Requirements
- Ugreen NAS (or compatible device)
- Support for `/dev/net/tun` (for VPN)
- Docker with `NET_ADMIN` capability support
- Minimum 4GB RAM (8GB+ recommended)
- Storage for media files

### Software Requirements
- Docker Engine 20.10+
- Docker Compose v2.0+
- SSH access to NAS
- Basic Linux command-line knowledge

### External Services
1. **Domain Name** (e.g., yourdomain.com)
2. **Cloudflare Account** (free tier works)
   - Domain added to Cloudflare
   - API token with DNS edit permissions
3. **Surfshark VPN Subscription**
   - Active account with WireGuard credentials
   - Alternative: Modify for NordVPN, ProtonVPN, etc. (Gluetun supports many providers)

### Network Requirements
- Static IP for NAS (recommended)
- Port forwarding on router:
  - 80 → NAS:80 (HTTP)
  - 443 → NAS:443 (HTTPS)
  - 51820/udp → NAS:51820 (WireGuard)

---

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/arr-stack-ugreennas.git
cd arr-stack-ugreennas
```

### 2. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit with your values
nano .env
```

**Required values**:
- `DOMAIN`: Your domain (e.g., yourdomain.com)
- `CF_DNS_API_TOKEN`: Cloudflare API token
- `SURFSHARK_PRIVATE_KEY`: Surfshark WireGuard private key
- `PIHOLE_UI_PASS`: Pi-hole admin password
- `WG_PASSWORD_HASH`: WireGuard password hash
- `TRAEFIK_DASHBOARD_AUTH`: Traefik dashboard auth

### 3. Create Directory Structure on NAS

```bash
# SSH to NAS
ssh user@nas-ip

# Create directories
sudo mkdir -p /volume1/docker/arr-stack/{gluetun-config,jellyseerr/config,bazarr/config,notifiarr,homarr/{configs,icons,data},traefik/dynamic}
sudo mkdir -p /volume1/Media/{downloads,tv,movies}

# Set permissions
sudo chown -R 1000:1000 /volume1/docker/arr-stack
sudo chown -R 1000:1000 /volume1/Media

# Create Traefik certificate file
sudo touch /volume1/docker/arr-stack/traefik/acme.json
sudo chmod 600 /volume1/docker/arr-stack/traefik/acme.json
```

### 4. Copy Configuration Files

```bash
# From your local machine
scp traefik/traefik.yml user@nas:/volume1/docker/arr-stack/traefik/
scp traefik/dynamic/tls.yml user@nas:/volume1/docker/arr-stack/traefik/dynamic/
```

### 5. Create Docker Network

```bash
# On NAS
docker network create \
  --driver=bridge \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  traefik-proxy
```

### 6. Deploy Traefik

```bash
docker compose -f docker-compose.traefik.yml up -d
```

**Verify**:
```bash
docker logs traefik -f
# Look for "Configuration loaded" and certificate acquisition
```

### 7. Configure DNS (see DNS-SETUP.md)

Create DNS records pointing to your NAS IP.

### 8. Deploy Media Stack

```bash
# Deploy in stages
docker compose -f docker-compose.arr-stack.yml up -d gluetun
docker compose -f docker-compose.arr-stack.yml up -d qbittorrent
docker compose -f docker-compose.arr-stack.yml up -d sonarr radarr prowlarr
docker compose -f docker-compose.arr-stack.yml up -d jellyfin jellyseerr bazarr
docker compose -f docker-compose.arr-stack.yml up -d pihole wg-easy homarr
docker compose -f docker-compose.arr-stack.yml up -d flaresolverr notifiarr
```

### 9. Access Services

Visit `https://homarr.yourdomain.com` for the main dashboard.

---

## ⚠️ CRITICAL: Ugreen NAS Port Conflict

**BEFORE deploying Traefik, you MUST reconfigure the Ugreen NAS web interface to avoid losing access!**

### The Problem

The Ugreen NAS web interface (nginx) runs on ports **80** and **443** by default.
Traefik **also needs** ports **80** and **443** for the media stack.
**They cannot both run at the same time on the same ports.**

### The Solution

**Change nginx to use ports 8080/8443 BEFORE deploying Traefik.**

#### Step-by-Step Fix

1. **SSH into your NAS**:
   ```bash
   ssh your-username@nas-ip
   ```

2. **Find nginx config files** using ports 80/443:
   ```bash
   sudo find /etc/nginx -type f -name '*.conf' -exec grep -l 'listen.*80\|listen.*443' {} \;
   ```

3. **For each file found**, replace ports:
   ```bash
   # Replace port 80 with 8080
   sudo sed -i 's/listen 80/listen 8080/g' /etc/nginx/filename.conf
   sudo sed -i 's/listen \[::\]:80/listen [::]:8080/g' /etc/nginx/filename.conf

   # Replace port 443 with 8443
   sudo sed -i 's/listen 443/listen 8443/g' /etc/nginx/filename.conf
   sudo sed -i 's/listen \[::\]:443/listen [::]:8443/g' /etc/nginx/filename.conf
   ```

4. **Restart nginx** (DO NOT stop it):
   ```bash
   sudo systemctl restart nginx
   ```

5. **Test access**:
   - New URL: `http://nas-ip:8080` or `https://nas-ip:8443`
   - If it works, proceed with Traefik deployment

### After Configuration

- **Ugreen NAS Web UI**: `http://YOUR_NAS_IP:8080`
- **Media Services**: `https://jellyfin.yourdomain.com` (standard ports via Traefik)

**Both services will run simultaneously without conflicts.**

⚠️ **WARNING**: If you skip this step and deploy Traefik, you will lose access to the Ugreen NAS web interface and need to reboot the NAS!

---

## Detailed Setup

### Step-by-Step: Filling Out the .env File

Before deployment, you need to configure your `.env` file with credentials and API tokens. **Follow these steps in order** for the easiest setup:

#### Step 1: Copy the Template

```bash
cp .env.example .env
```

Your `.env` already has:
- ✅ Domain configured
- ✅ Static IP addresses set
- ⏳ Empty fields for credentials (we'll fill these next)

---

#### Step 2: Generate Cloudflare API Token

**You need this for automatic SSL certificates.**

1. **Open**: https://dash.cloudflare.com/profile/api-tokens
2. **Click**: "Create Token"
3. **Select**: "Edit zone DNS" template
4. **Configure Permissions** - Click "+ Add more" to add a second permission:
   - Permission 1: `Zone → DNS → Edit`
   - Permission 2: `Zone → Zone → Read` (click "+ Add more")
5. **Zone Resources**: "All zones" (this is fine if you have one domain)
6. **Click**: "Continue to summary" → "Create Token"
7. **COPY THE TOKEN** (shown only once!)
8. **Paste** into `.env`:
   ```bash
   CF_DNS_API_TOKEN=your_token_here
   ```

---

#### Step 3: Add Surfshark VPN Credentials (WireGuard)

**Get your WireGuard configuration from**: https://my.surfshark.com/

1. Login to Surfshark
2. Navigate to: **VPN** → **Manual Setup**
3. Select device type: **Router**
4. Select protocol: **WireGuard**
5. When asked "Do you have a WireGuard key pair?", select **"I don't"**
6. Surfshark will generate keys - click **"Download"** to get the `.conf` file
7. **Open the downloaded file** and extract these values:

   ```ini
   [Interface]
   Address = 10.14.0.2/16          ← Copy this
   PrivateKey = uHSC4GWQ...        ← Copy this
   ```

8. **Add** to `.env`:
   ```bash
   SURFSHARK_PRIVATE_KEY=your_private_key_here
   SURFSHARK_WG_ADDRESS=10.14.0.2/16
   ```

**Note**: We use WireGuard (not OpenVPN) because it's faster and more reliable with Gluetun. You MUST download the config file to get the Address field - it's not shown on the web interface.

---

#### Step 4: Set Pi-hole Admin Password

**Choose a secure password** for Pi-hole's web interface, or generate one:

```bash
# Generate random secure password
openssl rand -base64 24
```

**Add** to `.env`:
```bash
PIHOLE_UI_PASS=your_chosen_password
```

**Save this password** - you'll need it to login to Pi-hole!

---

#### Step 5: Generate WireGuard Password Hash

**Choose a password** for WireGuard admin interface, then generate the bcrypt hash:

```bash
# Start Docker Desktop if not running, then:
docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'YOUR_WIREGUARD_PASSWORD'
```

**Example**:
```bash
docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'MySecureWGPass123!'
```

This outputs:
```
PASSWORD_HASH='$2a$12$...'
```

**Copy the hash** (the `$2a$12$...` part) and **add** to `.env`:
```bash
WG_PASSWORD_HASH=$2a$12$your_generated_hash
```

**Save your WireGuard password** (the plain text one) - you'll need it to login!

**Note**: The hash is just a text string - it's safe to generate on Mac/Windows/Linux, it will work on your NAS.

---

#### Step 6: Generate Traefik Dashboard Authentication

**Choose credentials** for Traefik dashboard (username: `admin`, password: your choice):

```bash
# Replace 'your_password' with your chosen password
docker run --rm httpd:alpine htpasswd -nb admin 'your_password' | sed -e s/\\$/\\$\\$/g
```

**Example**:
```bash
docker run --rm httpd:alpine htpasswd -nb admin 'MyTraefikPass123' | sed -e s/\\$/\\$\\$/g
```

This outputs:
```
admin:$$apr1$$...$$...
```

**Copy the entire output** and **add** to `.env`:
```bash
TRAEFIK_DASHBOARD_AUTH=admin:$$apr1$$...$$...
```

**Save your Traefik password** - you'll need it to login!

---

#### Step 7: Verify Your .env File

Your completed `.env` should look like this:

```bash
DOMAIN=yourdomain.com
CF_DNS_API_TOKEN=abc123...           # ✅ Filled
SURFSHARK_USER=your@email.com        # ✅ Filled
SURFSHARK_PASSWORD=yourpass          # ✅ Filled
PIHOLE_UI_PASS=yourpass             # ✅ Filled
WG_PASSWORD_HASH=$2a$12$...         # ✅ Filled
TRAEFIK_DASHBOARD_AUTH=admin:$$...  # ✅ Filled
```

**All fields filled?** ✅ You're ready for deployment!

---

### Save Your Passwords!

**You'll need these to login to services** (save in password manager):

| Service | Username | Password |
|---------|----------|----------|
| Pi-hole | (none) | Your Pi-hole password |
| WireGuard | (none) | Your WireGuard password (NOT the hash!) |
| Traefik | admin | Your Traefik password |

**Important**: The `.env` file contains secrets - **never commit it to git**! (It's in `.gitignore`)

### Verifying VPN Connection

```bash
# Check Gluetun logs
docker logs gluetun -f

# Should show:
# [INFO] Connected to VPN
# [INFO] IP: <surfshark-ip>

# Test external IP
docker exec gluetun wget -qO- ifconfig.me
# Should show VPN IP, NOT your home IP

# Test from qBittorrent
docker exec qbittorrent wget -qO- ifconfig.me
# Should also show VPN IP (confirms network_mode works)
```

---

## Service Configuration

### Prowlarr Setup

1. **Access**: `https://prowlarr.yourdomain.com`

2. **Add Indexers**:
   - Settings → Indexers → Add Indexer
   - Search for your preferred indexers
   - Configure each indexer

3. **Add FlareSolverr** (for Cloudflare-protected indexers):
   - Settings → Indexers → Add FlareSolverr
   - Name: FlareSolverr
   - Tags: `flaresolverr`
   - Host: `http://flaresolverr:8191`
   - Test and Save
   - Tag indexers that need Cloudflare bypass

4. **Connect to Sonarr**:
   - Settings → Apps → Add Application → Sonarr
   - Name: Sonarr
   - Sync Level: Full Sync
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr Server: `http://sonarr:8989`
   - API Key: (copy from Sonarr → Settings → General → Security)
   - Test and Save

5. **Connect to Radarr**:
   - Settings → Apps → Add Application → Radarr
   - Name: Radarr
   - Sync Level: Full Sync
   - Prowlarr Server: `http://prowlarr:9696`
   - Radarr Server: `http://radarr:7878`
   - API Key: (copy from Radarr → Settings → General → Security)
   - Test and Save

6. **Sync Indexers**:
   - Settings → Apps → Sync App Indexers (button at bottom)
   - Verify indexers appear in Sonarr and Radarr

---

### Sonarr Configuration

1. **Access**: `https://sonarr.yourdomain.com`

2. **Add Root Folder**:
   - Settings → Media Management → Root Folders
   - Add: `/tv`

3. **Add Download Client**:
   - Settings → Download Clients → Add → qBittorrent
   - Name: qBittorrent
   - Host: `gluetun` (important! not localhost)
   - Port: `8085`
   - Username: `admin`
   - Password: (your qBittorrent password)
   - Category: `sonarr`
   - Test and Save

4. **Quality Profiles** (optional):
   - Settings → Profiles
   - Customize to your preferences

5. **Add Series**:
   - Series → Add New
   - Search for TV show
   - Select quality profile, monitored status
   - Add

---

### Radarr Configuration

1. **Access**: `https://radarr.yourdomain.com`

2. **Add Root Folder**:
   - Settings → Media Management → Root Folders
   - Add: `/movies`

3. **Add Download Client**:
   - Settings → Download Clients → Add → qBittorrent
   - Name: qBittorrent
   - Host: `gluetun`
   - Port: `8085`
   - Username: `admin`
   - Password: (your qBittorrent password)
   - Category: `radarr`
   - Test and Save

4. **Add Movies**:
   - Movies → Add New
   - Search for movie
   - Select quality profile, monitored status
   - Add

---

### Jellyfin Configuration

1. **Access**: `https://jellyfin.yourdomain.com`

2. **Initial Setup**:
   - Create admin account
   - Select language

3. **Add Media Libraries**:
   - Movies:
     - Content type: Movies
     - Folder: `/media/movies`
     - Enable: Automatically refresh metadata
   - TV Shows:
     - Content type: Shows
     - Folder: `/media/tv`
     - Enable: Automatically refresh metadata

4. **Configure Metadata** (optional):
   - Settings → Libraries → Metadata downloaders
   - Configure TMDB, TVDB, etc.

5. **User Management**:
   - Dashboard → Users
   - Create accounts for family/friends

---

### Jellyseerr Configuration

1. **Access**: `https://jellyseerr.yourdomain.com`

2. **Sign In**:
   - Use Jellyfin Sign-In
   - Jellyfin URL: `http://jellyfin:8096`
   - Enter Jellyfin credentials
   - Import Jellyfin libraries

3. **Configure Sonarr**:
   - Settings → Services → Sonarr
   - Default Server: ON
   - Server Name: Sonarr
   - Hostname/IP: `sonarr`
   - Port: `8989`
   - API Key: (from Sonarr)
   - URL Base: (leave empty)
   - Quality Profile: (select default)
   - Root Folder: `/tv`
   - Season Folders: ON
   - Test and Save

4. **Configure Radarr**:
   - Settings → Services → Radarr
   - Default Server: ON
   - Server Name: Radarr
   - Hostname/IP: `radarr`
   - Port: `7878`
   - API Key: (from Radarr)
   - URL Base: (leave empty)
   - Quality Profile: (select default)
   - Root Folder: `/movies`
   - Test and Save

5. **User Permissions**:
   - Settings → Users
   - Configure request limits, auto-approval, etc.

---

### Bazarr Configuration

1. **Access**: `https://bazarr.yourdomain.com`

2. **Connect to Sonarr**:
   - Settings → Sonarr
   - Enabled: ON
   - Hostname/IP: `sonarr`
   - Port: `8989`
   - API Key: (from Sonarr)
   - Test and Save

3. **Connect to Radarr**:
   - Settings → Radarr
   - Enabled: ON
   - Hostname/IP: `radarr`
   - Port: `7878`
   - API Key: (from Radarr)
   - Test and Save

4. **Add Subtitle Providers**:
   - Settings → Providers
   - Enable providers (OpenSubtitles, Subscene, etc.)
   - Configure credentials if needed

5. **Languages**:
   - Settings → Languages
   - Add preferred subtitle languages
   - Set as default

---

### qBittorrent Configuration

1. **Access**: `https://qbit.yourdomain.com`
2. **Default Login**: `admin` / `adminadmin`
3. **IMMEDIATELY CHANGE PASSWORD**:
   - Tools → Options → Web UI → Authentication
   - Change password

4. **Categories** (for Sonarr/Radarr):
   - Right-click in categories → Add category
   - Add: `sonarr`, `radarr`
   - Set save paths:
     - sonarr → `/downloads/sonarr`
     - radarr → `/downloads/radarr`

5. **Connection Settings**:
   - Tools → Options → Connection
   - Verify port 8085
   - DO NOT enable UPnP (behind VPN)

6. **Downloads**:
   - Tools → Options → Downloads
   - Default Save Path: `/downloads`
   - Keep incomplete torrents in: `/downloads/incomplete`
   - Copy .torrent files to: `/downloads/torrents`

---

### Pi-hole Configuration

1. **Access**: `https://pihole.yourdomain.com/admin` or `http://your-nas.local:80/admin`
2. **Login**: Use password from `PIHOLE_UI_PASS` in .env

3. **Settings → DNS**:
   - Upstream DNS Servers:
     - Cloudflare (1.1.1.1, 1.0.0.1)
     - Or your preference
   - Interface settings: Listen on all interfaces

4. **Adlists** (optional):
   - Group Management → Adlists
   - Add additional blocklists

5. **Test DNS**:
   ```bash
   dig @YOUR_NAS_IP google.com
   dig @YOUR_NAS_IP doubleclick.net  # Should return 0.0.0.0 (blocked)
   ```

### Network-Wide Pi-hole Setup

To use Pi-hole for ad-blocking on all devices in your home:

1. **Configure Router DHCP DNS**:
   - Access your router admin (e.g., `http://192.168.0.1`)
   - Go to: **Network → DHCP Server**
   - Set **Primary DNS**: `YOUR_NAS_IP` (your NAS IP)
   - Set **Secondary DNS**: `YOUR_NAS_IP` (same, to prevent fallback leaks)
   - Save and reboot router

2. **Configure Router Internet DNS** (optional but recommended):
   - Go to: **Internet → DNS settings**
   - Set both Primary and Secondary to `YOUR_NAS_IP`
   - This prevents the router from adding itself as a fallback DNS

3. **Renew DHCP on devices**:
   - Reconnect to Wi-Fi, or
   - macOS: `networksetup -setdhcp "Wi-Fi"`

4. **Verify**:
   ```bash
   # Check DNS servers in use
   scutil --dns | grep nameserver

   # Should show YOUR_NAS_IP only
   ```

**Note: iCloud Private Relay**

Apple devices may show "This network is blocking iCloud Private Relay" when using Pi-hole. This is expected - Private Relay encrypts DNS which bypasses Pi-hole.

**Recommended**: Disable Private Relay on your home network:
- iPhone: Settings → Wi-Fi → (i) next to your network → iCloud Private Relay → OFF
- Keep it enabled for public Wi-Fi and cellular

---

### WireGuard Configuration

1. **Access**: `https://wg.yourdomain.com`
2. **Login**: Use password you set (used to generate `WG_PASSWORD_HASH`)

3. **Create Client**:
   - Click "New"
   - Name: `My Phone` (or device name)
   - Download QR code or config file

4. **Port Forwarding**:
   - Ensure UDP 51820 is forwarded on router
   - Port → NAS:51820

5. **Connect**:
   - Install WireGuard on device
   - Scan QR code or import config
   - Connect

6. **Verify**:
   - While connected, access: `https://homarr.yourdomain.com`
   - Should work even without external DNS (using internal IP)

---

### Homarr Configuration

1. **Access**: `https://homarr.yourdomain.com`

2. **Add Services**:
   - Click "Edit" (top right)
   - Add Widget → Service
   - Add each service:

   | Service | URL | Icon |
   |---------|-----|------|
   | Jellyfin | https://jellyfin.yourdomain.com | jellyfin.png |
   | Jellyseerr | https://jellyseerr.yourdomain.com | jellyseerr.png |
   | Sonarr | https://sonarr.yourdomain.com | sonarr.png |
   | Radarr | https://radarr.yourdomain.com | radarr.png |
   | Prowlarr | https://prowlarr.yourdomain.com | prowlarr.png |
   | Bazarr | https://bazarr.yourdomain.com | bazarr.png |
   | qBittorrent | https://qbit.yourdomain.com | qbittorrent.png |
   | Pi-hole | https://pihole.yourdomain.com/admin | pihole.png |
   | WireGuard | https://wg.yourdomain.com | wireguard.png |

3. **API Integration** (optional):
   - For each service, enable API integration
   - Add API keys to show stats on dashboard

4. **Customize Layout**:
   - Drag and drop widgets
   - Resize as needed
   - Save changes

---

### Notifiarr Configuration

1. **Download Config**:
   ```bash
   wget https://raw.githubusercontent.com/Notifiarr/notifiarr/main/examples/notifiarr.conf.example
   mv notifiarr.conf.example /volume1/docker/arr-stack/notifiarr/notifiarr.conf
   ```

2. **Get API Key**:
   - Register at: https://notifiarr.com
   - Copy API key

3. **Edit Config**:
   ```bash
   nano /volume1/docker/arr-stack/notifiarr/notifiarr.conf
   ```

   Update:
   - `api_key`: Your Notifiarr API key
   - Sonarr/Radarr/etc URLs and API keys

4. **Restart Notifiarr**:
   ```bash
   docker compose -f docker-compose.arr-stack.yml restart notifiarr
   ```

5. **Configure Webhooks**:
   - In Sonarr/Radarr:
   - Settings → Connect → Add → Webhook
   - URL: `http://notifiarr:5454/api/v1/notification/sonarr` (or radarr)
   - Method: POST

---

## Maintenance

### Updating Services

```bash
# Update all services
docker compose -f docker-compose.arr-stack.yml pull
docker compose -f docker-compose.arr-stack.yml up -d

# Update specific service
docker compose -f docker-compose.arr-stack.yml pull sonarr
docker compose -f docker-compose.arr-stack.yml up -d sonarr
```

### Backup

**Important volumes to backup**:
```bash
# List all volumes
docker volume ls | grep arr-stack

# Backup volumes
docker run --rm \
  -v sonarr-config:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/sonarr-config.tar.gz -C /data .

# Repeat for: radarr-config, prowlarr-config, jellyfin-config, etc.
```

**Backup configuration files**:
```bash
tar czf arr-stack-config-backup.tar.gz \
  /volume1/docker/arr-stack/gluetun-config \
  /volume1/docker/arr-stack/jellyseerr \
  /volume1/docker/arr-stack/bazarr \
  /volume1/docker/arr-stack/notifiarr \
  /volume1/docker/arr-stack/homarr \
  /volume1/docker/arr-stack/traefik
```

### Logs

```bash
# View logs for all services
docker compose -f docker-compose.arr-stack.yml logs -f

# View logs for specific service
docker logs -f sonarr

# View last 100 lines
docker logs --tail 100 sonarr

# Save logs to file
docker logs sonarr > sonarr-logs.txt
```

### Resource Monitoring

```bash
# View resource usage
docker stats

# View disk usage
docker system df

# Clean up unused images
docker image prune -a
```

---

## FAQ

### Q: How do I change my domain?

1. Update `.env`: `DOMAIN=newdomain.com`
2. Update `traefik/traefik.yml`: domains section
3. Recreate services:
   ```bash
   docker compose -f docker-compose.arr-stack.yml down
   docker compose -f docker-compose.arr-stack.yml up -d
   ```
4. Update DNS records (see DNS-SETUP.md)

### Q: Can I use a different VPN provider?

Yes! Edit `docker-compose.arr-stack.yml`:
```yaml
gluetun:
  environment:
    - VPN_SERVICE_PROVIDER=nordvpn  # or protonvpn, etc.
    - OPENVPN_USER=${VPN_USER}
    - OPENVPN_PASSWORD=${VPN_PASSWORD}
```

See Gluetun docs for supported providers: https://github.com/qdm12/gluetun-wiki

### Q: Services aren't accessible externally?

Check:
1. DNS records point to your public IP
2. **Port forwarding configured correctly**:
   - If Traefik uses ports 8080/8443, forward: External 80→8080, External 443→8443
   - Router may need restart for port forwarding to activate
3. Firewall allows ports 8080, 8443 on NAS
4. Cloudflare proxy disabled (DNS only - gray cloud)
5. ISP may be blocking ports 80/443 (common for residential)

See TROUBLESHOOTING.md → "Can't access services externally" for detailed solutions.

### Q: How do I restrict *arr services to local network only?

Remove Traefik labels from services you want local-only, or add authentication middleware.

### Q: Downloads aren't working?

1. Check VPN connection: `docker logs gluetun`
2. Verify qBittorrent can reach internet: `docker exec qbittorrent wget -qO- ifconfig.me`
3. Check if download client configured in Sonarr/Radarr
4. Verify categories exist in qBittorrent

### Q: SSL certificates not working?

1. Check Cloudflare API token is correct
2. Verify DNS records exist
3. Check Traefik logs: `docker logs traefik -f`
4. Verify acme.json permissions: `chmod 600 traefik/acme.json`

### Q: How do I add more storage?

Update volume mounts in `docker-compose.arr-stack.yml`:
```yaml
volumes:
  - /volume2/more-storage/movies:/movies2
```

Then add the path in Sonarr/Radarr root folders.

### Q: Container won't start - "address already in use"?

**Problem**: IP address conflict on traefik-proxy network

**Solution**: Assign static IPs to all services:
```yaml
services:
  service-name:
    networks:
      traefik-proxy:
        ipv4_address: 192.168.100.X
```

See TROUBLESHOOTING.md → "IP Address Conflicts" for full IP allocation plan.

### Q: Gluetun error: "Wireguard settings: interface address is not set"?

**Problem**: Surfshark WireGuard requires Address field not shown on web UI

**Solution**:
1. Go to https://my.surfshark.com/ → VPN → Manual Setup → Router → WireGuard
2. **Download** the full .conf file (don't just copy from web)
3. Open .conf file and find `Address = 10.14.0.2/16` in [Interface] section
4. Add to `.env`: `SURFSHARK_WG_ADDRESS=10.14.0.2/16`

### Q: Docker commands fail with "permission denied"?

On Ugreen NAS, use sudo:
```bash
sudo docker compose up -d
# Or via SSH:
echo 'YOUR_PASSWORD' | sudo -S docker compose up -d
```

**Permanent fix**: Add user to docker group
```bash
sudo usermod -aG docker $USER
# Logout and login again
```

### Q: Port forwarding doesn't work / External access fails?

**Symptoms**: Services work locally but timeout from external network

**Common causes**:
1. **CGNAT** (most likely) - ISP puts you behind carrier-grade NAT
   - Port forwarding cannot work with CGNAT
   - Affects ~30% of residential internet
   - ISPs don't advertise this

2. **ISP blocking** - ISP blocks all incoming connections

**How to test**:
```bash
# From phone on cellular data:
curl -I http://YOUR_PUBLIC_IP:8080

# If timeout after 10+ seconds = CGNAT or ISP blocking
```

**Solutions**:
- **Cloudflare Tunnel** (recommended) - See CLOUDFLARE-TUNNEL-SETUP.md
- **VPN-only access** - Use WireGuard for all access
- **Contact ISP** - Ask about CGNAT, request public IP (may cost extra)

See EXTERNAL-ACCESS-ISSUE.md for detailed diagnosis.

---

## Support

- **Issues**: https://github.com/yourusername/arr-stack-ugreennas/issues
- **Documentation**: See DEPLOYMENT-PLAN.md, DNS-SETUP.md, TROUBLESHOOTING.md
- **Gluetun**: https://github.com/qdm12/gluetun
- **Traefik**: https://doc.traefik.io/traefik/
- **Sonarr/Radarr**: https://wiki.servarr.com/

---

**Last Updated**: 2025-11-29
