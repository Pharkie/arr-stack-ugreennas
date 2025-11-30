# Cloudflare DNS Setup Guide

This guide will walk you through configuring Cloudflare DNS records and API token for your media stack with automatic SSL certificates.

## Table of Contents

- [Choosing Your Domain Strategy](#choosing-your-domain-strategy)
- [Dynamic DNS Setup (Recommended)](#dynamic-dns-setup-recommended)
- [Step 1: Add Domain to Cloudflare](#step-1-add-domain-to-cloudflare)
- [Step 2: Create DNS Records](#step-2-create-dns-records)
- [Step 3: Generate API Token](#step-3-generate-api-token)
- [Step 4: Disable Cloudflare Proxy](#step-4-disable-cloudflare-proxy)
- [Step 5: Verify DNS](#step-5-verify-dns)
- [Optional: Cloudflare Security Settings](#optional-cloudflare-security-settings)
- [Troubleshooting](#troubleshooting)

---

## Choosing Your Domain Strategy

**This stack requires a domain managed by Cloudflare** for automatic SSL certificates via DNS challenge. You have several options:

### Option 1: Buy a Cheap Dedicated Domain (Recommended ✅)

**Buy a cheap domain just for your NAS services** - as little as **$8/year** for a `.cc` domain!

**Recommended: Buy directly from Cloudflare Registrar**
- Go to https://dash.cloudflare.com/ → Domain Registration → Register Domain
- Search for available domains
- **`.cc` domains are ~$8/year** and work great for this purpose
- Cloudflare sells at cost (no markup) so it's the cheapest option

**Examples**: `yourname-nas.cc`, `mymedia.cc`, `home-server.cc`

**Pros**:
- ✅ Super cheap (~$8/year for .cc)
- ✅ Simple setup (no existing DNS to migrate)
- ✅ Already on Cloudflare (no transfer needed)
- ✅ DNS challenge works immediately
- ✅ Wildcard SSL certificates
- ✅ Don't touch your existing domain/website

**Other registrars** (if Cloudflare doesn't have your TLD):
- **Porkbun** (often cheapest)
- **Namecheap** (reliable)

**Best for**: Most users, especially if you have an existing domain with complex DNS

---

### Option 2: Use Your Existing Domain

**Transfer DNS management to Cloudflare** (domain stays with current registrar):

**Pros**:
- ✅ Use your existing domain
- ✅ Services like `jellyfin.yourdomain.com`

**Cons**:
- ❌ Must migrate all existing DNS records
- ❌ Requires nameserver changes
- ❌ Risk of breaking existing services during migration

**Best for**: Users with simple DNS setups or new domains

---

### Option 3: Subdomain Delegation

**Keep main domain elsewhere, delegate a subdomain to Cloudflare**:

**Note**: This is complex and not recommended. Use Option 1 instead.

---

## Prerequisites

- Domain (see options above)
- Cloudflare account (free tier is sufficient)
- Your public IP address (find at: https://whatismyipaddress.com/)
- Optional: TP-Link or other router with DDNS support

---

## Dynamic DNS Setup (Recommended)

**Problem**: Home internet IPs often change, breaking your DNS records.

**Solution**: Use Dynamic DNS to automatically update Cloudflare when your IP changes.

### Router DDNS + Cloudflare CNAME (Easiest ✅)

If your router supports DDNS (TP-Link, ASUS, Netgear, etc.):

1. **Enable DDNS in your router**:
   - Router Admin → Dynamic DNS
   - Provider: Select your router's DDNS (e.g., TP-Link, tplinkdns.com)
   - Hostname: Choose a name (e.g., `yourname.tplinkdns.com`)
   - Save

2. **Test it works**:
   ```bash
   dig +short yourname.tplinkdns.com
   # Should show your current IP
   ```

3. **Use CNAME records in Cloudflare** (instead of A records):
   - Point your domain to the DDNS hostname
   - When your IP changes, router updates DDNS → Cloudflare follows automatically

**Example**:
```
Router updates: yourname.tplinkdns.com → YOUR_PUBLIC_IP
Cloudflare CNAME: yourdomain.com → yourname.tplinkdns.com
Result: yourdomain.com always points to correct IP!
```

---

### Alternative: DDNS Docker Container

If your router doesn't support DDNS, run this on your NAS:

```yaml
# Add to a compose file
services:
  cloudflare-ddns:
    image: oznu/cloudflare-ddns:latest
    container_name: cloudflare-ddns
    restart: unless-stopped
    environment:
      - API_KEY=${CF_DNS_API_TOKEN}
      - ZONE=yourdomain.com
      - SUBDOMAIN=@
      - PROXIED=false
```

Updates Cloudflare every 5 minutes automatically.

---

## Step 1: Add Domain to Cloudflare

If you haven't already added your domain to Cloudflare:

1. **Login to Cloudflare**: https://dash.cloudflare.com/

2. **Add Site**:
   - Click "Add a Site"
   - Enter: `yourdomain.com` (or `yourname-nas.com`, `yourdomain.com`, etc.)
   - Click "Add site"

3. **Select Plan**:
   - Choose "Free" plan
   - Continue

4. **Review DNS Records**:
   - Cloudflare will scan existing records
   - Click "Continue"

5. **Update Nameservers**:
   - Cloudflare will provide nameservers (e.g., `ns1.cloudflare.com`)
   - Update nameservers at your domain registrar
   - This can take up to 48 hours to propagate (usually much faster)

6. **Wait for Activation**:
   - You'll receive an email when the domain is active
   - Status will show "Active" in Cloudflare dashboard

---

## Step 2: Create DNS Records

### Method A: Using Router DDNS (Recommended for Dynamic IPs) ✅

**If you set up router DDNS** (e.g., TP-Link DDNS), use CNAME records pointing to your DDNS hostname:

1. **Navigate to DNS**:
   - Cloudflare Dashboard → Your Domain → **DNS** → **Records**

2. **Add Root CNAME**:
   - Click **"Add record"**
   - **Type**: `CNAME`
   - **Name**: `@`
   - **Target**: `yourname.tplinkdns.com` (your router's DDNS hostname)
   - **Proxy status**: ⚠️ **CRITICAL** ⚠️ - Click the cloud icon to toggle to **DNS only** (gray ☁️)
     - Default is **Proxied** (orange 🟠) - **YOU MUST CHANGE THIS!**
     - Click the orange cloud until it turns **GRAY**
   - **TTL**: Auto
   - Click **"Save"**

3. **Add Wildcard CNAME** (covers all subdomains):
   - Click **"Add record"**
   - **Type**: `CNAME`
   - **Name**: `*`
   - **Target**: `yourname.tplinkdns.com` (same as above)
   - **Proxy status**: ⚠️ **AGAIN - MUST BE GRAY CLOUD** ☁️ (DNS only, not orange!)
   - **TTL**: Auto
   - Click **"Save"**

**⚠️ CRITICAL - PROXY STATUS WARNING ⚠️**

```
❌ WRONG - Orange cloud (Proxied):    🟠 Proxied
✅ CORRECT - Gray cloud (DNS only):   ☁️ DNS only

Cloudflare DEFAULTS to orange (proxied). This breaks Traefik's DNS challenge!
You MUST click the cloud icon to toggle it to GRAY for both records!
```

**Result**:
- `yourdomain.com` → `yourname.tplinkdns.com` → Your IP
- `*.yourdomain.com` → `yourname.tplinkdns.com` → Your IP

When your IP changes, router updates DDNS → Cloudflare automatically follows!

---

### Method B: Direct A Records (If You Have Static IP)

**Only use if your IP never changes or you'll manually update DNS:**

1. **Find Your Public IP**:
   ```bash
   curl ifconfig.me
   ```

2. **Add A Record** (root):
   - Type: `A`
   - Name: `@`
   - IPv4 address: `YOUR_PUBLIC_IP`
   - **Proxy status**: ☁️ **DNS only** (gray, NOT orange!)
   - TTL: Auto

3. **Add Wildcard A Record**:
   - Type: `A`
   - Name: `*`
   - IPv4 address: `YOUR_PUBLIC_IP`
   - **Proxy status**: ☁️ **DNS only** (gray, NOT orange!)
   - TTL: Auto

---

### Verify DNS Records Are Correct

After creating records, **VERIFY THE CLOUD STATUS**:

| Type | Name | Target | Proxy Status | Correct? |
|------|------|--------|--------------|----------|
| CNAME | @ | yourname.tplinkdns.com | ☁️ DNS only (GRAY) | ✅ |
| CNAME | * | yourname.tplinkdns.com | ☁️ DNS only (GRAY) | ✅ |

**If you see orange clouds** 🟠 - **Click them to toggle to gray!**

This is the #1 mistake that breaks SSL certificate generation.

---

## Step 3: Generate API Token

Traefik needs an API token to automatically create SSL certificates via DNS challenge.

### Create Token

1. **Go to API Tokens**:
   - Cloudflare Dashboard → Profile (top right) → API Tokens
   - Or direct link: https://dash.cloudflare.com/profile/api-tokens

2. **Create Token**:
   - Click "Create Token"

3. **Use Template**:
   - Find "Edit zone DNS" template
   - Click "Use template"

4. **Configure Permissions**:
   - Permissions:
     - Zone → DNS → Edit
     - Zone → Zone → Read
   - Zone Resources:
     - Include → Specific zone → `yourdomain.com`
   - (Leave other settings as default)

5. **Create and Copy**:
   - Click "Continue to summary"
   - Click "Create Token"
   - **COPY THE TOKEN** (you can only see it once!)
   - Example: `1234567890abcdef1234567890abcdef12345678`

6. **Test Token** (optional):
   - Cloudflare provides a curl command to test
   - Run it to verify the token works

7. **Add to .env**:
   ```bash
   CF_DNS_API_TOKEN=1234567890abcdef1234567890abcdef12345678
   ```

---

## Step 4: Disable Cloudflare Proxy

**IMPORTANT**: For this setup to work, Cloudflare proxy MUST be disabled.

### Why?

- Traefik handles SSL/TLS certificates directly
- Cloudflare proxy would interfere with this
- We're using Cloudflare for DNS and API only

### How to Disable

1. **Navigate to DNS Records**:
   - Cloudflare Dashboard → `yourdomain.com` → DNS → Records

2. **Check Each Record**:
   - Look at "Proxy status" column
   - Should show **gray cloud** (DNS only)
   - NOT **orange cloud** (Proxied)

3. **Toggle if Needed**:
   - Click the cloud icon to toggle
   - Gray = DNS only = Correct ✅
   - Orange = Proxied = Incorrect ❌

### Verify All Records

All records should look like this:

```
Type    Name          Content              Proxy Status    TTL
A       @             203.0.113.50         DNS only        Auto
CNAME   traefik       yourdomain.com    DNS only        Auto
CNAME   homarr        yourdomain.com    DNS only        Auto
CNAME   jellyfin      yourdomain.com    DNS only        Auto
... (etc for all services)
```

---

## Step 5: Verify DNS

### Using Command Line

```bash
# Check A record
dig yourdomain.com +short
# Should return: YOUR_PUBLIC_IP

# Check CNAME records
dig traefik.yourdomain.com +short
dig jellyfin.yourdomain.com +short
# Should return: yourdomain.com OR YOUR_PUBLIC_IP
```

### Using Online Tools

- **DNS Checker**: https://dnschecker.org/
  - Enter: `traefik.yourdomain.com`
  - Check propagation globally

- **What's My DNS**: https://www.whatsmydns.net/
  - Enter: `jellyfin.yourdomain.com`
  - Verify it resolves to your IP

### Expected Results

All subdomains should resolve to your public IP address:
```
traefik.yourdomain.com    → 203.0.113.50
homarr.yourdomain.com     → 203.0.113.50
jellyfin.yourdomain.com   → 203.0.113.50
... (etc)
```

---

## Optional: Cloudflare Security Settings

### SSL/TLS Settings

1. **Navigate to SSL/TLS**:
   - Cloudflare Dashboard → `yourdomain.com` → SSL/TLS

2. **Set Mode**:
   - Choose: **Full** or **Full (strict)**
   - NOT "Flexible" (would cause redirect loops)

**Note**: Since we're using "DNS only" mode, this primarily affects the @ root domain if you ever enable the proxy later.

### Security Level

1. **Navigate to Security**:
   - Cloudflare Dashboard → `yourdomain.com` → Security → Settings

2. **Security Level**:
   - Recommended: **Medium**
   - Or adjust based on preference

### Firewall Rules (Optional)

Create rules to restrict access by country, IP, etc.:

1. **Navigate to Firewall**:
   - Cloudflare Dashboard → `yourdomain.com` → Security → WAF

2. **Create Rule**:
   - Example: Block all countries except UK
   - Field: Country
   - Operator: does not equal
   - Value: GB
   - Action: Block

**Note**: Only useful if you re-enable Cloudflare proxy (orange cloud).

---

## Router Configuration

### Port Forwarding

Configure your router to forward traffic to your NAS:

| Service | External Port | Internal IP | Internal Port | Protocol |
|---------|---------------|-------------|---------------|----------|
| HTTP | 80 | NAS_LOCAL_IP | 80 | TCP |
| HTTPS | 443 | NAS_LOCAL_IP | 443 | TCP |
| WireGuard | 51820 | NAS_LOCAL_IP | 51820 | UDP |

**Example** (if NAS is at 192.168.1.100):
- External: 80 → Internal: 192.168.1.100:80 (TCP)
- External: 443 → Internal: 192.168.1.100:443 (TCP)
- External: 51820 → Internal: 192.168.1.100:51820 (UDP)

### Router Access

1. Login to your router admin panel
2. Find "Port Forwarding" or "Virtual Server"
3. Add the three rules above
4. Save and apply

**Note**: Every router is different. Consult your router's manual if needed.

---

## Troubleshooting

### DNS not resolving

**Symptoms**: `dig traefik.yourdomain.com` returns nothing or NXDOMAIN

**Solutions**:
1. Wait 5-10 minutes for DNS propagation
2. Verify records are created in Cloudflare dashboard
3. Check nameservers are updated at registrar
4. Try a different DNS server: `dig @1.1.1.1 traefik.yourdomain.com`

### SSL certificate not generated

**Symptoms**: Traefik logs show "unable to generate certificate"

**Solutions**:
1. Verify `CF_DNS_API_TOKEN` is correct in `.env`
2. Check token permissions (Zone:DNS:Edit + Zone:Zone:Read)
3. Verify zone is `yourdomain.com` in token settings
4. Check `acme.json` permissions: `chmod 600 traefik/acme.json`
5. Wait 1-2 minutes (Let's Encrypt can be slow)
6. Check Traefik logs: `docker logs traefik -f`

### Services not accessible externally

**Symptoms**: Can access locally but not from outside network

**Solutions**:
1. Verify port forwarding configured (80, 443)
2. Check public IP hasn't changed
3. Verify DNS points to correct public IP
4. Test ports: https://www.yougetsignal.com/tools/open-ports/
5. Check firewall on NAS allows ports 80, 443
6. Verify router firewall allows incoming on 80, 443

### Certificate issued for wrong domain

**Symptoms**: SSL certificate shows Cloudflare or wrong domain

**Solutions**:
1. Verify Cloudflare proxy is **disabled** (gray cloud)
2. Orange cloud = proxied = wrong
3. Gray cloud = DNS only = correct
4. Toggle to DNS only and wait a few minutes
5. Restart Traefik: `docker compose -f docker-compose.traefik.yml restart`

### Redirect loop (too many redirects)

**Symptoms**: Browser shows "too many redirects" error

**Solutions**:
1. Cloudflare proxy must be **disabled** (DNS only)
2. If using proxy, set SSL/TLS mode to "Full" or "Full (strict)"
3. Check Traefik isn't double-redirecting

### Dynamic IP Changed

**Symptoms**: Services stopped working, DNS points to old IP

**Solutions**:
1. Find new public IP: `curl ifconfig.me`
2. Update A record in Cloudflare to new IP
3. Or set up Dynamic DNS (DDNS):
   - Use Cloudflare API
   - Or router DDNS feature
   - Or install ddclient on NAS

---

## DNS Record Summary

Copy this table for reference:

```
Domain: yourdomain.com
Public IP: __________ (fill in your IP)

Record Type: A
Name: @
Content: YOUR_PUBLIC_IP
Proxy: DNS only ✅

Record Type: CNAME (for each service)
Names: traefik, homarr, jellyfin, jellyseerr, sonarr, radarr, prowlarr,
       bazarr, qbit, pihole, wg, flaresolverr, notifiarr
Target: @
Proxy: DNS only ✅
```

---

## Next Steps

After completing DNS setup:

1. ✅ Verify all DNS records resolve correctly
2. ✅ Confirm API token is added to `.env`
3. ✅ Ensure port forwarding is configured
4. ✅ Proceed with Traefik deployment (see DEPLOYMENT-PLAN.md)

---

**Last Updated**: 2025-11-29
