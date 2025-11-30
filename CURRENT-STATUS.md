# Current Deployment Status - 2025-11-30

## ✅ What's Working

**All 14 services deployed and running**:
- Traefik (192.168.100.2) - Reverse proxy
- Gluetun (192.168.100.3) - VPN gateway (Surfshark WireGuard, UK)
- qBittorrent, Sonarr, Radarr, Prowlarr (via VPN)
- Jellyfin (192.168.100.4)
- Jellyseerr (192.168.100.8)
- Bazarr (192.168.100.9)
- FlareSolverr (192.168.100.10)
- Notifiarr (192.168.100.11)
- Pi-hole (192.168.100.5)
- WireGuard (192.168.100.6)
- Homarr (192.168.100.7)

**Local access working perfectly**:
- Dashboard: http://YOUR_NAS_IP:9090
- All services accessible via Traefik routing

**External access via Cloudflare Tunnel - WORKING**:
- ✅ https://homarr.yourdomain.com - Dashboard
- ✅ https://jellyfin.yourdomain.com - Media server
- ✅ https://sonarr.yourdomain.com - TV show automation
- ✅ https://radarr.yourdomain.com - Movie automation
- ✅ https://prowlarr.yourdomain.com - Indexer manager
- ✅ https://qbit.yourdomain.com - Torrent client
- ✅ https://jellyseerr.yourdomain.com - Media requests
- ✅ https://bazarr.yourdomain.com - Subtitle management
- ✅ https://pihole.yourdomain.com - DNS & ad-blocking
- ✅ https://wg.yourdomain.com - VPN server UI
- ✅ https://traefik.yourdomain.com - Traefik dashboard

**Network configuration**:
- Static IPs assigned (no more conflicts)
- VPN routing working (qBittorrent through Surfshark)
- Docker networks configured
- Cloudflare Tunnel bypasses CGNAT/port forwarding issues

---

## ✅ DEPLOYMENT COMPLETE

**All services accessible externally via Cloudflare Tunnel!**

Port forwarding not needed - Cloudflare Tunnel creates outbound-only connection that bypasses CGNAT.

---

## ✅ Service Configuration - COMPLETE

All media automation services are configured and working:

### 1. ✅ Prowlarr Indexers Configured
- **6 indexers added**: The Pirate Bay, YTS, EZTV, TorrentGalaxy, LimeTorrents, ShowRSS
- FlareSolverr configured for Cloudflare-protected sites
- All indexers tested and working

### 2. ✅ Prowlarr Linked to Sonarr/Radarr
- Sonarr connected: `http://192.168.100.3:8989`
- Radarr connected: `http://192.168.100.3:7878`
- All 6 indexers automatically synced to both apps

### 3. ✅ qBittorrent Download Client Configured
- Added to Sonarr: `192.168.100.3:8085`
- Added to Radarr: `192.168.100.3:8085`
- Downloads routed through Surfshark VPN (Gluetun)
- Credentials secured (changed from defaults)

### 4. ✅ Jellyseerr Setup Complete
- Connected to Jellyfin: `http://192.168.100.4:8096`
- Linked to Sonarr: `192.168.100.3:8989` → `/tv`
- Linked to Radarr: `192.168.100.3:7878` → `/movies`
- Request workflow active

### 5. ✅ Download Workflow Tested
- TV show requested in Sonarr
- Indexers searched successfully
- qBittorrent downloading through VPN
- Files organizing to `/tv` folder
- Ready for Jellyfin playback

---

## 🎬 How to Use Your Media Stack

### Request Content (Easiest Way):
1. Go to **Jellyseerr** (https://jellyseerr.yourdomain.com)
2. Search for a movie or TV show
3. Click **Request**
4. Sonarr/Radarr automatically search and download
5. Watch in Jellyfin when ready

### Manual Search:
- **TV Shows**: https://sonarr.yourdomain.com → Add Series
- **Movies**: https://radarr.yourdomain.com → Add Movie

### Monitor Downloads:
- **qBittorrent**: https://qbit.yourdomain.com
- **Sonarr Activity**: https://sonarr.yourdomain.com → Activity
- **Radarr Activity**: https://radarr.yourdomain.com → Activity

### Watch Content:
- **Jellyfin**: https://jellyfin.yourdomain.com

---

## 🔐 Quick Access URLs

### External (via Cloudflare Tunnel - HTTPS with SSL)
- **Homarr Dashboard**: https://homarr.yourdomain.com
- **Traefik Dashboard**: https://traefik.yourdomain.com (basic auth: admin)
- **Jellyfin**: https://jellyfin.yourdomain.com
- **Jellyseerr**: https://jellyseerr.yourdomain.com
- **Sonarr**: https://sonarr.yourdomain.com
- **Radarr**: https://radarr.yourdomain.com
- **Prowlarr**: https://prowlarr.yourdomain.com
- **qBittorrent**: https://qbit.yourdomain.com
- **Bazarr**: https://bazarr.yourdomain.com
- **Pi-hole**: https://pihole.yourdomain.com
- **WireGuard**: https://wg.yourdomain.com

### Local Network (HTTP - faster for local use)
- **Homarr Dashboard**: http://YOUR_NAS_IP:9090
- **Traefik Dashboard**: http://YOUR_NAS_IP:9090
- **Jellyfin**: http://192.168.100.4:8096
- **Sonarr**: http://192.168.100.3:8989 (via Gluetun)
- **Radarr**: http://192.168.100.3:7878 (via Gluetun)
- **qBittorrent**: http://192.168.100.3:8085 (via Gluetun)

Note: Sonarr/Radarr/qBittorrent/Prowlarr share Gluetun's IP (192.168.100.3) due to `network_mode: service:gluetun`

---

## 📊 Summary

**Status**: ✅ FULLY OPERATIONAL - Ready to Use!

**Deployment**: Complete - all 14 services running
**External Access**: Working - Cloudflare Tunnel bypassed CGNAT
**Service Configuration**: Complete - full automation workflow active
**Testing**: Verified - downloads working through VPN

**Media Automation Pipeline**:
1. Request content → Jellyseerr
2. Search indexers → Prowlarr (6 indexers)
3. Manage downloads → Sonarr/Radarr
4. Download through VPN → qBittorrent (Surfshark UK)
5. Organize files → /tv and /movies folders
6. Stream content → Jellyfin

**SSL/TLS**: Cloudflare handles SSL termination, all external URLs use HTTPS

**Documentation**: Complete with lessons learned and usage guide

---

## 🎓 Key Lessons Learned

1. **Traefik + Cloudflare Tunnel Integration**
   - Cloudflare Tunnel sends HTTP traffic to Traefik (not HTTPS)
   - Disable HTTP→HTTPS redirect in Traefik when using tunnel
   - Cloudflare handles SSL/TLS termination
   - All Traefik routers must accept `web` entrypoint

2. **Services with network_mode: service:gluetun**
   - Cannot be auto-discovered by Traefik's Docker provider
   - Must create manual routes in Traefik dynamic config files
   - All share the same IP (gluetun container's IP)
   - Route to different ports on same IP

3. **Cloudflare DNS Configuration**
   - Tunnel routes require "Proxied" mode (orange cloud)
   - DNS-only mode (gray cloud) doesn't work with tunnels
   - Delete conflicting DNS records before creating tunnel routes

4. **Dynamic Configuration File Format**
   - Traefik file provider watches `/dynamic` directory
   - Simple HTTP routes don't need TLS config
   - Middleware can be defined in same file

---

**Last Updated**: 2025-11-30 01:30 UTC
