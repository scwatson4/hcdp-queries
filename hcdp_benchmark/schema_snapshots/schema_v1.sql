--
-- PostgreSQL database dump
--

\restrict EzdhQCCslUtTxbLMdQdyuzi2GmqroEMlAFghQNxyfHixnbnlLMrZdjkgbYI03pC

-- Dumped from database version 16.13 (Ubuntu 16.13-1.pgdg24.04+1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: historical_station_values; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historical_station_values (
    station_id text,
    date date,
    datatype text,
    period text,
    fill text,
    production text,
    aggregation text,
    value double precision,
    raw_data jsonb
);


ALTER TABLE public.historical_station_values OWNER TO postgres;

--
-- Name: ingestion_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ingestion_log (
    id integer NOT NULL,
    job_type text,
    started_at timestamp with time zone DEFAULT now(),
    finished_at timestamp with time zone,
    records_fetched integer DEFAULT 0,
    records_upserted integer DEFAULT 0,
    status text DEFAULT 'running'::text,
    error_message text,
    details jsonb
);


ALTER TABLE public.ingestion_log OWNER TO postgres;

--
-- Name: ingestion_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ingestion_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ingestion_log_id_seq OWNER TO postgres;

--
-- Name: ingestion_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ingestion_log_id_seq OWNED BY public.ingestion_log.id;


--
-- Name: mesonet_measurements; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mesonet_measurements (
    station_id text,
    var_id text,
    "timestamp" timestamp with time zone,
    value double precision,
    flag text
);


ALTER TABLE public.mesonet_measurements OWNER TO postgres;

--
-- Name: mesonet_stations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mesonet_stations (
    station_id text NOT NULL,
    name text,
    lat double precision,
    lng double precision,
    elevation_m double precision,
    island text,
    location text DEFAULT 'hawaii'::text,
    raw_metadata jsonb,
    geom public.geometry(Point,4326),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.mesonet_stations OWNER TO postgres;

--
-- Name: mesonet_variables; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mesonet_variables (
    var_id text NOT NULL,
    description text,
    units text,
    interval_s integer,
    raw_metadata jsonb
);


ALTER TABLE public.mesonet_variables OWNER TO postgres;

--
-- Name: mv_daily_station_summary; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW public.mv_daily_station_summary AS
 SELECT m.station_id,
    s.name AS station_name,
    s.island,
    date((m."timestamp" AT TIME ZONE 'Pacific/Honolulu'::text)) AS date_hst,
    min(
        CASE
            WHEN (m.var_id ~~ 'Tair%'::text) THEN m.value
            ELSE NULL::double precision
        END) AS tair_min,
    max(
        CASE
            WHEN (m.var_id ~~ 'Tair%'::text) THEN m.value
            ELSE NULL::double precision
        END) AS tair_max,
    avg(
        CASE
            WHEN (m.var_id ~~ 'Tair%'::text) THEN m.value
            ELSE NULL::double precision
        END) AS tair_avg,
    sum(
        CASE
            WHEN (m.var_id = 'RF_1_Tot300s'::text) THEN m.value
            ELSE NULL::double precision
        END) AS rainfall_mm,
    avg(
        CASE
            WHEN (m.var_id ~~ 'RH%Avg%'::text) THEN m.value
            ELSE NULL::double precision
        END) AS rh_avg,
    avg(
        CASE
            WHEN (m.var_id ~~ 'WS%Avg%'::text) THEN m.value
            ELSE NULL::double precision
        END) AS wind_speed_avg,
    max(
        CASE
            WHEN ((m.var_id ~~ 'WS%Max%'::text) OR (m.var_id ~~ 'WS%'::text)) THEN m.value
            ELSE NULL::double precision
        END) AS wind_speed_max,
    avg(
        CASE
            WHEN (m.var_id ~~ 'SRad%'::text) THEN m.value
            ELSE NULL::double precision
        END) AS solar_rad_avg,
    avg(
        CASE
            WHEN ((m.var_id ~~ 'SM%'::text) OR (m.var_id ~~ 'SWC%'::text)) THEN m.value
            ELSE NULL::double precision
        END) AS soil_moisture_avg
   FROM (public.mesonet_measurements m
     JOIN public.mesonet_stations s ON ((m.station_id = s.station_id)))
  GROUP BY m.station_id, s.name, s.island, (date((m."timestamp" AT TIME ZONE 'Pacific/Honolulu'::text)))
  WITH NO DATA;


ALTER MATERIALIZED VIEW public.mv_daily_station_summary OWNER TO postgres;

--
-- Name: mv_monthly_station_summary; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW public.mv_monthly_station_summary AS
 SELECT station_id,
    station_name,
    island,
    (date_trunc('month'::text, (date_hst)::timestamp with time zone))::date AS month,
    min(tair_min) AS tair_min,
    max(tair_max) AS tair_max,
    avg(tair_avg) AS tair_avg,
    sum(rainfall_mm) AS rainfall_mm,
    avg(rh_avg) AS rh_avg,
    avg(wind_speed_avg) AS wind_speed_avg,
    max(wind_speed_max) AS wind_speed_max,
    avg(solar_rad_avg) AS solar_rad_avg,
    avg(soil_moisture_avg) AS soil_moisture_avg
   FROM public.mv_daily_station_summary
  GROUP BY station_id, station_name, island, ((date_trunc('month'::text, (date_hst)::timestamp with time zone))::date)
  WITH NO DATA;


ALTER MATERIALIZED VIEW public.mv_monthly_station_summary OWNER TO postgres;

--
-- Name: station_monitor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.station_monitor (
    station_id text NOT NULL,
    data jsonb,
    fetched_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.station_monitor OWNER TO postgres;

--
-- Name: ingestion_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_log ALTER COLUMN id SET DEFAULT nextval('public.ingestion_log_id_seq'::regclass);


--
-- Name: ingestion_log ingestion_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_log
    ADD CONSTRAINT ingestion_log_pkey PRIMARY KEY (id);


--
-- Name: mesonet_stations mesonet_stations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mesonet_stations
    ADD CONSTRAINT mesonet_stations_pkey PRIMARY KEY (station_id);


--
-- Name: mesonet_variables mesonet_variables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mesonet_variables
    ADD CONSTRAINT mesonet_variables_pkey PRIMARY KEY (var_id);


--
-- Name: station_monitor station_monitor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.station_monitor
    ADD CONSTRAINT station_monitor_pkey PRIMARY KEY (station_id);


--
-- Name: idx_hist_upsert; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_hist_upsert ON public.historical_station_values USING btree (station_id, date, datatype, period, COALESCE(production, ''::text), COALESCE(aggregation, ''::text));


--
-- Name: idx_meas_station_ts; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_meas_station_ts ON public.mesonet_measurements USING btree (station_id, "timestamp" DESC);


--
-- Name: idx_meas_upsert; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_meas_upsert ON public.mesonet_measurements USING btree (station_id, var_id, "timestamp");


--
-- Name: idx_meas_var_station_ts; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_meas_var_station_ts ON public.mesonet_measurements USING btree (var_id, station_id, "timestamp" DESC);


--
-- Name: idx_mv_daily; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_mv_daily ON public.mv_daily_station_summary USING btree (station_id, date_hst);


--
-- Name: idx_mv_monthly; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_mv_monthly ON public.mv_monthly_station_summary USING btree (station_id, month);


--
-- Name: idx_stations_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_stations_geom ON public.mesonet_stations USING gist (geom);


--
-- PostgreSQL database dump complete
--

\unrestrict EzdhQCCslUtTxbLMdQdyuzi2GmqroEMlAFghQNxyfHixnbnlLMrZdjkgbYI03pC

