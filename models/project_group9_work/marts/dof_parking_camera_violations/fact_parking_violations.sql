-- Fact table: parking and camera violations for idling and double parking
-- Grain: one row per summons (summons_number, deduplicated in staging)

WITH stg_parking_violations AS (
    SELECT * FROM {{ ref('stg_nyc_parking_camera_violations') }}
),

-- All the dimensions in their own CTEs for easy reference
dim_date AS (
    SELECT * FROM {{ ref('dim_conformed_date') }}
),

dim_time AS (
    SELECT * FROM {{ ref('dim_time') }}
),

dim_agency AS (
    SELECT * FROM {{ ref('dim_agency') }}
),

dim_borough AS (
    SELECT * FROM {{ ref('dim_borough') }}
),

dim_license_plate AS (
    SELECT * FROM {{ ref('dim_license_plate') }}
),

dim_violation AS (
    SELECT * FROM {{ ref('dim_violation') }}
),

fact_parking_camera_violations AS (

    SELECT
        -- Fact's own surrogate key, from the grain (deduplicated in staging)
        {{ dbt_utils.generate_surrogate_key(['s.summons_number']) }} AS parking_violation_key,

        -- Degenerate dimensions (business identifiers and high-cardinality attributes)
        s.summons_number,
        s.license_plate_number,
        s.violation_status,
        s.precinct,

        -- Date and time keys
        -- Staging filters out rows without a valid issue_date: a NULL key here is a bug
        issue_d.date_key AS issue_date_key,
        -- Unparseable or ambiguous times were set to NULL in staging -> placeholder
        COALESCE(t.time_key, '-1') AS violation_time_key,
        -- Most tickets have no judgment entry -> placeholder
        COALESCE(judgment_d.date_key, '-1') AS judgment_entry_date_key,

        -- Dimension keys (named to match each dimension's primary key)
        COALESCE(lp.license_plate_key, '-1') AS license_plate_key,
        -- No placeholder in dim_violation: every ticket has one (extraction filter)
        v.violation_key,
        COALESCE(b.borough_key, '-1') AS borough_key,
        COALESCE(ag.agency_key, '-1') AS agency_key,

        -- Measures (NUMERIC for exact currency values)
        s.fine_amount,
        s.penalty_amount,
        s.interest_amount,
        s.reduction_amount,
        s.payment_amount,
        s.amount_due,

        -- Calculated measure: days from ticket to judgment (NULL if no judgment)
        DATE_DIFF(s.judgment_entry_date, s.issue_date, DAY) AS days_to_judgment

    FROM stg_parking_violations s

    -- Left joins keep every staging row; JOIN ON the attributes that make up each dimension's surrogate key

    -- Dates (role-playing: same dimension joined twice)
    LEFT JOIN dim_date issue_d
        ON s.issue_date = issue_d.full_date
    LEFT JOIN dim_date judgment_d
        ON s.judgment_entry_date = judgment_d.full_date

    -- Time (violation_time is already TIME at minute precision)
    LEFT JOIN dim_time t
        ON  EXTRACT(HOUR FROM s.violation_time) = t.hour
        AND EXTRACT(MINUTE FROM s.violation_time) = t.minutes

    -- License plate: IS NOT DISTINCT FROM so a NULL state or type still matches its combination
    LEFT JOIN dim_license_plate lp
        ON  s.license_state IS NOT DISTINCT FROM lp.license_state
        AND s.license_type IS NOT DISTINCT FROM lp.license_type
        AND lp.license_plate_key != '-1'

    LEFT JOIN dim_violation v
        ON s.violation_type = v.violation_type

    LEFT JOIN dim_borough b
        ON s.borough = b.borough

    LEFT JOIN dim_agency ag
        ON s.agency_name = ag.agency_name

)

SELECT * FROM fact_parking_camera_violations