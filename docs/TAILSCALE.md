# + Tailscale (remote LAN access)

> Return to [Setup Guide](SETUP.md) · See also [Remote Access (Cloudflare Tunnel)](REMOTE-ACCESS.md)

Reach your whole LAN (Pi-hole, `*.lan` domains, admin UIs, Home Assistant, the NAS) from anywhere — including hotel WiFi, mobile data, or networks behind CGNAT.

**Cloudflared vs Tailscale — when to use which:**
- **Cloudflared** publishes specific HTTP services (Jellyfin, Seerr) to the public internet via your domain.
- **Tailscale** gives *you* (and devices you authorise) private access to the entire LAN — including admin UIs you'd never expose publicly.
- They're complementary. Run both.

**Requirements:**
- Free [Tailscale](https://tailscale.com) account (up to 100 devices, personal use)
- The stack already deployed and running on the NAS

## 1. Create your Tailscale account

Sign up at [login.tailscale.com](https://login.tailscale.com/) — it federates with Google/Microsoft/GitHub/Apple, no separate password needed. Keep the browser tab open; you'll use the admin console in step 3.

## 2. Deploy the Tailscale container

```bash
cd $NAS_STACK_DIR
docker compose -f docker-compose.tailscale.yml up -d
```

The container starts but isn't authenticated yet. Get the login URL:

```bash
docker logs tailscale 2>&1 | grep -A1 "To authenticate"
```

You should see a line like `https://login.tailscale.com/a/abc123...`. Open it in your browser, sign into the same account from step 1, and approve the device.

> **Why interactive?** The compose file leaves `TS_AUTHKEY` unset for first-run auth. For automated re-auth (e.g. after a long outage), generate an [auth key](https://login.tailscale.com/admin/settings/keys), put it in `.env` as `TS_AUTHKEY=tskey-auth-…`, and `docker compose up -d` again.

## 3. Configure the tailnet (Tailscale admin console)

Three one-time settings at [login.tailscale.com/admin](https://login.tailscale.com/admin):

**a) Approve the subnet route.** Open *Machines* → click your NAS → *Edit route settings* → tick `10.10.0.0/24` (or whatever you set as `LAN_SUBNET`) → Save. Without this, peers see the route but Tailscale won't forward traffic to it.

**b) Disable key expiry on the NAS.** Same page → *Disable key expiry*. The NAS is an always-on router; you don't want it to silently disconnect every ~6 months.

**c) Split DNS for `*.lan`.** Open *DNS* → *Add nameserver* → *Custom* → IP `10.10.0.10` → *Restrict to domain*: `lan` → Save. This makes `sonarr.lan`, `homeassistant.lan` etc. resolve via Pi-hole when remote.

> **Why split DNS?** Tailscale doesn't override your device's normal DNS unless you tell it to (we set `TS_ACCEPT_DNS=false`). The split-DNS rule says "only for `.lan` queries, ask Pi-hole" — everything else keeps using the device's normal resolver.

## 4. Install Tailscale on your devices

- **iOS/Android**: install the Tailscale app, sign in with the same account
- **macOS**: `brew install --cask tailscale` (or download from tailscale.com/download)
- **Windows/Linux**: see [tailscale.com/download](https://tailscale.com/download)

Each device shows up in *Machines* in the admin console after first sign-in.

## 5. Test it

Put your laptop on a phone hotspot (simulates a v4-only hotel network), then try:

```bash
# Direct IP — Home Assistant
curl http://10.10.0.20:8123

# .lan domain — Sonarr (via Traefik on the NAS)
curl http://sonarr.lan
```

Both should respond exactly as they do on home WiFi.

## Troubleshooting

**`docker logs tailscale` shows no login URL.**
The container may have re-used existing state. Force a fresh login:
```bash
docker exec tailscale tailscale logout
docker exec tailscale tailscale up --advertise-routes=10.10.0.0/24 --accept-routes
```
The URL prints to that command's output.

**Peer can ping the NAS (10.10.0.10) but not other LAN devices (10.10.0.20 etc).**
The subnet route isn't approved. Re-check step 3a — until you tick the route box in the admin console and save, only the Tailscale node itself is reachable.

**`*.lan` doesn't resolve when remote.**
Split DNS isn't configured. Re-check step 3c. Verify on the client:
```bash
# macOS
scutil --dns | grep -A2 'domain.*lan'
```
You should see a resolver with nameserver `10.10.0.10` scoped to domain `lan`.

**Healthcheck failing in `docker ps`.**
Normal until you complete the interactive auth in step 2. Once authenticated, the next healthcheck interval (30s) should flip to healthy.

**Connection works on cellular but not on a specific hotel/corporate WiFi.**
Some networks block all outbound UDP. Tailscale automatically falls back to DERP relay over TCP/443; just confirm in the admin console *Machines* view — the node may show "(via DERP)" instead of "direct".

---

## ✅ + Tailscale Complete!

Your tailnet now exposes the LAN privately to any device you've authorised. Add new devices via the admin console; revoke them the same way.

Issues? [Report on GitHub](https://github.com/Pharkie/ultimate-arr-stack/issues).
