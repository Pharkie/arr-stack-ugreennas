# Media Stack Deployment Plan

## Project Overview

**Goal**: Deploy a complete media automation stack on Ugreen NAS with VPN routing, reverse proxy, and SSL certificates.

**Domain**: yourdomain.com
**Network**: traefik-proxy (192.168.100.0/24)
**VPN Provider**: Surfshark
**Timezone**: Europe/London

---

## Architecture Note: Two-File Deployment

This stack uses **two separate Docker Compose files**:

1. **`docker-compose.traefik.yml`** - Infrastructure layer (reverse proxy, SSL, networking)
2. **`docker-compose.arr-stack.yml`** - Application layer (all media services)

**Why separate?**
- Independent lifecycle management (restart/update services without affecting Traefik)
- Scalability (one Traefik can serve multiple future stacks)
- Clean separation of concerns (infrastructure vs. applications)
- Easier troubleshooting (isolated logs and configurations)

**⚠️ IMPORTANT: Deployment Order Matters!**
1. **Deploy Traefik FIRST** → Creates the `traefik-proxy` network and sets up SSL
2. **Deploy arr-stack SECOND** → Joins the existing network and uses Traefik for routing

If you deploy in the wrong order, arr-stack will fail with "network not found" error.

---

## Deployment Status

- [ ] **Phase 1**: Nginx Port Reconfiguration
- [ ] **Phase 2**: Pre-deployment Setup
- [ ] **Phase 3**: Traefik Deployment
- [ ] **Phase 4**: VPN & Core Services
- [ ] **Phase 5**: Media Services
- [ ] **Phase 6**: Infrastructure Services
- [ ] **Phase 7**: Service Configuration & Integration
- [ ] **Phase 8**: Testing & Verification

---

## Phase 1: Nginx Port Reconfiguration

⚠️ **DO THIS FIRST OR YOU WILL LOSE NAS ACCESS**

**Why**: Ugreen NAS (nginx) and Traefik both want ports 80/443. Move nginx to 8080/8443.

### Quick Steps

```bash
# SSH to NAS
ssh your-username@nas-ip

# Update all nginx configs (one command)
for file in /etc/nginx/ugreen*.conf; do
  sudo sed -i 's/listen 80/listen 8080/g' "$file"
  sudo sed -i 's/listen \[::\]:80/listen [::]:8080/g' "$file"
  sudo sed -i 's/listen 443/listen 8443/g' "$file"
  sudo sed -i 's/listen \[::\]:443/listen [::]:8443/g' "$file"
done

# Restart nginx (NOT stop!)
sudo systemctl restart nginx

# Test: Access NAS at http://nas-ip:8080
```

**Done**: NAS UI on port 8080, Traefik can use port 80/443

---

## Phase 2: Pre-deployment Setup

### 1.1 Create Directory Structure on NAS
**Status**: ⏳ Pending

```bash
# SSH into Ugreen NAS
ssh your-username@ugreen-nas-ip

# Create directory structure
sudo mkdir -p /volume1/docker/arr-stack/{gluetun-config,jellyseerr/config,bazarr/config,notifiarr,homarr/{configs,icons,data},traefik/dynamic}
sudo mkdir -p /volume1/Media/{downloads,tv,movies}

# Set permissions
sudo chown -R 1000:1000 /volume1/docker/arr-stack
sudo chown -R 1000:1000 /volume1/Media

# Create acme.json for Traefik SSL certificates
sudo touch /volume1/docker/arr-stack/traefik/acme.json
sudo chmod 600 /volume1/docker/arr-stack/traefik/acme.json
```

**Verification**:
```bash
ls -la /volume1/docker/arr-stack
ls -la /volume1/Media
```

---

### 1.2 Configure Environment Variables
**Status**: ⏳ Pending

**Follow these steps in order** to fill out your `.env` file:

#### Step 1: Copy Template
```bash
cp .env.example .env
```

#### Step 2: Cloudflare API Token
1. Open: https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token" → Use "Edit zone DNS" template
3. **Add permissions** (click "+ Add more"):
   - `Zone → DNS → Edit`
   - `Zone → Zone → Read`
4. Zone Resources: "All zones" (or specific zone)
5. Create and **copy the token**
6. Add to `.env`: `CF_DNS_API_TOKEN=your_token_here`

#### Step 3: Surfshark VPN Credentials (WireGuard)
1. Go to: https://my.surfshark.com/
2. Navigate: VPN → Manual Setup → Router → WireGuard
3. Select "I don't have a key pair" to generate new keys
4. Click **"Download"** to get the full WireGuard configuration file (`.conf`)
5. Open the downloaded file and extract:
   - **PrivateKey** (from [Interface] section)
   - **Address** (from [Interface] section, e.g., 10.14.0.2/16)
6. Add to `.env`:
   ```
   SURFSHARK_PRIVATE_KEY=your_private_key_here
   SURFSHARK_WG_ADDRESS=10.14.0.2/16
   ```
**Note**: The Address field is NOT shown on the web interface - you MUST download the config file.

#### Step 4: Pi-hole Password
Generate secure password or choose your own:
```bash
openssl rand -base64 24
```
Add to `.env`: `PIHOLE_UI_PASS=your_password`

**Save this password** - you'll need it to login!

#### Step 5: WireGuard Password Hash
Choose a password, then generate hash:
```bash
docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'YOUR_PASSWORD'
```
Copy the `$2a$12$...` hash and add to `.env`:
```
WG_PASSWORD_HASH=$2a$12$your_generated_hash
```

**Save your password** (the plain text one) - you'll need it to login!

#### Step 6: Traefik Dashboard Auth
Choose password, then generate htpasswd:
```bash
docker run --rm httpd:alpine htpasswd -nb admin 'your_password' | sed -e s/\\$/\\$\\$/g
```
Copy the entire output and add to `.env`:
```
TRAEFIK_DASHBOARD_AUTH=admin:$$apr1$$...$$...
```

**Save your password** - you'll need it to login!

#### Verify .env Complete
Your `.env` should have all fields filled:
- ✅ CF_DNS_API_TOKEN
- ✅ SURFSHARK_USER
- ✅ SURFSHARK_PASSWORD
- ✅ PIHOLE_UI_PASS
- ✅ WG_PASSWORD_HASH
- ✅ TRAEFIK_DASHBOARD_AUTH

**See [README-UGREEN.md](README-UGREEN.md#step-by-step-filling-out-the-env-file) for detailed instructions.**

---

### 1.3 Create Docker Network
**Status**: ⏳ Pending

```bash
docker network create \
  --driver=bridge \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  traefik-proxy
```

**Verification**:
```bash
docker network ls | grep traefik-proxy
docker network inspect traefik-proxy
```

---

### 1.4 Copy Traefik Configuration Files
**Status**: ⏳ Pending

```bash
# Copy traefik.yml to NAS
scp traefik/traefik.yml user@nas:/volume1/docker/arr-stack/traefik/

# Copy dynamic TLS configuration
scp traefik/dynamic/tls.yml user@nas:/volume1/docker/arr-stack/traefik/dynamic/
```

---

## Phase 3: Traefik Deployment

### 2.1 Deploy Traefik
**Status**: ⏳ Pending

```bash
cd /path/to/arr-stack-ugreennas
docker compose -f docker-compose.traefik.yml up -d
```

**Expected Output**:
```
[+] Running 2/2
 ✔ Network traefik-proxy  Created
 ✔ Container traefik      Started
```

---

### 2.2 Verify Traefik Deployment
**Status**: ⏳ Pending

**Check Logs**:
```bash
docker logs traefik -f
```

**Look for**:
- ✅ "Configuration loaded"
- ✅ "Server listening on :80"
- ✅ "Server listening on :443"
- ✅ Cloudflare certificate acquisition (may take 1-2 minutes)

**Access Dashboard**:
- URL: `https://traefik.yourdomain.com:8080`
- Check for SSL certificate
- Verify HTTP → HTTPS redirect

**Common Issues**:
- If certificate fails: Check `CF_DNS_API_TOKEN` is correct
- If dashboard not accessible: Verify DNS records (see DNS-SETUP.md)
- Check acme.json permissions: `ls -la traefik/acme.json` (should be 600)

---

## Phase 4: VPN & Core Services

### 3.1 Deploy Gluetun (VPN Gateway)
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d gluetun
```

**Verification**:
```bash
docker logs gluetun -f
```

**Look for**:
- ✅ "Connected to VPN"
- ✅ IP address from VPN provider
- ✅ No firewall errors

**Test VPN Connection**:
```bash
# Check external IP through Gluetun
docker exec gluetun wget -qO- ifconfig.me
```
Should show Surfshark IP, NOT your home IP.

---

### 3.2 Deploy qBittorrent
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d qbittorrent
```

**Verification**:
```bash
docker logs qbittorrent -f
```

**Access**:
- URL: `https://qbit.yourdomain.com`
- Default credentials: `admin` / `adminadmin`
- **Immediately change password!**

**Verify VPN**:
- In qBittorrent, go to: Tools → Execution Log
- Check connection IP (should be VPN IP)
- Or use: https://ipleak.net/ torrent test

---

### 3.3 Deploy *arr Stack (Sonarr, Radarr, Prowlarr)
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d sonarr radarr prowlarr
```

**Verification**:
```bash
docker ps | grep -E "sonarr|radarr|prowlarr"
```

**Access**:
- Sonarr: `https://sonarr.yourdomain.com`
- Radarr: `https://radarr.yourdomain.com`
- Prowlarr: `https://prowlarr.yourdomain.com`

---

## Phase 5: Media Services

### 4.1 Deploy Jellyfin
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d jellyfin
```

**Access**: `https://jellyfin.yourdomain.com`

**Initial Setup**:
1. Create admin account
2. Add media libraries:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
3. Configure metadata providers

---

### 4.2 Deploy Jellyseerr
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d jellyseerr
```

**Access**: `https://jellyseerr.yourdomain.com`

**Configuration**: See Phase 5.4

---

### 4.3 Deploy Bazarr
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d bazarr
```

**Access**: `https://bazarr.yourdomain.com`

**Configuration**: See Phase 5.5

---

### 4.4 Deploy Supporting Services
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d flaresolverr notifiarr
```

**Note**: Notifiarr requires manual config file setup (see README-UGREEN.md)

---

## Phase 6: Infrastructure Services

### 5.1 Deploy Pi-hole
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d pihole
```

**Access**: `https://pihole.yourdomain.com/admin`

**Verification**:
```bash
# Test DNS resolution
dig @192.168.100.5 -p 53535 google.com
```

---

### 5.2 Deploy WireGuard
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d wg-easy
```

**Access**: `https://wg.yourdomain.com`

**Port Forwarding**: Ensure UDP port 51820 is forwarded on your router.

---

### 5.3 Deploy Homarr (Dashboard)
**Status**: ⏳ Pending

```bash
docker compose -f docker-compose.arr-stack.yml up -d homarr
```

**Access**: `https://homarr.yourdomain.com`

**Configuration**: Add all services to dashboard (see README-UGREEN.md)

---

## Phase 7: Service Configuration & Integration

### 6.1 Configure Prowlarr Indexers
**Status**: ⏳ Pending

1. Access Prowlarr: `https://prowlarr.yourdomain.com`
2. Settings → Indexers → Add Indexer
3. Add your preferred indexers
4. Configure FlareSolverr if needed:
   - Settings → Indexers → Add FlareSolverr
   - URL: `http://flaresolverr:8191`

---

### 6.2 Link Prowlarr to Sonarr/Radarr
**Status**: ⏳ Pending

**In Prowlarr**:
1. Settings → Apps → Add Application
2. Add Sonarr:
   - URL: `http://sonarr:8989`
   - API Key: (get from Sonarr → Settings → General)
3. Add Radarr:
   - URL: `http://radarr:7878`
   - API Key: (get from Radarr → Settings → General)
4. Sync: Settings → Apps → Sync App Indexers

---

### 6.3 Configure Download Client
**Status**: ⏳ Pending

**In Sonarr & Radarr**:
1. Settings → Download Clients → Add → qBittorrent
2. Host: `gluetun` (using network_mode: service:gluetun)
3. Port: `8085`
4. Username: `admin`
5. Password: (your qBittorrent password)
6. Category: `sonarr` or `radarr`

---

### 6.4 Configure Jellyseerr
**Status**: ⏳ Pending

1. Access: `https://jellyseerr.yourdomain.com`
2. Sign in with Jellyfin
3. Settings → Jellyfin:
   - URL: `http://jellyfin:8096`
   - Link account
4. Settings → Services:
   - Add Sonarr: `http://sonarr:8989`
   - Add Radarr: `http://radarr:7878`

---

### 6.5 Configure Bazarr
**Status**: ⏳ Pending

1. Access: `https://bazarr.yourdomain.com`
2. Settings → Sonarr:
   - URL: `http://sonarr:8989`
   - API Key: (from Sonarr)
3. Settings → Radarr:
   - URL: `http://radarr:7878`
   - API Key: (from Radarr)
4. Settings → Subtitles:
   - Add subtitle providers (OpenSubtitles, etc.)

---

## Phase 8: Testing & Verification

### 7.1 VPN Routing Test
**Status**: ⏳ Pending

```bash
# Check Gluetun external IP
docker exec gluetun wget -qO- ifconfig.me

# Should show VPN IP (Surfshark)
```

---

### 7.2 Download Workflow Test
**Status**: ⏳ Pending

1. In Sonarr, add a TV show
2. Search for episode
3. Download episode
4. Verify:
   - qBittorrent shows download
   - Download completes
   - Sonarr imports to `/volume1/Media/tv`
   - Jellyfin shows new episode

---

### 7.3 SSL Certificate Verification
**Status**: ⏳ Pending

Check all services have valid SSL:
- [ ] traefik.yourdomain.com
- [ ] qbit.yourdomain.com
- [ ] sonarr.yourdomain.com
- [ ] radarr.yourdomain.com
- [ ] prowlarr.yourdomain.com
- [ ] jellyfin.yourdomain.com
- [ ] jellyseerr.yourdomain.com
- [ ] bazarr.yourdomain.com
- [ ] pihole.yourdomain.com
- [ ] wg.yourdomain.com
- [ ] homarr.yourdomain.com

---

### 7.4 DNS & Pi-hole Test
**Status**: ⏳ Pending

```bash
# Test DNS resolution
dig @192.168.100.5 -p 53535 google.com

# Access Pi-hole dashboard
# Verify queries are being logged
```

---

### 7.5 WireGuard VPN Test
**Status**: ⏳ Pending

1. Access: `https://wg.yourdomain.com`
2. Create new client
3. Download config
4. Connect with WireGuard client
5. Verify:
   - Can access local services
   - DNS uses Pi-hole (10.8.1.200)

---

## Deployment Notes

### Date Started
2025-11-29

### Deployment Status
✅ **COMPLETED** - All services deployed and running

**Deployed Services**:
- ✅ Traefik (192.168.100.2) - Reverse proxy with SSL
- ✅ Gluetun (192.168.100.3) - VPN gateway (Surfshark WireGuard, UK)
- ✅ qBittorrent - Download client (via Gluetun)
- ✅ Sonarr - TV show management (via Gluetun)
- ✅ Radarr - Movie management (via Gluetun)
- ✅ Prowlarr - Indexer manager (via Gluetun)
- ✅ Jellyfin (192.168.100.4) - Media server
- ✅ Jellyseerr (192.168.100.8) - Request manager
- ✅ Bazarr (192.168.100.9) - Subtitle manager
- ✅ FlareSolverr (192.168.100.10) - Cloudflare bypass
- ✅ Notifiarr (192.168.100.11) - Notifications
- ✅ Pi-hole (192.168.100.5) - DNS/Ad-blocking
- ✅ WireGuard (192.168.100.6) - VPN server
- ✅ Homarr (192.168.100.7) - Dashboard

**Pending**:
- ⏳ External access (port forwarding not working - likely CGNAT/ISP blocking)
- ⏳ External SSL certificate generation (requires external access)
- ⏳ Service configuration & integration

**External Access Status**:
- ❌ Port forwarding configured but connections timeout
- ❌ All external connections fail (ports 80, 443, 8080, 8443)
- ✅ Local access works perfectly (YOUR_NAS_IP)
- 🔍 Investigating: CGNAT, ISP blocking, or router issue
- 💡 Recommended solution: Cloudflare Tunnel (see CLOUDFLARE-TUNNEL-SETUP.md)

### Issues Encountered

1. **IP Address Conflicts**
   - **Problem**: Notifiarr auto-assigned 192.168.100.2 (Traefik's reserved IP)
   - **Impact**: Traefik, Jellyfin, and Homarr couldn't start
   - **Solution**: Assigned static IPs to ALL services on traefik-proxy network
   - **Lesson**: Always use static IPs when mixing static and dynamic assignments

2. **WireGuard Address Field Missing**
   - **Problem**: Gluetun failed with "Wireguard settings: interface address is not set"
   - **Cause**: Surfshark web interface doesn't show the Address field
   - **Solution**: Downloaded full .conf file to extract Address (10.14.0.2/16)
   - **Lesson**: WireGuard requires both PrivateKey AND Address - must download config file

3. **Docker Permission Issues**
   - **Problem**: Docker commands require sudo on Ugreen NAS
   - **Solution**: Use `sudo docker compose` or `echo 'PASSWORD' | sudo -S docker compose`
   - **Lesson**: Ugreen NAS doesn't add regular users to docker group by default

4. **Port Forwarding Configuration**
   - **Problem**: External access timing out
   - **Potential causes**: Router needs restart, ISP blocking ports 80/443
   - **Configuration**: External 80→8080, 443→8443, 51820→51820 (UDP)
   - **Status**: Configured, awaiting router restart for verification

5. **Ugreen NAS Nginx Port Conflicts**
   - **Problem**: Ugreen NAS auto-resets nginx to ports 80/443 on reboot
   - **Solution**: Configured Traefik to use ports 8080/8443 instead
   - **Lesson**: Don't fight the NAS - use alternate ports for services

6. **External Access Failure (CGNAT/ISP Blocking)**
   - **Problem**: All external connections timeout despite correct port forwarding
   - **Symptoms**: Ports show as "open" but HTTP/HTTPS requests timeout after 10+ seconds
   - **Testing**: Tried ports 80, 443, 8080, 8443 - all fail from external network
   - **Local access**: Works perfectly (YOUR_NAS_IP:8080)
   - **Likely cause**: CGNAT (Carrier-Grade NAT) or ISP blocking incoming connections
   - **Investigation**:
     - ✅ Port forwarding configured correctly in router
     - ✅ Router restarted
     - ✅ Ugreen firewall disabled
     - ✅ Ports listening on 0.0.0.0
     - ✅ DNS resolves correctly
     - ❌ External connections timeout from multiple networks
   - **Recommended solution**: Cloudflare Tunnel (bypasses port forwarding entirely)
   - **Alternative solutions**: VPN-only access, contact ISP about CGNAT
   - **Status**: Documented in EXTERNAL-ACCESS-ISSUE.md and CLOUDFLARE-TUNNEL-SETUP.md

### Lessons Learned

1. **Static IP Management**
   - Assign static IPs to ALL services on a network to prevent conflicts
   - Document IP allocation plan upfront
   - Use sequential IPs for easier troubleshooting

2. **VPN Provider Specifics**
   - Each VPN provider has different credential requirements
   - Surfshark WireGuard needs: PrivateKey + Address (from .conf file)
   - Always download full config files, don't rely on web UI

3. **NAS-Specific Considerations**
   - Ugreen NAS manages nginx automatically - don't modify directly
   - Use alternate ports (8080/8443) for Traefik to avoid conflicts
   - Docker commands need sudo by default

4. **Port Forwarding**
   - External port → Internal port mapping is crucial
   - Router may need restart for port forwarding to activate
   - ISPs may block residential ports 80/443

5. **Deployment Order**
   - Always deploy Traefik first (creates network, handles SSL)
   - Deploy Gluetun before VPN-dependent services
   - Stop all containers before changing network configuration

6. **Documentation**
   - Keep troubleshooting docs updated during deployment
   - Document actual IPs, credentials location, error messages
   - Screenshots of router config help for future reference

7. **External Access Challenges**
   - Port forwarding may not work (CGNAT, ISP blocking very common)
   - Always test external access from different network (cellular data)
   - Have backup plan: Cloudflare Tunnel, VPN-only access
   - CGNAT affects ~30% of residential internet connections
   - ISPs rarely advertise CGNAT - only discover by testing

---

## Next Steps After Deployment

1. **Security Hardening**:
   - Change all default passwords
   - Enable 2FA where possible
   - Review Traefik middleware (rate limiting, etc.)
   - Consider restricting *arr services to VPN/local network only

2. **Backup Strategy**:
   - Set up automated backups of Docker volumes
   - Document restore procedure
   - Test backup restoration

3. **Monitoring**:
   - Consider adding Prometheus/Grafana
   - Set up alerts for service failures
   - Monitor disk space

4. **Optimization**:
   - Tune qBittorrent settings
   - Optimize Jellyfin transcoding
   - Review indexer performance in Prowlarr

---

## Quick Reference

### Service URLs
| Service | URL |
|---------|-----|
| Traefik Dashboard | https://traefik.yourdomain.com:8080 |
| Homarr (Main Dashboard) | https://homarr.yourdomain.com |
| Jellyfin | https://jellyfin.yourdomain.com |
| Jellyseerr | https://jellyseerr.yourdomain.com |
| qBittorrent | https://qbit.yourdomain.com |
| Sonarr | https://sonarr.yourdomain.com |
| Radarr | https://radarr.yourdomain.com |
| Prowlarr | https://prowlarr.yourdomain.com |
| Bazarr | https://bazarr.yourdomain.com |
| Pi-hole | https://pihole.yourdomain.com/admin |
| WireGuard | https://wg.yourdomain.com |

### Docker Commands
```bash
# View all services
docker compose -f docker-compose.arr-stack.yml ps

# View logs for specific service
docker logs -f <container_name>

# Restart service
docker compose -f docker-compose.arr-stack.yml restart <service_name>

# Stop all services
docker compose -f docker-compose.arr-stack.yml down

# Update and restart service
docker compose -f docker-compose.arr-stack.yml pull <service_name>
docker compose -f docker-compose.arr-stack.yml up -d <service_name>
```

### Network Information
- **traefik-proxy**: 192.168.100.0/24 (Gateway: .1)
- **vpn-net**: 10.8.1.0/24 (Internal VPN routing)
- **WireGuard VPN**: 10.8.0.0/24 (Client connections)

---

**Last Updated**: 2025-11-29
