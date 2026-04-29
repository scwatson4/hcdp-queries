# Database Connection

## Local access

```bash
# Interactive SQL
sudo -u postgres psql -d hcdp

# Single query
sudo -u postgres psql -d hcdp -c "SELECT COUNT(*) FROM mesonet_measurements;"

# Export to CSV
sudo -u postgres psql -d hcdp -c "\copy (SELECT ...) TO STDOUT WITH CSV HEADER" > output.csv
```

## Connection parameters

```
Host:     localhost (or /var/run/postgresql for Unix socket)
Port:     5432
Database: hcdp
User:     postgres
Auth:     peer (local Unix socket, no password needed with sudo -u postgres)
```

## For programmatic access (Python, etc.)

Set the environment variable:
```bash
export HCDP_PG_DSN="postgresql://postgres@/hcdp"
```

Or source from the ingestion config:
```bash
source /opt/hcdp/.env
# Uses $HCDP_DB_URI
```

## Data directory

PostgreSQL data is stored on an attached volume:
```
/media/volume/hcdp_postgres_db
```

Current usage: ~190 GB of 250 GB (78%). The mesonet_measurements table (66 GB) plus indexes (121 GB) dominate.

## Ingestion pipeline

- **Location**: `/opt/hcdp/ingest.py`
- **Cron**: runs `--update` every 15 minutes
- **Config**: `/opt/hcdp/.env` (API token, DB URI)
- **Logs**: `ingestion_log` table in the database

## HCDP API (source)

If you need data not in the database, the HCDP API is available:
```bash
source /opt/hcdp/.env
curl -s -H "Authorization: Bearer $HCDP_API_TOKEN" \
  "https://api.hcdp.ikewai.org/mesonet/db/measurements?location=hawaii&station_ids=0501&var_ids=Tair_1_Avg&start_date=2026-01-01T00:00:00-10:00&end_date=2026-01-01T23:59:59-10:00&row_mode=json&local_tz=true&limit=5"
```

API spec: `/opt/hcdp/hcdp_api.yaml`
