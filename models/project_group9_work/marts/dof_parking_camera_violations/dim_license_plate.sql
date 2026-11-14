-- License plate dimension for parking and camera violations
-- Grain: one row per distinct (license_state, license_type) combination
-- Individual plate numbers stay in the fact table

WITH stg_parking_violations AS (
    SELECT * FROM {{ ref('stg_nyc_parking_camera_violations') }}
),

distinct_plates AS (

    SELECT DISTINCT
        license_state,
        license_type
    FROM stg_parking_violations
    -- keep combinations where at least one attribute is known;
    -- rows where both are null map to the -1 placeholder
    WHERE license_state IS NOT NULL
       OR license_type IS NOT NULL

),

enriched AS (

    SELECT
        license_state,
        license_type,

        -- Derived group based on NY DMV plate class codes
        CASE
            WHEN license_type IS NULL OR license_type = '999' THEN 'unknown'
            WHEN license_type IN ('PAS', 'SRF', 'SPO') THEN 'passenger'
            WHEN license_type IN ('COM', 'APP', 'IRP', 'TRC', 'TRL', 'SEM', 'CMB', 'TOW', 'TRA') THEN 'commercial'
            WHEN license_type IN ('OMT', 'OMR', 'OMS', 'OML') THEN 'for-hire / taxi'
            ELSE 'other'
        END AS license_type_group

    FROM distinct_plates

),

license_plate_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['license_state', 'license_type']) }} AS license_plate_key,
        license_state,
        license_type,
        license_type_group
    FROM enriched

),

-- Null placeholder row: fact rows with no state and no license type map to this key
null_placeholder AS (

    SELECT
        '-1' AS license_plate_key,
        CAST(NULL AS STRING) AS license_state,
        CAST(NULL AS STRING) AS license_type,
        CAST(NULL AS STRING) AS license_type_group

)

SELECT * FROM license_plate_dimension
UNION ALL
SELECT * FROM null_placeholder