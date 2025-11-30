# External Access Troubleshooting - 2025-11-29

## Current Status

**Problem**: External connections to yourdomain.com timeout - no response from ANY port

**What Works**:
- ✅ All 14 services running locally
- ✅ Traefik accessible on LAN (http://YOUR_NAS_IP:8080)
- ✅ Port forwarding configured in router (80→8080, 443→8443, 51820→51820)
- ✅ Router restarted
- ✅ Ugreen firewall DISABLED
- ✅ Ports 8080/8443 listening on 0.0.0.0 (all interfaces)
- ✅ DNS resolves correctly (yourdomain.com → YOUR_PUBLIC_IP)

**What Doesn't Work**:
- ❌ External HTTP access: http://YOUR_PUBLIC_IP (port 80) - timeout
- ❌ External HTTP access: http://YOUR_PUBLIC_IP:8080 - timeout
- ❌ External HTTPS access: https://YOUR_PUBLIC_IP:8443 - timeout
- ❌ Domain access: https://yourdomain.com - timeout

## Diagnosis

### Test Results

```bash
# Port scan from external network:
nc -zv YOUR_PUBLIC_IP 80     # ✅ Connection succeeded
nc -zv YOUR_PUBLIC_IP 443    # ✅ Connection succeeded

# HTTP requests from external network:
curl -I http://YOUR_PUBLIC_IP        # ❌ Timeout (10+ seconds)
curl -I http://YOUR_PUBLIC_IP:8080   # ❌ Timeout (10+ seconds)

# From phone (cellular network):
http://yourdomain.com         # ❌ "ERR_CONNECTION_FAILED"
http://YOUR_PUBLIC_IP:8080  # ❌ "No connection"
```

### Likely Causes (In Order of Probability)

1. **CGNAT (Carrier-Grade NAT)** - Most likely
   - ISP puts residential customers behind another NAT layer
   - Port forwarding cannot work with CGNAT
   - Connection "succeeds" at TCP level but traffic never reaches NAS
   - **Check**: Compare router WAN IP with public IP (ifconfig.me)
   - **Solution**: Cloudflare Tunnel, VPN-only access, or business internet

2. **ISP Blocking Incoming Connections**
   - Some ISPs block ALL incoming connections for residential
   - Less common than CGNAT but possible
   - **Solution**: Same as CGNAT

3. **Router Hairpin NAT Not Working**
   - Router may not support accessing WAN IP from LAN
   - Explains why external tests from same ISP fail
   - **Test**: Try from different network (mobile cellular, different ISP)

4. **Hidden ISP Router/Modem**
   - ISP-provided modem in router mode + separate router = double NAT
   - Port forwarding on inner router doesn't help
   - **Check**: Look for modem admin panel (often 192.168.1.1 or 192.168.100.1)

## Recommended Solutions

### Option A: Cloudflare Tunnel (RECOMMENDED)

**Pros**:
- Bypasses port forwarding entirely
- Works with CGNAT
- Free tier available
- Standard HTTPS URLs (no port numbers)
- DDoS protection included

**Cons**:
- Requires cloudflared daemon running on NAS
- Slight latency increase
- Traffic goes through Cloudflare

**Setup**:
See `CLOUDFLARE-TUNNEL-SETUP.md` (to be created)

### Option B: VPN-Only Access

**Pros**:
- Already have WireGuard configured (port 51820 UDP)
- No third-party services
- Full privacy
- UDP port more likely to work than TCP 80/443

**Cons**:
- Requires VPN connection to access services
- Not convenient for sharing with family/friends
- No SSL certificates (unless using Cloudflare DNS challenge)

**Test**:
1. Forward UDP 51820 in router (already configured)
2. From phone, try accessing WireGuard at wg.yourdomain.com:51820
3. If WireGuard connects, use it for all media stack access

### Option C: Contact ISP

**Pros**:
- "Proper" solution
- No workarounds needed

**Cons**:
- May require business internet plan ($$$)
- ISP may not support/understand request
- Can take days/weeks

**What to ask**:
"I need incoming connections on ports 80 and 443 for a home web server. Am I behind CGNAT? Can you provide a public IP address?"

### Option D: Use Different Port Range

**Pros**:
- Some ISPs only block ports 80/443/8080/8443
- Higher ports (10000+) may work

**Cons**:
- Unlikely to work if CGNAT is the issue
- URLs require port numbers

**Test**:
1. Change Traefik to ports 10080/10443
2. Forward 10080→10080, 10443→10443
3. Test http://YOUR_PUBLIC_IP:10080

## Next Steps

1. **Verify CGNAT**:
   ```bash
   # Check router WAN IP (in router admin panel, status page)
   # Compare to public IP:
   curl ifconfig.me
   # If different = CGNAT
   ```

2. **Test WireGuard**:
   - Port 51820 UDP might work even if TCP ports don't
   - Try connecting from phone using wg-easy config
   - If works, can use VPN for all access

3. **Implement Cloudflare Tunnel**:
   - Most reliable solution for CGNAT/blocked ports
   - Free tier supports unlimited bandwidth
   - Setup takes ~30 minutes

4. **Update DNS if needed**:
   - If using Cloudflare Tunnel, update DNS to point to tunnel
   - If VPN-only, can remove public DNS records

## Current Access Methods (Working)

While external access is broken, you can still access services:

**Local Network**:
- Homarr: http://YOUR_NAS_IP:9090
- Jellyfin: http://YOUR_NAS_IP:8096
- Sonarr: http://YOUR_NAS_IP:8989
- Radarr: http://YOUR_NAS_IP:7878
- All services accessible via Traefik: http://YOUR_NAS_IP:8080

**With WireGuard** (if port 51820 works):
- Connect to WireGuard VPN
- Access all services via your-tunnel.local or YOUR_NAS_IP

## Files to Create

- [ ] `CLOUDFLARE-TUNNEL-SETUP.md` - Step-by-step tunnel setup
- [ ] `VPN-ONLY-ACCESS.md` - Configure stack for VPN-only
- [ ] Update `DEPLOYMENT-PLAN.md` with external access lessons
- [ ] Update `README-UGREEN.md` FAQ with CGNAT info

---

**Status**: Investigation paused - awaiting user decision on solution path

**Last Updated**: 2025-11-29 21:55 UTC
