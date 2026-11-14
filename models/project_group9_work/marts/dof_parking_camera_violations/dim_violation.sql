-- Violation dimension for parking and camera violations
-- Grain: one row per distinct violation_type
-- Derived category matches complaint_category in dim_complaint_type,
-- so 311 complaints and parking violations can be compared

WITH stg_parking_violations AS (
    SELECT * FROM {{ ref('stg_nyc_parking_camera_violations') }}
),

distinct_violations AS (

    SELECT DISTINCT violation_type
    FROM stg_parking_violations
    WHERE violation_type IS NOT NULL

),

enriched AS (

    SELECT
        violation_type,

        -- Derived category based on keywords (case insensitive)
        -- Values must match complaint_category in dim_complaint_type
        CASE
            WHEN LOWER(violation_type) LIKE '%idling%' THEN 'Idling'
            WHEN LOWER(violation_type) LIKE '%double park%' THEN 'Double Parking'
            ELSE 'Other'
        END AS violation_category

    FROM distinct_violations

),

violation_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['violation_type']) }} AS violation_key,
        violation_type,
        violation_category
    FROM enriched

)

SELECT * FROM violation_dimension