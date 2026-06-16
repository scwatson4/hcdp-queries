# Query: Post-reboot stack verification (shell-only, no GUI)

**Date:** 2026-06-16 10:30 UTC
**Context:** instance was rebooted; web desktop no longer relied upon. Verified from the
shell. Authorized fix: restart `qgis-mcp.service` only. Did **not** touch raster service,
firewall, or Postgres. Branch stayed `claude/integrate-pipeline-codex-OMPo2` (only the
healthcheck script pulled into the working tree).

---

## Healthcheck ✓/✗ (after restarting qgis-mcp)

| | Check |
|---|---|
| ✓ | VNC X server `:1` running (came up on its own after reboot) |
| ✓ | `qgis-mcp.service` active |
| ✓ | QGIS MCP socket `9876` listening (loopback) |
| ✓ | QGIS plugin socket accepts connections |
| ✓ | raster service healthy (`http://127.0.0.1:8000/health`) |
| ! | linger OFF — this is why qgis-mcp didn't auto-survive the reboot |

**RESULT: all critical checks passed.**

### Fix applied
Post-reboot, qgis-mcp was down (socket/ping failing) but VNC `:1` was already running, so per
the runbook I restarted **only** `systemctl --user restart qgis-mcp.service`, waited ~10 s,
and re-ran the check — it recovered fully (socket up in ~3 s). VNC was not started (already
up); nothing else touched.

## Postgres: DOWN — not touched (per instruction)

`pg_isready` → `no response`. Root cause (read-only diagnosis):

- The real cluster unit **`postgresql@16-main` is in `failed` state**. The `postgresql`
  meta-unit shows "active" but that's just a wrapper — no postgres backend process exists.
- Boot log:
  ```
  Error: /media/volume/hcdp_postgres_db/postgresql/16/main is not accessible or does not exist
  postgresql@16-main.service: Failed with result 'protocol'.
  ```
- **Boot-ordering race:** the data volume `/media/volume/hcdp_postgres_db` is mounted with
  `x-systemd.device-timeout=1s`, so Postgres tried to start before the volume finished
  mounting and bailed. The volume **is mounted now** (`/dev/sdc` → `/media/volume/hcdp_postgres_db`,
  ext4; data dir present, root-owned), so the cluster just needs to be (re)started.

### Recommended (operator action — not performed here)
```
sudo systemctl start postgresql@16-main      # or: sudo pg_ctlcluster 16 main start
```
Prevent recurrence with a mount dependency on the cluster unit:
```
# /etc/systemd/system/postgresql@16-main.service.d/wait-for-volume.conf
[Unit]
RequiresMountsFor=/media/volume/hcdp_postgres_db
```

## Worth flagging

The "raster service healthy" ✓ is a **static liveness check** — it does not prove DB access.
With Postgres down, any MCP/raster/table operation that queries the database will fail until
the cluster is started. The stack is *serving* but the *data layer is offline*.

## Not touched
Raster service, firewall, Postgres, VNC server. (Linger remains OFF — enabling
`loginctl enable-linger exouser` would let qgis-mcp auto-start after future reboots, but that
was out of scope here.)
