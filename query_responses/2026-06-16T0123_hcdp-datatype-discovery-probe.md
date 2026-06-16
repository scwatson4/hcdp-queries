# Query: HCDP datatype discovery probe (read-only GET reconnaissance)

**Date:** 2026-06-16 01:23 UTC
**Mode:** GET-only. No changes to any service, config, qgis-mcp, or the HCDP API. The
probe script (`services/jetstream2/probe_datatypes.py`) was pulled from the `qgis-glue`
branch into the working tree only — deployment stayed on
`claude/integrate-pipeline-codex-OMPo2`. Token never printed; absent from the JSON report.

Run: `/opt/hcdp/venv/bin/python3` (requests 2.33.1 + rasterio 1.5.0 → rasterio value
engine). 119 requests, exit 0. **Rainfall self-test returned a working shape**, confirming
the probe + token/env are valid. All 5 datatypes resolved — no "NO WORKING SHAPE FOUND".

---

## HCDP datatype probe (https://api.hcdp.ikewai.org) — 119 requests

### relative_humidity
- working params: `{'period': 'day'}`
- extents OK: statewide, bi, ka, oa, mn
- coverage: ~2005–2025 (latest available: 2026-05-15)
- CRS: EPSG:4326  res(deg): [0.00225, 0.00225]  dtype: float32  band_units: None
- values: min=65.7803 p02=69.373 mean=78.115 p98=88.9794 max=97.5353 (287117 land px)

### ndvi_modis
- working params: `{'period': 'day'}`
- extents OK: statewide, bi, ka, oa, mn
- coverage: ~2000–2025 (latest available: 2026-05-15)
- CRS: EPSG:4326  res(deg): [0.00225, 0.00225]  dtype: float32  band_units: None
- values: min=-0.2709 p02=0.0278 mean=0.4245 p98=0.7589 max=0.9222 (287983 land px)

### ignition_probability
- working params: `{'period': 'day'}`
- extents OK: statewide, bi, ka, oa, mn
- coverage: ~2005–2025 (latest available: 2026-05-15)
- CRS: EPSG:4326  res(deg): [0.00225, 0.00225]  dtype: float32  band_units: None
- values: min=-0.0 p02=0.01 mean=0.2501 p98=0.69 max=0.94 (281166 land px)

### spi
- working params: `{'period': 'month', 'timescale': 'timescale003'}`
- extents OK: statewide
- coverage: ~1990–2025 (latest available: 2026-05)
- CRS: EPSG:4326  res(deg): [0.00225, 0.00225]  dtype: float32  band_units: None
- values: min=-0.4313 p02=0.2832 mean=2.1773 p98=3.09 max=3.09 (287983 land px)

### rainfall
- working params: `{'period': 'month', 'production': 'new'}`
- extents OK: statewide, bi, ka, oa, mn
- coverage: ~1990–2025 (latest available: 2026-05)
- CRS: EPSG:4326  res(deg): [0.00225, 0.00225]  dtype: float32  band_units: None
- values: min=0.0304 p02=6.0373 mean=154.5794 p98=630.1166 max=1213.4332 (287983 land px)

Full JSON: `/tmp/hcdp_datatype_probe.json` (9.3 KB)

---

## Observations worth flagging (not errors)

- **`spi` only returns `statewide`** — unlike the other four datatypes, it had no per-island
  (bi/ka/oa/mn) extents in this probe. Relevant if island-level SPI is needed.
- **`spi` value range is one-sided** (p02=0.28, max capped at 3.09). SPI is normally ~±3
  centered near 0; this sampled month/timescale (`timescale003`, 3-month) skews positive
  (wet). Likely just the sampled date, but distinct from a typical SPI spread.
- **Parameter shapes differ by datatype** — the three daily gridded products
  (relative_humidity, ndvi_modis, ignition_probability) use `{period: day}`; `spi` needs
  `{period: month, timescale: timescale003}`; rainfall uses `{period: month, production: new}`.
- All products share the same grid: **EPSG:4326, ~0.00225° (~250 m), float32**, ~288k land
  pixels statewide.

## Reproduce

```bash
cd /opt/hcdp/src
git fetch origin qgis-glue
git checkout origin/qgis-glue -- services/jetstream2/probe_datatypes.py
set -a; source /opt/hcdp/.env; set +a       # sets HCDP_API_TOKEN / HCDP_API_BASE (not printed)
/opt/hcdp/venv/bin/python3 services/jetstream2/probe_datatypes.py
```
