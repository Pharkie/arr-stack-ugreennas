# Claude Code Instructions

## NAS Access

SSH credentials are in `.claude/config.local.md`. Read it before running any NAS commands.

## Project Structure

Docker media stack for Ugreen NAS. Edit NAS files (like `pihole/dnsmasq.d/02-local-dns.conf`) **on the NAS**, not locally.

- **Local dev repo**: `/Users/adamknowles/dev/ultimate-arr-stack/`
- **NAS deploy path**: `/volume1/docker/arr-stack/`

## Cross-Stack: Therapy Stack

A separate `therapy-stack` runs at `/volume1/docker/therapy-stack/` on its own network (`therapy-net`, 172.21.0.0/24). Baserow is also on the `arr-stack` network (static IP 172.20.0.20) so Traefik can route to it.

**Files referencing therapy-stack:** `pihole/dnsmasq.d/02-local-dns.conf`, `traefik/dynamic/therapy.local.yml`

**IMPORTANT:** Baserow's static IP (172.20.0.20) is critical. Without it, Docker can assign Gluetun's IP (172.20.0.3) to Baserow on reboot, breaking the VPN stack. The `ip_range: 172.20.0.128/25` in `docker-compose.traefik.yml` confines dynamic IPs to 128-255.

Therapy-stack local repo: `/Users/adamknowles/dev/n8n Therapybot/Git repo/`

## E2E Tests

Run `npm run test:e2e` after any change to Docker Compose files, service config, networks, or ports. All 13 tests must pass. They screenshot every service UI and verify API responses.
