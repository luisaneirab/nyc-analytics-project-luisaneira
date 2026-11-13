-- Borough dimension shared by 311 service requests and parking/camera violations
-- Grain: one row per borough
-- Both staging models standardize borough to the same values
-- (Manhattan, Bronx, Brooklyn, Queens, Staten Island, UNKNOWN or CITYWIDE)

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_subset') }}
),

stg_parking_violations AS (
    SELECT * FROM {{ ref('stg_nyc_parking_camera_violations') }}
),

all_borough AS (

    SELECT DISTINCT borough
    FROM stg_311
    WHERE borough IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT borough
    FROM stg_parking_violations
    WHERE borough IS NOT NULL

),

borough_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['borough']) }} AS borough_key,
        borough
    FROM all_borough

),

-- Null placeholder row: fact rows with no borough map to this key
null_placeholder AS (

    SELECT
        '-1' AS borough_key,
        CAST(NULL AS STRING) AS borough

)

SELECT * FROM borough_dimension
UNION ALL
SELECT * FROM null_placeholder