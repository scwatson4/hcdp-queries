# Query: Web desktop (Guacamole) not opening — diagnose

**Date:** 2026-06-16 09:45 UTC
**Mode:** read-only diagnosis. No services, configs, VNC, firewall, or security groups changed.

---

## Verdict

The web-desktop stack is **healthy on the server side**. The problem is almost certainly a
**changed public IP / wrong URL**, not a broken service.

## What was verified (no changes made)

| Check | Result |
|---|---|
| `guacamole-exo-guac-guacamole-1` container | **Up 3 weeks** |
| `guacamole-exo-guac-guacd-1` container | **Up (healthy)** |
| Port `49528` | listening on `0.0.0.0` (docker-proxy) |
| `http://127.0.0.1:49528/guacamole/` | **HTTP 200** — serves the real login page (`guac-login`, Angular) |
| `http://127.0.0.1:49528/guacamole/api/languages` | HTTP 200 |
| `http://127.0.0.1:49528/` (bare root) | HTTP 404 (normal — app lives under `/guacamole/`) |
| VNC `:1` (Xvnc, the streamed desktop) | running, `5901` listening |
| `guacamole-exo-watchtower-1` | `Exited (1)` — auto-updater only, irrelevant to the desktop |

## Likely cause: the instance's public IP rotated

- **Current public/floating IP: `149.165.151.99`** (confirmed via OpenStack metadata and external egress check — both agree).
- Previously documented IP was `149.165.155.217` (vendored `INTEGRATION.md` / the Jetstream2 IP-rotation runbook note). Jetstream2 floating IPs can change, so a bookmark to the old IP simply fails to connect.

## What to try

1. **Use the current URL — mind the path:**
   `http://149.165.151.99:49528/guacamole/`
   (Bare `http://149.165.151.99:49528/` returns 404; it must end in `/guacamole/`.)
2. If normally opened via the **Exosphere web dashboard** ("Web Desktop" button on the
   instance), use that — it tracks the instance's current IP automatically, so it's the most
   reliable path after an IP change.

## If it still won't open with the correct IP/URL

That points to the **OpenStack security group** not allowing inbound TCP `49528` from your
network — the host is listening fine; the cloud firewall is a separate layer. No
firewall/security-group rule was changed here (out of scope + console action on the operator
side). Next read-only step if needed: inspect the Guacamole container logs for inbound
connection attempts to distinguish "never reaching the host" from "reaching but rejected."
