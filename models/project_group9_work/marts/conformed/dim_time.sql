-- Time-of-day dimension shared by 311 service requests and parking/camera violations
-- Grain: one row per minute of the day (HH:MM)
-- 311 timestamps include seconds; truncated to the minute to match parking times

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_subset') }}
),

stg_parking_violations AS (
    SELECT * FROM {{ ref('stg_nyc_parking_camera_violations') }}
),

-- Extract the time portion from the 311 timestamp columns
-- (date portion goes to dim_conformed_date)
stg_311_times AS (

    SELECT TIME_TRUNC(TIME(created_date), MINUTE) AS time_of_day
    FROM stg_311
    WHERE created_date IS NOT NULL

    UNION DISTINCT

    SELECT TIME_TRUNC(TIME(closed_date), MINUTE) AS time_of_day
    FROM stg_311
    WHERE closed_date IS NOT NULL

),

-- Union all possible times from both sources
all_times AS (

    SELECT time_of_day
    FROM stg_311_times

    UNION DISTINCT

    -- Parking violation_time is already TIME at minute precision (parsed in staging)
    SELECT DISTINCT violation_time AS time_of_day
    FROM stg_parking_violations
    WHERE violation_time IS NOT NULL

),

time_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['time_of_day']) }} AS time_key,

        EXTRACT(HOUR FROM time_of_day) AS hour,
        EXTRACT(MINUTE FROM time_of_day) AS minutes,

        -- Day-part flags (team definitions; exactly one is TRUE for each time)
        EXTRACT(HOUR FROM time_of_day) BETWEEN 5 AND 11 AS is_morning,     -- 5:00 AM - 11:59 AM
        EXTRACT(HOUR FROM time_of_day) BETWEEN 12 AND 18 AS is_afternoon,  -- 12:00 PM - 6:59 PM
        EXTRACT(HOUR FROM time_of_day) BETWEEN 19 AND 22 AS is_evening,    -- 7:00 PM - 10:59 PM
        EXTRACT(HOUR FROM time_of_day) >= 23
            OR EXTRACT(HOUR FROM time_of_day) < 5 AS is_night,             -- 11:00 PM - 4:59 AM

        -- Rush hour: 7:00 AM - 9:59 AM and 4:00 PM - 6:59 PM
        -- Overlaps the day-part flags on purpose (spans morning and afternoon)
        -- Time only: combine with is_weekend from dim_date for weekday rush hours
        EXTRACT(HOUR FROM time_of_day) BETWEEN 7 AND 9
            OR EXTRACT(HOUR FROM time_of_day) BETWEEN 16 AND 18 AS is_rush_hour

    FROM all_times

),

-- Null placeholder row: fact rows with no time (e.g., unparseable parking times, open 311 complaints)
null_placeholder AS (

    SELECT
        '-1' AS time_key,
        CAST(NULL AS INT64) AS hour,
        CAST(NULL AS INT64) AS minutes,
        CAST(NULL AS BOOLEAN) AS is_morning,
        CAST(NULL AS BOOLEAN) AS is_afternoon,
        CAST(NULL AS BOOLEAN) AS is_evening,
        CAST(NULL AS BOOLEAN) AS is_night,
        CAST(NULL AS BOOLEAN) AS is_rush_hour

)

SELECT * FROM time_dimension
UNION ALL
SELECT * FROM null_placeholder