-- Fact table: 311 service requests for idling and double parking
-- Grain: one row per service request (request_id, deduplicated in staging)

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_subset') }}
),

-- All the dimensions in their own CTEs for easy reference
dim_date AS (
    SELECT * FROM {{ ref('dim_conformed_date') }}
),

dim_time AS (
    SELECT * FROM {{ ref('dim_time') }}
),

dim_address AS (
    SELECT * FROM {{ ref('dim_address') }}
),

dim_complaint_type AS (
    SELECT * FROM {{ ref('dim_complaint_types') }}
),

dim_agency AS (
    SELECT * FROM {{ ref('dim_agency') }}
),

dim_borough AS (
    SELECT * FROM {{ ref('dim_borough') }}
),

dim_resolution AS (
    SELECT * FROM {{ ref('dim_resolution') }}
),

fact_311_service_request AS (

    SELECT
        -- Fact's own surrogate key, from the grain (deduplicated in staging)
        {{ dbt_utils.generate_surrogate_key(['s.request_id']) }} AS service_request_key,

        -- Degenerate dimension (business identifier)
        s.request_id,

        -- Date and time keys
        -- Staging guarantees created_date: a NULL key here is a bug
        created_d.date_key AS created_date_key,
        COALESCE(created_t.time_key, '-1') AS created_time_key,
        -- Open requests have no closed date or time -> placeholder
        COALESCE(closed_d.date_key, '-1') AS closed_date_key,
        COALESCE(closed_t.time_key, '-1') AS closed_time_key,
        COALESCE(resolved_d.date_key, '-1') AS resolution_action_updated_date_key,

        -- Dimension keys
        COALESCE(a.address_key, '-1') AS address_key,
        -- No placeholder in dim_complaint_type: every request has one (extraction filter)
        ct.complaint_type_key,
        COALESCE(ag.agency_key, '-1') AS agency_key,
        COALESCE(b.borough_key, '-1') AS borough_key,
        COALESCE(r.resolution_key, '-1') AS resolution_key,

        -- Degenerate dimensions and attributes passed from staging
        s.status,
        s.method_of_submission,
        s.police_precinct,
        s.bbl,
        s.latitude,
        s.longitude,
        s.x_coordinate_state_plane,
        s.y_coordinate_state_plane,

        -- Calculated measures
        TIMESTAMP_DIFF(s.closed_date, s.created_date, HOUR) AS hours_to_close,
        TIMESTAMP_DIFF(s.closed_date, s.created_date, DAY) AS days_to_close

    FROM stg_311 s

    -- Left joins keep every staging row; JOIN ON the attributes that make up each dimension's surrogate key

    -- Dates (role-playing: same dimension joined three times)
    LEFT JOIN dim_date created_d
        ON CAST(s.created_date AS DATE) = created_d.full_date
    LEFT JOIN dim_date closed_d
        ON CAST(s.closed_date AS DATE) = closed_d.full_date
    LEFT JOIN dim_date resolved_d
        ON CAST(s.resolution_action_updated_date AS DATE) = resolved_d.full_date

    -- Times (truncated to the minute, same as dim_time)
    LEFT JOIN dim_time created_t
        ON  EXTRACT(HOUR FROM s.created_date) = created_t.hour
        AND EXTRACT(MINUTE FROM s.created_date) = created_t.minutes
    LEFT JOIN dim_time closed_t
        ON  EXTRACT(HOUR FROM s.closed_date) = closed_t.hour
        AND EXTRACT(MINUTE FROM s.closed_date) = closed_t.minutes

    -- Address: IS NOT DISTINCT FROM so NULL attributes still match the dimension row
    LEFT JOIN dim_address a
        ON  s.location_type IS NOT DISTINCT FROM a.location_type
        AND s.zip IS NOT DISTINCT FROM a.zip
        AND s.incident_address IS NOT DISTINCT FROM a.incident_address
        AND s.city IS NOT DISTINCT FROM a.city
        AND s.street_name IS NOT DISTINCT FROM a.street_name
        AND s.cross_street_1 IS NOT DISTINCT FROM a.cross_street_1
        AND s.cross_street_2 IS NOT DISTINCT FROM a.cross_street_2
        AND s.intersection_street_1 IS NOT DISTINCT FROM a.intersection_street_1
        AND s.intersection_street_2 IS NOT DISTINCT FROM a.intersection_street_2
        AND s.address_type IS NOT DISTINCT FROM a.address_type
        AND s.landmark IS NOT DISTINCT FROM a.landmark
        AND a.address_key != '-1'

    LEFT JOIN dim_complaint_type ct
        ON  s.complaint_type = ct.complaint_type
        AND s.descriptor = ct.descriptor

    LEFT JOIN dim_agency ag
        ON s.agency_name = ag.agency_name

    LEFT JOIN dim_borough b
        ON s.borough = b.borough

    LEFT JOIN dim_resolution r
        ON s.resolution_description = r.resolution_description

)

SELECT * FROM fact_311_service_request