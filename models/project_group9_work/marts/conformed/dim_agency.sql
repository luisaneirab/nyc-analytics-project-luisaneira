-- Agency dimension shared by both data sources
-- Grain: one row per distinct  agency

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_subset') }}
),

stg_parking_violations AS (
    SELECT * FROM {{ ref('stg_nyc_parking_camera_violations') }}
),

all_agency AS (

    SELECT DISTINCT agency_name
    FROM stg_311
    WHERE agency_name IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT agency_name
    FROM stg_parking_violations
    WHERE agency_name IS NOT NULL

),

agency_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['agency_name']) }} AS agency_key,
        agency_name
    FROM all_agency

),

null_placeholder AS (

    SELECT
        '-1' AS agency_key,
        CAST(NULL AS STRING) AS agency_name

)