# Query: QGIS install on hcdp-postgres-db — Phase 1a dry-run gate

**Date:** 2026-06-15 00:30 UTC
**Mode:** dry-run only. QGIS repo added, `apt-get update` executed, `apt-get install -s qgis python3-qgis` simulated. **No packages installed.** No services touched. Stopping at the Phase-1 gate per the plan.

---

## Headline

```
0 upgraded, 157 newly installed, 0 to remove and 65 not upgraded.
```

Every package this install pulls is **new** — nothing on the system is replaced. The 65 "not upgraded" line refers to pending Ubuntu noble updates that are unrelated to QGIS (queued from earlier `apt update`s, not selected for the QGIS install transaction).

## (a) Specifically asked: gdal / proj / libqt* upgrade analysis

### Nothing currently installed gets upgraded by this install

| Package | Currently installed | Dry-run action |
|---|---|---|
| `libgdal34t64` | 3.8.4+dfsg-3ubuntu3 | **unchanged** (not in install list) |
| `gdal-data` | 3.8.4+dfsg-3ubuntu3 | **unchanged** |
| `libproj25` | 9.4.0-1build2 | **unchanged** |
| `proj-data` | 9.4.0-1build2 | **unchanged** |
| `libqt5core5t64` | not installed | **new** |
| `libqt6core6t64` | not installed | not pulled (QGIS 3.44 is Qt5) |

The dry-run produced **zero** lines matching the upgrade pattern (`Inst pkg [oldver] (newver …)`). All 157 `Inst` lines are new installs (`Inst pkg (newver Ubuntu:24.04/noble [amd64])` with the `[amd64]` being the architecture marker, not an old-version bracket).

### New packages flagged for visibility (counts by category)

| Category | New packages | Source |
|---|---|---|
| Qt5 stack (libqt5-*, qt5-*, libqt53d*) | **62** | Ubuntu noble (`libqt5core5t64` 5.15.13, plus `libqt5gui5t64`, `libqt5widgets5t64`, full Qt5 graphics + Qt3D + WebKit + WebChannel + Designer + Help) |
| QGIS itself | **13** | QGIS repo (`1:3.44.7+40noble`): `qgis`, `qgis-common`, `qgis-providers`, `qgis-providers-common`, `qgis-plugin-grass`, `qgis-plugin-grass-common`, `qgis-provider-grass`, `libqgis-core3.44.7`, `libqgis-analysis`, `libqgis-native`, `libqgis-gui`, `libqgis-3d`, `libqgis-app`, `libqgis-server`, `libqgisgrass8`, `libqgispython`, `libqgis-customwidgets`, `python3-qgis`, `python3-qgis-common` |
| GDAL/PROJ/spatial | **24** | Ubuntu noble: `gdal-bin` (3.8.4), `python3-gdal` (3.8.4), `python3-pyproj` (3.6.1), `libsqlite3-mod-spatialite` (5.1.0), `libspatialindex6`, `libgeos*` already on host, plus `grass-core`/`grass-doc` (8.3.2) |
| Python ecosystem | **45** | Ubuntu noble: `python3-numpy` (1.26.4), `python3-matplotlib` (3.6.3), `python3-scipy` (1.11.4), `python3-lxml`, `python3-bs4`, `python3-owslib`, `python3-plotly`, `python3-psycopg2`, `python3-pyqt5*`, `python3-jupyter-core`, `python3-fonttools`, etc. |

Notably **no qt6** is pulled (QGIS 3.44 is still a Qt5 codebase). The `qt6-` series in the prompt's flag list isn't applicable to this install.

`python3-gdal` and `python3-pyproj` from Ubuntu repos are pulled in as **dependencies of the system QGIS install**, but they go to the system `dist-packages` directory — they have **no path into either of the existing service venvs**, which sit on `/opt/hcdp/raster_service/.venv` and `/opt/hcdp/venv` and were built with `python -m venv` (no `--system-site-packages`). The venvs already have their own `numpy`, `matplotlib`, `psycopg2-binary`, etc., wheel-installed and pinned in `requirements.txt`.

## (b) Specifically asked: raster service + FastMCP — system GDAL or wheel-bundled?

**Both venvs use wheel-bundled GDAL/PROJ/GEOS, confirmed end-to-end.**

### `ldd` on `rasterio/_io.so` (the C extension that actually opens rasters)

Both `/opt/hcdp/raster_service/.venv` and `/opt/hcdp/venv` resolve identically:

```
libgdal-95b3f1c5.so.38.3.12.1  →  …/rasterio.libs/libgdal-95b3f1c5.so.38.3.12.1
libtiff-fcdb3d8f.so.6.2.0      →  …/rasterio.libs/libtiff-fcdb3d8f.so.6.2.0
libsqlite3-27e0bcf3.so.3.51.1  →  …/rasterio.libs/libsqlite3-27e0bcf3.so.3.51.1
libgeos_c-23da760b.so.1.20.5   →  …/rasterio.libs/libgeos_c-23da760b.so.1.20.5
libproj-4d6f3841.so.25.9.7.1   →  …/rasterio.libs/libproj-4d6f3841.so.25.9.7.1
libgeos-1269e1bd.so.3.14.1     →  …/rasterio.libs/libgeos-1269e1bd.so.3.14.1
```

The `rasterio.libs/` directory next to the `rasterio/` package is exactly the auditwheel-repaired bundle that the manylinux wheel ships. The `_io.so` was linked with an `$ORIGIN`-relative rpath, so the dynamic linker finds the bundled libs **before** ever looking in `/usr/lib`.

### Runtime confirmation (matters more than ldd — proves what's actually loaded)

A live Python process inside `raster_service/.venv` reports:

```
rasterio.__gdal_version__ = 3.12.1     ← bundled (system is 3.8.4)

/proc/<pid>/maps mapped libs:
  …/rasterio.libs/libgdal-95b3f1c5.so.38.3.12.1
  …/rasterio.libs/libgeos-1269e1bd.so.3.14.1
  …/rasterio.libs/libgeos_c-23da760b.so.1.20.5
  …/rasterio.libs/libproj-4d6f3841.so.25.9.7.1
```

No `/usr/lib/x86_64-linux-gnu/libgdal*` or `/usr/lib/.../libproj*` is mapped. The version delta (bundled 3.12.1 vs system 3.8.4) makes the conclusion unmistakable: the running service is wired to its own bundled GDAL.

### What the FastMCP servers actually run on

Per the systemd snapshot from prior sessions, all three FastMCP servers are launched with:

```
command = "/opt/hcdp/raster_service/.venv/bin/python3"
args    = ["/opt/hcdp/mcp/<server>.py"]
```

Same interpreter → same wheel-bundled GDAL story applies. The MCP servers are subject to the identical dlopen path as the raster service.

### Conclusion preview for Phase 1e regression check

A QGIS install will pull a system Qt5 stack + a system gdal-bin (3.8.4) + system python3-gdal — none of which sit on the venv's import path or LD search path. The existing services should be **bit-identical** before and after install. The regression check in Phase 1e is still worth running, but I expect:

- `/health` on the raster service: 200 with same JSON
- Postgres still up (this install touches nothing in `/etc/postgresql` or systemd)
- `import hcdp_raster_mcp_server` from the service venv: clean, same versions
- All 3 FastMCP servers' tool registries: same names, same count

If anything diverges, the most likely culprit would be a side effect of QGIS pulling `python3-numpy` into `dist-packages` colliding with `PYTHONPATH` — but neither venv has `dist-packages` in `sys.path` (verified by `python3 -c 'import sys; print(sys.path)'` returning only the venv's `site-packages` and stdlib). So even that should be benign.

## QGIS apt repo details (so we don't have to re-do this if we roll back)

```
/etc/apt/keyrings/qgis-archive-keyring.gpg   ← QGIS Archive Automatic Signing Key (2022-2027)
                                                fingerprint 2D7E3441A707FDB3E7059441D155B8E6A419C5BE
                                                User ID: QGIS Archive Automatic Signing Key
                                                         <qgis-developer@lists.osgeo.org>

/etc/apt/sources.list.d/qgis.sources         ← deb822 format:
   Types: deb
   URIs: https://qgis.org/ubuntu
   Suites: noble
   Architectures: amd64
   Components: main
   Signed-By: /etc/apt/keyrings/qgis-archive-keyring.gpg
```

After `apt-get update`, line 35 was: `https://nbg1.your-objectstorage.com/qgis-download/debian noble/main amd64 Packages [161 kB]` (qgis.org redirects to their Hetzner object-storage backend; this is documented and expected).

Candidate version offered: **QGIS 3.44.7+40noble** ("Solothurn", current stable).

## Phase 1a state on disk (delta vs. snapshot)

| Path | Change | Restorable from snapshot? |
|---|---|---|
| `/etc/apt/keyrings/qgis-archive-keyring.gpg` | created (1775 B) | yes — `rm` |
| `/etc/apt/sources.list.d/qgis.sources` | created (155 B) | yes — `rm` |
| `/var/lib/apt/lists/*` | refreshed (added QGIS pkg list, ~161 KB) | regenerable via `apt-get update` |
| **Nothing else** | — | — |

No packages installed, no services restarted, no /opt directory modified, no Postgres connection made, no config files touched outside apt's metadata.

## Stop point

Stopping here per the phase contract. Awaiting your go for Phase 1b (the actual `apt-get install qgis python3-qgis`, which will install all 157 packages from above and consume ~1.5–2 GB on `/`). Phase 1c–1e (`qgis --version` under headless, Python `import qgis.core`, regression check on the running services) follow automatically once 1b succeeds, but I'll still STOP at the end of 1e before Phase 2.
