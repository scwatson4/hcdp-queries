# Query: Fix post-reboot startup gaps (Postgres + reboot-proofing + linger)

**Date:** 2026-06-16 10:45 UTC
**Scope:** authorized three fixes, then verified. Did not change firewall, raster service,
or VNC. Branch unchanged (`claude/integrate-pipeline-codex-OMPo2`).

---

## 1. Postgres started ✅

```
sudo systemctl start postgresql@16-main      # is-active: active
pg_isready -h 127.0.0.1 -p 5432              # accepting connections
pg_isready                                    # /var/run/postgresql:5432 - accepting connections
sudo -u postgres psql -d hcdp -c "select 1;" # -> 1 row
```

The boot-time failure was a race: `postgresql@16-main` started before the data volume
`/media/volume/hcdp_postgres_db` finished mounting (`x-systemd.device-timeout=1s`). The
volume was already mounted by the time of this fix, so the cluster started cleanly.

## 2. Reboot-proofed ✅

Created `/etc/systemd/system/postgresql@16-main.service.d/wait-for-volume.conf`:

```ini
[Unit]
RequiresMountsFor=/media/volume/hcdp_postgres_db
```

`sudo systemctl daemon-reload`. Confirmed picked up — the unit's effective
`RequiresMountsFor` now lists `/media/volume/hcdp_postgres_db`, so on the next reboot the
cluster waits for the volume mount before starting (no more start-before-mount race). Postgres
stayed active through the reload (reload ≠ restart).

## 3. Linger + service enabled ✅

```
loginctl enable-linger exouser               # Linger=yes
systemctl --user enable qgis-mcp.service     # created default.target.wants symlink
```

Note: linger alone wasn't enough — the qgis-mcp user service was `disabled`, so it would not
have auto-started even with the user manager kept alive. Enabling the service (it has
`WantedBy=default.target`) is what actually makes qgis-mcp come up on reboot. Both now in
place: `is-enabled: enabled`, `is-active: active`.

## Verification

### Healthcheck — all green
```
✓ VNC X server :1 running
✓ qgis-mcp.service active
✓ QGIS MCP socket 9876 listening (loopback)
✓ QGIS plugin socket accepts connections
✓ raster service healthy (http://127.0.0.1:8000/health)
✓ linger enabled — services survive logout/reboot
RESULT: all critical checks passed — the stack is ready.
```

### Postgres status
Up, accepting connections on both the TCP (127.0.0.1:5432) and unix sockets; `select 1`
returns. Cluster unit `postgresql@16-main` = active.

### Ingest is advancing
- `max(date_hst)` in `mv_daily_station_summary_qc` = **2026-06-15** (the daily matview caps at
  the last complete day — normal; today's row materializes after the day closes).
- Raw mesonet `max(timestamp)` advanced after Postgres came back: the **10:45 UTC** cron tick
  (`ingestion_log` id 7620, status `success`) pulled data to **2026-06-16 10:40 UTC**, lag
  back to **~7 min** (normal for the 15-min cron).
- Only the single **10:30** tick was missed (it fell inside the Postgres-down window between
  the 10:23 reboot and this fix) — visible as the gap between runs 7619 (10:15) and 7620 (10:45).
  Cadence has resumed cleanly.

## Result

Postgres: **UP** and ingesting. Latest ingest timestamp: **2026-06-16 10:40 UTC** (and
advancing on the normal 15-min cadence). All three startup gaps fixed and reboot-proofed.
Not touched: firewall, raster service, VNC.
