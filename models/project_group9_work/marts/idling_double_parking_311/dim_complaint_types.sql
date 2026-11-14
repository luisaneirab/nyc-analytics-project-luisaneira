-- Complaint type dimension for 311 service requests
-- Grain: one row per distinct (complaint_type, descriptor) combination
-- Extraction filtered to descriptors: Engine Idling, Double Parked Blocking Traffic,
-- Double Parked Blocking Vehicle

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_subset') }}
),

distinct_complaint_types AS (

    SELECT DISTINCT
        complaint_type,
        descriptor
    FROM stg_311
    WHERE complaint_type IS NOT NULL

),

enriched AS (

    SELECT
        complaint_type,
        descriptor,

        -- Derived category based on keywords (case insensitive)
        -- Shared categories let 311 complaints be compared with parking violations
        CASE
            WHEN LOWER(descriptor) LIKE '%idling%'
                OR LOWER(complaint_type) LIKE '%idling%'
                THEN 'Idling'

            WHEN LOWER(descriptor) LIKE '%double park%'
                OR LOWER(complaint_type) LIKE '%double park%'
                THEN 'Double Parking'

            ELSE 'Other'
        END AS complaint_category

    FROM distinct_complaint_types

),

complaint_type_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['complaint_type', 'descriptor']) }} AS complaint_type_key,
        complaint_type,
        descriptor,
        complaint_category
    FROM enriched

)

SELECT * FROM complaint_type_dimension
