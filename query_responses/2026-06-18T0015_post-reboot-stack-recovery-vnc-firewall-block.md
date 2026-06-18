# Query: Post-reboot stack recovery (dependency order) + confirm web desktop will open

**Date:** 2026-06-18 00:15 UTC
**Scope:** brought the HCDP stack up in dependency order after a reboot, verified each layer,
and ran the decisive Guacamole↔VNC reachability test. Did not touch the firewall, security
groups, ufw, sshd, raster service, or any data — read-only beyond the one authorized Postgres
start. Stopped at the firewall boundary per guardrail.

---

## Status table (state after reboot → action → state now)

| Component | After reboot | Action taken | State now |
|---|---|---|---|
| Data volume | Mounted at subdirs (`/dev/sdc` → `…/hcdp_postgres_db`, `/dev/sdb` → `…/hcdp_postgres_db_2`) | none — `/media/volume` itself is not a mountpoint by design; the data disks are mounted under it | mounted; 46G free on data, 40G on root |
| Postgres | **failed** (`Result: protocol`, boot race @ 22:49) | `sudo systemctl start postgresql@16-main` | active; `select 1;` on `hcdp` returns |
| Linger | `yes` (already enabled) | none | yes |
| VNC :1 | **running** (Xvnc pid 2030 on `0.0.0.0:5901`) | none — up via its own mechanism; `vncserver@:1` unit is disabled/dead but irrelevant | running, 5901 listening |
| guacd | up (Docker `…guacd-1`, healthy) | none | healthy (4822 container-internal) |
| Guacamole web | up (Docker `…guacamole-1`, `49528→8080`) | none | up |
| qgis-mcp | active (linger held it across reboot) | none | active, socket `127.0.0.1:9876` |
| Raster service | healthy | none | `/health` → 200 |

`instance_healthcheck.sh`: **all critical checks passed.**
Note: the `watchtower` container (image auto-updater, unrelated to the desktop) is `Exited (1)` — harmless.

## Verdict: desktop will NOT open yet — VNC layer is the block, but **not because VNC is down**

VNC `:1` is up and listening on `0.0.0.0:5901`. The decisive test — `nc` from **inside the guacd
container** to its configured VNC target `172.17.0.1:5901` — **fails**, while the **same probe to
host SSH `:22` succeeds** (and the host is pingable from the container). The only difference is the
host firewall:

- ufw is **active**, INPUT policy **DROP**.
- ufw allow-list is exactly `22/tcp, 5432/tcp, 8000/tcp` (v4 + v6). **5901 is not allowed.**
- No allow for `5901` or the docker bridge subnets anywhere in `ufw-user-input`.

So guacd's connection from the docker bridge (`172.18.0.2`) to the host's `5901` is silently
dropped at INPUT. SSH works from the same container because `22` is explicitly allowed; VNC does
not because `5901` is not. Identical network path — the firewall allow-list is the sole difference.

This is almost certainly the same "web desktop won't open" seen previously; it was never fixed at
the firewall layer, which is why the workflow fell back to shell-only.

## Topology that matters

- guacd container: `172.18.0.2`, gateway `172.18.0.1`, on `guacamole_exo-guac-net` (no interface on `172.17.x`).
- Guacamole connection config (`/config/user-mapping.xml`) targets VNC at **`172.17.0.1:5901`** (the default docker bridge gateway = host).
- VNC binds `0.0.0.0:5901`, so it is served on every host interface — reachability is purely a firewall-allow question, not a bind question.

## What's still down + the command to run (NOT run — firewall is off-limits per guardrail)

Scoped fix — allows only the guac docker bridge, keeps VNC off the public internet:

```
sudo ufw allow from 172.18.0.0/16 to any port 5901 proto tcp
```

If it still won't connect after that, also allow `172.17.0.0/16` (the host name the connection
config uses). A blanket `ufw allow 5901` is **not** recommended — it would expose VNC to the
public internet.

## Result

Stack is up and healthy at every layer I'm authorized to touch (Postgres recovered from the boot
race; everything else survived via linger + Docker). The single remaining blocker to the web
desktop is a host-firewall allow gap for port 5901 from the guac docker subnet — left for
authorization since it touches ufw.
