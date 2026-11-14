-- Date dimension shared by  311 idling and double parking service requests and DOF Parking and camera violations

-- Build initial CTEs for Jinja syntax to make refs to staging models easier
WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_subset') }}
),

stg_parking_violations AS (
    SELECT * FROM {{ ref('stg_nyc_parking_camera_violations') }}
),

-- Then union dates from the staging data together, collecting all poss dates
all_dates AS (

    -- 311 service requests: date roles referenced by fact_311_service_request
    SELECT DISTINCT CAST(created_date AS DATE) AS full_date
    FROM stg_311
    WHERE created_date IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT CAST(closed_date AS DATE) AS full_date
    FROM stg_311
    WHERE closed_date IS NOT NULL


    UNION DISTINCT 

    SELECT DISTINCT CAST(resolution_action_updated_date AS DATE) AS full_date
    FROM stg_311
    WHERE resolution_action_updated_date IS NOT NULL

    UNION DISTINCT

    -- DOF Parking Camera Violations: date roles referenced by fact_parking_camera_violations
    SELECT DISTINCT CAST(issue_date AS DATE) AS full_date
    FROM stg_parking_violations
    WHERE issue_date IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT CAST(judgment_entry_date AS DATE) AS full_date
    FROM stg_parking_violations
    WHERE judgment_entry_date IS NOT NULL

),


-- Date dimension with NYC fiscal year, Jul 1 - Jun 30, diff from federal
date_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['full_date']) }} AS date_key,

        full_date,
        EXTRACT(YEAR FROM full_date) AS year,
        EXTRACT(QUARTER FROM full_date) AS quarter,
        EXTRACT(MONTH FROM full_date) AS month,
        FORMAT_DATE('%B', full_date) AS month_name,
        EXTRACT(DAY FROM full_date) AS day_of_month,
        EXTRACT(DAYOFWEEK FROM full_date) AS day_of_week,
        FORMAT_DATE('%A', full_date) AS weekday_name,
        EXTRACT(DAYOFWEEK FROM full_date) IN (1, 7) AS is_weekend,

        CASE
            WHEN EXTRACT(MONTH FROM full_date) >= 7 THEN EXTRACT(YEAR FROM full_date) + 1
            ELSE EXTRACT(YEAR FROM full_date)
        END AS fiscal_year

    FROM all_dates

),

-- Null placeholder row: to handle NULL values.
-- Fact tables should map a null source date to this key (e.g., open complaints with no closed_date)
-- Keeps all fact and date_dim joins INNER JOINs safely
null_placeholder AS (

    SELECT
        '-1' AS date_key,
        CAST(NULL AS DATE) AS full_date,
        CAST(NULL AS INT64) AS year,
        CAST(NULL AS INT64) AS quarter,
        CAST(NULL AS INT64) AS month,
        CAST(NULL AS STRING) AS month_name,
        CAST(NULL AS INT64) AS day_of_month,
        CAST(NULL AS INT64) AS day_of_week,
        CAST(NULL AS STRING) AS weekday_name,
        CAST(NULL AS BOOLEAN) AS is_weekend,
        CAST(NULL AS INT64) AS fiscal_year
)
-- explicit CASTs so BigQuery knows the column types for the UNION

SELECT * FROM date_dimension

UNION ALL

SELECT * FROM null_placeholder
