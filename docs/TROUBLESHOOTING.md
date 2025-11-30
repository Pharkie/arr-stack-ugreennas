# Troubleshooting Guide

Common issues and solutions for the media automation stack.

## Table of Contents

- [Critical Issues](#critical-issues)
- [General Issues](#general-issues)
- [Traefik Issues](#traefik-issues)
- [VPN & Gluetun Issues](#vpn--gluetun-issues)
- [Download Issues (qBittorrent)](#download-issues-qbittorrent)
- [*arr Stack Issues](#arr-stack-issues)
- [Jellyfin Issues](#jellyfin-issues)
- [Networking Issues](#networking-issues)
- [Permission Issues](#permission-issues)
- [Performance Issues](#performance-issues)
- [Useful Commands](#useful-commands)

---

## Critical Issues

### Lost Access to Ugreen NAS Web Interface

**Symptoms**: Cannot access Ugreen NAS web interface via browser or Mac app

**Cause**: nginx (Ugreen web server) was stopped or Traefik was deployed while nginx was running on ports 80/443, causing a port conflict.

**Immediate Fix**:

1. **Reboot the NAS** (power button or unplug/replug)
2. Wait 2-3 minutes for full boot
3. nginx will start automatically and restore web access

**Permanent Solution** (to prevent this from happening again):

#### Step 1: Reconfigure nginx to use different ports

After rebooting and regaining access:

```bash
# SSH into NAS
ssh your-username@nas-ip

# Find all nginx config files using ports 80/443
sudo find /etc/nginx -type f -name '*.conf' -exec grep -l 'listen.*80\|listen.*443' {} \;

# For EACH file found, update the ports (example for ugreen_ssl.conf):
sudo sed -i 's/listen 80/listen 8080/g' /etc/nginx/ugreen_ssl.conf
sudo sed -i 's/listen \[::\]:80/listen [::]:8080/g' /etc/nginx/ugreen_ssl.conf
sudo sed -i 's/listen 443/listen 8443/g' /etc/nginx/ugreen_ssl.conf
sudo sed -i 's/listen \[::\]:443/listen [::]:8443/g' /etc/nginx/ugreen_ssl.conf
```

**Common Ugreen nginx files** to update:
- `/etc/nginx/ugreen_redirect.conf`
- `/etc/nginx/ugreen_ssl.conf`
- `/etc/nginx/ugreen_ssl2.conf`
- `/etc/nginx/ugreen_ssl_internal.conf`
- `/etc/nginx/ugreen_ssl_redirect.conf`

#### Step 2: Restart nginx

```bash
# Restart nginx (NOT stop - use restart!)
sudo systemctl restart nginx

# Verify it's running
sudo systemctl status nginx

# Check nginx is now on ports 8080/8443
sudo netstat -tulpn | grep nginx
```

#### Step 3: Test new access

Access NAS web UI at:
- HTTP: `http://YOUR_NAS_IP:8080` (or your NAS IP)
- HTTPS: `https://YOUR_NAS_IP:8443`
- Or: `http://your-tunnel.local:8080`

#### Step 4: Deploy Traefik safely

Now that nginx is on ports 8080/8443, Traefik can use ports 80/443 without conflicts:

```bash
# Deploy Traefik
cd /volume1/docker/arr-stack
docker compose -f docker-compose.traefik.yml up -d
```

**Result**:
- ✅ Ugreen NAS UI accessible on ports 8080/8443
- ✅ Traefik + media stack on standard ports 80/443
- ✅ Both services run simultaneously

**Prevention**:
⚠️ **NEVER** run `systemctl stop nginx` - always use `systemctl restart nginx` when making changes.

---

## General Issues

### Container won't start

**Symptoms**: Container exits immediately after starting

**Diagnosis**:
```bash
# Check container status
docker ps -a | grep <container_name>

# View logs
docker logs <container_name>

# Check for errors
docker compose -f docker-compose.arr-stack.yml ps
```

**Common Causes**:

1. **Missing environment variables**:
   ```bash
   # Check .env file has all required values
   cat .env | grep -v "^#" | grep "="
   ```
   Solution: Fill in all empty variables in `.env`

2. **Permission errors**:
   ```bash
   # Check ownership
   ls -la /volume1/docker/arr-stack/
   ```
   Solution: `sudo chown -R 1000:1000 /volume1/docker/arr-stack`

3. **Port conflicts**:
   ```bash
   # Check if port is in use
   netstat -tuln | grep <port>
   ```
   Solution: Stop conflicting service or change port

4. **Volume mount errors**:
   - Check paths exist: `ls /volume1/Media/downloads`
   - Create if missing: `mkdir -p /volume1/Media/{downloads,tv,movies}`

---

### Container stuck in "Restarting" state

**Symptoms**: `docker ps` shows status as "Restarting"

**Diagnosis**:
```bash
docker logs --tail 50 <container_name>
docker inspect <container_name> | grep -A 10 "State"
```

**Solutions**:
1. Stop and remove container:
   ```bash
   docker stop <container_name>
   docker rm <container_name>
   docker compose -f docker-compose.arr-stack.yml up -d <service_name>
   ```

2. Check healthcheck is working:
   - View healthcheck in docker-compose file
   - Test manually: `docker exec <container> curl -f http://localhost:<port>/`

---

### "Network not found" error

**Symptoms**: Error when starting services: "network traefik-proxy not found"

**Solution**:
```bash
# Create the network
docker network create \
  --driver=bridge \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  traefik-proxy

# Verify
docker network ls | grep traefik-proxy
docker network inspect traefik-proxy
```

---

## Traefik Issues

### SSL certificates not generating

**Symptoms**: Sites show "certificate invalid" or "not secure"

**Diagnosis**:
```bash
# Check Traefik logs
docker logs traefik -f | grep -i certificate

# Check acme.json
cat /volume1/docker/arr-stack/traefik/acme.json
# Should contain certificate data

# Check file permissions
ls -la /volume1/docker/arr-stack/traefik/acme.json
# Should be -rw------- (600)
```

**Solutions**:

1. **Fix acme.json permissions**:
   ```bash
   chmod 600 /volume1/docker/arr-stack/traefik/acme.json
   docker compose -f docker-compose.traefik.yml restart
   ```

2. **Verify Cloudflare API token**:
   ```bash
   # Check .env
   grep CF_DNS_API_TOKEN .env

   # Test token
   curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer YOUR_TOKEN" \
        -H "Content-Type:application/json"
   ```

3. **Check DNS records**:
   ```bash
   dig traefik.yourdomain.com +short
   # Should return your public IP
   ```

4. **Cloudflare proxy disabled**:
   - Go to Cloudflare dashboard
   - DNS records should show "DNS only" (gray cloud)
   - NOT "Proxied" (orange cloud)

5. **Let's Encrypt rate limits**:
   - Switch to staging server in `traefik.yml`:
     ```yaml
     caServer: https://acme-staging-v02.api.letsencrypt.org/directory
     ```
   - Test, then switch back to production

---

### Traefik dashboard not accessible

**Symptoms**: Cannot access `https://traefik.yourdomain.com:8080`

**Solutions**:

1. **Check Traefik is running**:
   ```bash
   docker ps | grep traefik
   docker logs traefik --tail 50
   ```

2. **Verify authentication**:
   ```bash
   # Check .env has dashboard auth
   grep TRAEFIK_DASHBOARD_AUTH .env
   ```
   Generate if missing:
   ```bash
   echo $(htpasswd -nb admin yourpassword) | sed -e s/\\$/\\$\\$/g
   ```

3. **Port 8080 accessible**:
   ```bash
   curl http://localhost:8080/dashboard/
   ```

4. **DNS resolves**:
   ```bash
   dig traefik.yourdomain.com +short
   ```

---

### 404 or Service Unavailable

**Symptoms**: Traefik returns 404 or "Service Unavailable"

**Diagnosis**:
```bash
# Check Traefik sees the service
docker logs traefik | grep -i <service_name>

# Verify container is on traefik-proxy network
docker inspect <container_name> | grep -A 5 Networks

# Check Traefik labels
docker inspect <container_name> | grep -A 20 Labels
```

**Solutions**:

1. **Service not on traefik-proxy network**:
   - Check docker-compose file has:
     ```yaml
     networks:
       - traefik-proxy
     ```
   - Recreate: `docker compose -f docker-compose.arr-stack.yml up -d <service>`

2. **Missing or incorrect Traefik labels**:
   - Verify `traefik.enable=true`
   - Check `traefik.http.routers.<name>.rule` matches domain
   - Check `traefik.http.services.<name>.loadbalancer.server.port` matches container port

3. **Service not running**:
   ```bash
   docker ps | grep <service_name>
   ```

---

## VPN & Gluetun Issues

### Gluetun not connecting to VPN

**Symptoms**: Gluetun logs show connection errors

**Diagnosis**:
```bash
docker logs gluetun -f
```

**Look for**:
- "Connected to VPN" = Success ✅
- "Authentication failed" = Credential error ❌
- "Timeout" = Network/firewall issue ❌
- "Wireguard settings: interface address is not set" = Missing WireGuard Address ❌

**Solutions**:

1. **WireGuard Address not set** (common with Surfshark):

   **Error**: "Wireguard settings: interface address is not set"

   **Cause**: The WireGuard Address field is NOT shown on Surfshark's web interface

   **Solution**:
   ```bash
   # You MUST download the full WireGuard config file to get the Address
   # 1. Go to: https://my.surfshark.com/
   # 2. VPN → Manual Setup → Router → WireGuard
   # 3. Generate or use existing key pair
   # 4. Click "Download" to get the .conf file
   # 5. Open the .conf file and find the Address line:
   #    [Interface]
   #    PrivateKey = your_private_key
   #    Address = 10.14.0.2/16    ← This is what you need!

   # Add to .env:
   SURFSHARK_WG_ADDRESS=10.14.0.2/16
   ```

2. **Check Surfshark WireGuard credentials**:
   ```bash
   grep SURFSHARK .env
   ```
   - Verify private key is correct
   - Verify address is set (e.g., 10.14.0.2/16)
   - Get from: https://my.surfshark.com/ → VPN → Manual Setup → WireGuard

2. **TUN device not available**:
   ```bash
   # On NAS
   ls -la /dev/net/tun
   ```
   Should exist. If not:
   ```bash
   sudo mkdir -p /dev/net
   sudo mknod /dev/net/tun c 10 200
   sudo chmod 666 /dev/net/tun
   ```

3. **NET_ADMIN capability**:
   - Check docker-compose has:
     ```yaml
     cap_add:
       - NET_ADMIN
     ```

4. **Firewall blocking VPN**:
   - Check NAS firewall allows outbound VPN connections
   - UDP/TCP ports for Surfshark (usually 1194, 51820)

5. **Change VPN server**:
   ```bash
   # In .env or docker-compose
   VPN_COUNTRIES=Germany,Switzerland
   ```

---

### VPN connected but no internet

**Symptoms**: Gluetun shows "Connected" but services can't reach internet

**Diagnosis**:
```bash
# Test from Gluetun
docker exec gluetun ping -c 3 1.1.1.1

# Test from qBittorrent
docker exec qbittorrent ping -c 3 1.1.1.1

# Check external IP
docker exec gluetun wget -qO- ifconfig.me
```

**Solutions**:

1. **Firewall rules**:
   Add to Gluetun environment:
   ```yaml
   - FIREWALL_OUTBOUND_SUBNETS=192.168.100.0/24,10.8.1.0/24
   ```

2. **DNS issues**:
   Add to Gluetun environment:
   ```yaml
   - DOT=off
   ```

3. **Restart Gluetun**:
   ```bash
   docker compose -f docker-compose.arr-stack.yml restart gluetun
   ```

---

### VPN IP leak detected

**Symptoms**: IP check shows home IP instead of VPN IP

**Test**:
```bash
# Should show VPN IP (not home IP)
docker exec gluetun wget -qO- ifconfig.me

# Test from qBittorrent
docker exec qbittorrent wget -qO- ifconfig.me
```

**Solutions**:

1. **Kill switch not working**:
   - Gluetun has built-in kill switch
   - If leaking, check firewall settings in Gluetun

2. **Service not using Gluetun network**:
   - Verify `network_mode: "service:gluetun"` in docker-compose
   - Recreate container

3. **Use ipleak.net torrent test**:
   - Download test torrent: https://ipleak.net/
   - Add to qBittorrent
   - Check IP on ipleak.net (should show VPN IP)

---

## Download Issues (qBittorrent)

### Cannot access qBittorrent WebUI

**Symptoms**: `https://qbit.yourdomain.com` not loading

**Diagnosis**:
```bash
# Check container running
docker ps | grep qbittorrent

# Check logs
docker logs qbittorrent --tail 50

# Test from inside container
docker exec qbittorrent curl -f http://localhost:8085/
```

**Solutions**:

1. **Gluetun not running**:
   - qBittorrent uses `network_mode: service:gluetun`
   - Start Gluetun first:
     ```bash
     docker compose -f docker-compose.arr-stack.yml up -d gluetun
     docker compose -f docker-compose.arr-stack.yml up -d qbittorrent
     ```

2. **Wrong port**:
   - Check Traefik label: `traefik.http.services.qbittorrent.loadbalancer.server.port=8085`
   - Should match qBittorrent WEBUI_PORT

3. **Authentication issue**:
   - Default: `admin` / `adminadmin`
   - Clear browser cookies and retry

---

### Downloads not starting

**Symptoms**: Torrents added but stuck at 0%

**Diagnosis**:
1. Check qBittorrent logs for errors
2. Verify VPN is connected
3. Check if torrent has seeds

**Solutions**:

1. **No internet (VPN issue)**:
   ```bash
   docker exec qbittorrent ping -c 3 1.1.1.1
   ```
   If fails, see [VPN Issues](#vpn--gluetun-issues)

2. **Port not forwarded**:
   - qBittorrent → Tools → Options → Connection
   - Disable UPnP (doesn't work behind VPN)
   - Port forwarding through VPN provider (if supported)

3. **Download path permissions**:
   ```bash
   ls -la /volume1/Media/downloads
   # Should be owned by 1000:1000
   sudo chown -R 1000:1000 /volume1/Media/downloads
   ```

4. **Disk full**:
   ```bash
   df -h /volume1/Media
   ```

---

### Downloads not moving to media folders

**Symptoms**: Download completes in qBittorrent but not in Jellyfin

**Diagnosis**:
1. Check Sonarr/Radarr Activity tab
2. Look for import errors
3. Check file permissions

**Solutions**:

1. **Path mapping incorrect**:
   - In Sonarr/Radarr Settings → Download Clients
   - Remote Path Mappings:
     - Host: `gluetun`
     - Remote Path: `/downloads/`
     - Local Path: `/downloads/`

2. **Permissions**:
   ```bash
   sudo chown -R 1000:1000 /volume1/Media/downloads
   sudo chown -R 1000:1000 /volume1/Media/tv
   sudo chown -R 1000:1000 /volume1/Media/movies
   ```

3. **Category mismatch**:
   - qBittorrent categories: `sonarr`, `radarr`
   - Should match download client config in Sonarr/Radarr

---

## *arr Stack Issues

### Sonarr/Radarr can't connect to qBittorrent

**Symptoms**: Test connection fails in Download Client settings

**Error**: "Unable to connect to qBittorrent"

**Solutions**:

1. **Wrong hostname**:
   - Should be `gluetun` (NOT `qbittorrent` or `localhost`)
   - Because qBittorrent uses `network_mode: service:gluetun`

2. **Wrong credentials**:
   - Username: `admin`
   - Password: (your qBittorrent password)

3. **qBittorrent auth settings**:
   - qBittorrent → Options → Web UI
   - Bypass authentication for localhost: **Disable**

---

### Prowlarr not syncing indexers

**Symptoms**: Indexers in Prowlarr but not in Sonarr/Radarr

**Solutions**:

1. **Check Apps configuration**:
   - Prowlarr → Settings → Apps
   - Verify Sonarr/Radarr are added
   - Test connection (should show green checkmark)

2. **API keys incorrect**:
   - Copy from Sonarr → Settings → General → Security → API Key
   - Paste into Prowlarr Apps config

3. **Manual sync**:
   - Prowlarr → Settings → Apps
   - Click "Sync App Indexers" button at bottom

4. **Check logs**:
   ```bash
   docker logs prowlarr --tail 100 | grep -i sync
   ```

---

### FlareSolverr not working

**Symptoms**: Cloudflare-protected indexers failing

**Solutions**:

1. **Not configured in Prowlarr**:
   - Prowlarr → Settings → Indexers → Add FlareSolverr
   - Host: `http://flaresolverr:8191`
   - Tags: `flaresolverr`

2. **Indexer not tagged**:
   - Edit indexer in Prowlarr
   - Add tag: `flaresolverr`

3. **FlareSolverr container not running**:
   ```bash
   docker ps | grep flaresolverr
   docker logs flaresolverr
   ```

---

## Jellyfin Issues

### Media not showing in Jellyfin

**Symptoms**: Libraries empty or missing media files

**Solutions**:

1. **Scan library**:
   - Dashboard → Libraries → (library name) → Scan Library

2. **Check file permissions**:
   ```bash
   ls -la /volume1/Media/movies
   ls -la /volume1/Media/tv
   # Files should be readable by user 1000
   ```

3. **Verify paths**:
   - Dashboard → Libraries → (library) → Manage Library
   - Paths should be: `/media/movies` or `/media/tv`
   - NOT `/volume1/Media/...`

4. **Check logs**:
   ```bash
   docker logs jellyfin --tail 100 | grep -i error
   ```

---

### Jellyfin transcoding not working

**Symptoms**: Video playback stutters or fails

**Solutions**:

1. **Hardware acceleration**:
   - Dashboard → Playback → Hardware Acceleration
   - Try different options (VAAPI, NVENC, etc.)
   - Or disable for CPU transcoding

2. **Insufficient resources**:
   ```bash
   docker stats jellyfin
   ```
   - Increase CPU/RAM limits if needed

3. **Missing codecs**:
   - Update Jellyfin: `docker compose -f docker-compose.arr-stack.yml pull jellyfin`

---

## Networking Issues

### IP Address Conflicts

**Symptoms**: Container fails to start with "address already in use" or similar error

**Cause**: Docker auto-assigns IPs from the network pool, causing conflicts with static IPs defined for other services.

**Example Error**:
```
Error response from daemon: failed to create endpoint traefik on network traefik-proxy:
Address already in use
```

**Diagnosis**:
```bash
# Check which container is using the conflicting IP
docker network inspect traefik-proxy | grep -A 10 "IPv4Address"

# See all assigned IPs
docker network inspect traefik-proxy | jq '.[].Containers'
```

**Solution**:

Assign static IPs to ALL services on the traefik-proxy network to prevent auto-assignment conflicts:

```yaml
# In docker-compose.arr-stack.yml
services:
  service-name:
    networks:
      traefik-proxy:
        ipv4_address: 192.168.100.X  # Assign specific IP
```

**IP Allocation Plan**:
- 192.168.100.1: Gateway (reserved)
- 192.168.100.2: Traefik
- 192.168.100.3: Gluetun
- 192.168.100.4: Jellyfin
- 192.168.100.5: Pi-hole
- 192.168.100.6: WireGuard
- 192.168.100.7: Homarr
- 192.168.100.8: Jellyseerr
- 192.168.100.9: Bazarr
- 192.168.100.10: FlareSolverr
- 192.168.100.11: Notifiarr

**After assigning IPs**:
```bash
# Stop all containers to clear IP assignments
docker compose -f docker-compose.traefik.yml -f docker-compose.arr-stack.yml down

# Redeploy with static IPs
docker compose -f docker-compose.traefik.yml up -d
docker compose -f docker-compose.arr-stack.yml up -d
```

---

### Services can't communicate

**Symptoms**: Jellyseerr can't connect to Sonarr/Radarr, etc.

**Diagnosis**:
```bash
# Test from one container to another
docker exec jellyseerr ping -c 3 sonarr
docker exec jellyseerr curl -f http://sonarr:8989/
```

**Solutions**:

1. **Not on same network**:
   - Check docker-compose: services should be on `traefik-proxy` or `vpn-net`
   - Recreate container

2. **Wrong hostname**:
   - Use container name as hostname (e.g., `sonarr`, not `sonarr.yourdomain.com`)
   - Exception: qBittorrent uses `gluetun` as hostname

3. **Firewall blocking**:
   - Check container firewall rules

---

### Can't access services externally

**Symptoms**: Works locally but not from outside network

**Diagnosis**:
```bash
# Test from external network (phone on cellular)
curl -I https://jellyfin.yourdomain.com

# Check DNS resolves to your public IP
dig yourdomain.com +short

# Find your current public IP
curl ifconfig.me
```

**Solutions**:

1. **Port forwarding not configured correctly**:

   **IMPORTANT**: If Traefik uses alternate ports (8080/8443), forward like this:

   | Service | External Port | Internal IP | Internal Port | Protocol |
   |---------|--------------|-------------|---------------|----------|
   | HTTP | 80 | YOUR_NAS_IP | 8080 | TCP |
   | HTTPS | 443 | YOUR_NAS_IP | 8443 | TCP |
   | WireGuard | 51820 | YOUR_NAS_IP | 51820 | UDP |

   - Router settings → Port Forwarding / NAT Forwarding / Virtual Server
   - External port 80 → NAS IP:8080 (NOT 80!)
   - External port 443 → NAS IP:8443 (NOT 443!)
   - Save and **restart your router** for changes to take effect

2. **Router needs restart**:
   - Some routers don't activate port forwarding until rebooted
   - Restart router and wait 2-3 minutes
   - Test again from external network

3. **ISP blocking ports 80/443**:
   - Many residential ISPs block incoming ports 80 and 443
   - Test with: `timeout 5 curl -I http://YOUR_PUBLIC_IP`
   - If times out, your ISP may be blocking
   - **Solutions**:
     - Use alternate ports (8080, 8443) in URLs
     - Contact ISP to unblock ports (business account may be needed)
     - Use Cloudflare Tunnel (bypasses port forwarding)

4. **DNS not resolving**:
   ```bash
   dig jellyfin.yourdomain.com +short
   # Should return your public IP
   ```
   - Update DNS records in Cloudflare to point to your public IP
   - Wait 5-10 minutes for DNS propagation

5. **Public IP changed** (Dynamic DNS issue):
   - Find current: `curl ifconfig.me`
   - Compare to DNS: `dig yourdomain.com +short`
   - If different, update Cloudflare DNS
   - Consider setting up DDNS auto-update

6. **Firewall blocking**:
   - Check NAS firewall allows ports 8080, 8443
   - Some NAS systems have built-in firewalls that block external access

7. **SSL certificate not generated yet**:
   - Certificates require port 80/443 to be accessible
   - Check Traefik logs: `docker logs traefik | grep -i certificate`
   - May take 1-2 minutes after deployment

8. **Ugreen NAS built-in firewall** (if enabled):
   - Check: Ugreen Control Panel → Security → Firewall
   - If enabled, you need to add rules for ports 8080, 8443
   - Via CLI (if firewall enabled):
     ```bash
     sudo iptables -I UG_INPUT -p tcp --dport 8080 -j ACCEPT
     sudo iptables -I UG_INPUT -p tcp --dport 8443 -j ACCEPT
     ```
   - **Note**: These iptables rules don't persist across reboots
   - Best practice: Disable Ugreen firewall, use Traefik security headers instead

9. **All external connections timing out**:
   - Symptoms: Even direct IP access fails (http://YOUR_IP:8080)
   - Possible causes:
     - ISP blocking ALL incoming connections (some residential ISPs do this)
     - Router port forwarding not actually working
     - ISP-provided router/modem with separate firewall
     - Double NAT situation (modem + router)

   **Diagnosis**:
   ```bash
   # From external network (phone cellular):
   # Try different ports to see if ANY work:
   curl -I http://YOUR_PUBLIC_IP:8080
   curl -I http://YOUR_PUBLIC_IP:80
   curl -I http://YOUR_PUBLIC_IP:443

   # All timeout = ISP or router issue, not NAS
   ```

   **Solutions**:
   - **Option A**: Cloudflare Tunnel (bypasses port forwarding entirely)
   - **Option B**: VPN-only access (use WireGuard, no external HTTP/HTTPS)
   - **Option C**: Contact ISP about incoming connection restrictions
   - **Option D**: Check for double NAT (modem in router mode + separate router)

---

## Permission Issues

### Docker permission denied on NAS

**Symptoms**: Cannot run docker commands without sudo

**Error**:
```
permission denied while trying to connect to the Docker daemon socket
```

**Solution**:

Run docker commands with sudo on Ugreen NAS:

```bash
# Instead of:
docker compose up -d

# Use:
sudo docker compose up -d

# Or with password via SSH:
echo 'YOUR_PASSWORD' | sudo -S docker compose up -d
```

**Alternative** (add user to docker group):
```bash
sudo usermod -aG docker $USER
# Logout and login again for changes to take effect
```

---

### "Permission denied" errors

**Symptoms**: Container logs show permission errors

**Common locations**:
- `/volume1/Media/*`
- `/volume1/docker/arr-stack/*`

**Solutions**:

1. **Fix ownership**:
   ```bash
   sudo chown -R 1000:1000 /volume1/docker/arr-stack
   sudo chown -R 1000:1000 /volume1/Media
   ```

2. **Fix permissions**:
   ```bash
   sudo chmod -R 755 /volume1/docker/arr-stack
   sudo chmod -R 755 /volume1/Media
   ```

3. **Check PUID/PGID**:
   - All linuxserver.io containers use PUID=1000, PGID=1000
   - Verify files are owned by 1000:1000

---

## Performance Issues

### High CPU usage

**Diagnosis**:
```bash
docker stats
```

**Solutions**:

1. **Jellyfin transcoding**:
   - Enable hardware acceleration
   - Reduce quality settings
   - Pre-transcode media

2. **Too many containers**:
   - Stop unused services
   - Increase NAS resources

3. **Disk I/O**:
   - Check with: `iostat -x 1`
   - Consider SSD for Docker volumes

---

### High memory usage

**Diagnosis**:
```bash
docker stats
free -h
```

**Solutions**:

1. **Add memory limits**:
   ```yaml
   services:
     jellyfin:
       mem_limit: 2g
   ```

2. **Restart hungry containers**:
   ```bash
   docker compose -f docker-compose.arr-stack.yml restart jellyfin
   ```

---

## Useful Commands

### Container Management

```bash
# View all running containers
docker ps

# View all containers (including stopped)
docker ps -a

# Start service
docker compose -f docker-compose.arr-stack.yml up -d <service>

# Stop service
docker compose -f docker-compose.arr-stack.yml stop <service>

# Restart service
docker compose -f docker-compose.arr-stack.yml restart <service>

# Remove service (keeps volumes)
docker compose -f docker-compose.arr-stack.yml rm <service>

# View logs
docker logs -f <container_name>

# View last 100 lines
docker logs --tail 100 <container_name>

# Execute command in container
docker exec -it <container_name> sh

# View resource usage
docker stats
```

### Network Management

```bash
# List networks
docker network ls

# Inspect network
docker network inspect traefik-proxy

# View which containers are on network
docker network inspect traefik-proxy | grep -A 3 Containers

# Remove network (stop containers first)
docker network rm traefik-proxy
```

### Volume Management

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect sonarr-config

# Backup volume
docker run --rm \
  -v sonarr-config:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/sonarr-backup.tar.gz -C /data .

# Restore volume
docker run --rm \
  -v sonarr-config:/data \
  -v $(pwd):/backup \
  alpine sh -c "cd /data && tar xzf /backup/sonarr-backup.tar.gz"

# Remove volume (DANGEROUS)
docker volume rm sonarr-config
```

### Cleanup

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune

# Full cleanup
docker system prune -a --volumes
```

---

## Getting More Help

### Check Logs

Always start by checking logs:
```bash
# Service-specific
docker logs <container_name> --tail 100

# All services
docker compose -f docker-compose.arr-stack.yml logs --tail 100
```

### Community Resources

- **Sonarr/Radarr Wiki**: https://wiki.servarr.com/
- **Gluetun**: https://github.com/qdm12/gluetun
- **Traefik Docs**: https://doc.traefik.io/
- **LinuxServer.io**: https://docs.linuxserver.io/
- **r/selfhosted**: https://reddit.com/r/selfhosted

### Reporting Issues

When asking for help, include:
1. What you're trying to do
2. What's happening instead
3. Relevant logs (`docker logs <service>`)
4. Docker Compose file section (if relevant)
5. Environment (.env values, redact secrets)

---

**Last Updated**: 2025-11-29
