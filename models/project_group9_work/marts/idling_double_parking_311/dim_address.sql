-- Address dimension for 311 service requests
-- Grain: one row per distinct combination of location attributes
-- Borough is handled separately in the conformed dim_borough

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_subset') }}
),

distinct_addresses AS (

    SELECT DISTINCT
        location_type,
        zip,
        incident_address,
        city,
        street_name,
        cross_street_1,
        cross_street_2,
        intersection_street_1,
        intersection_street_2,
        address_type,
        landmark
    FROM stg_311
    -- keep rows with at least one known location attribute;
    -- rows where all are null map to the -1 placeholder
    WHERE COALESCE(
        location_type, zip, incident_address, city, street_name,
        cross_street_1, cross_street_2, intersection_street_1,
        intersection_street_2, address_type, landmark
    ) IS NOT NULL

),

address_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'location_type', 'zip', 'incident_address', 'city', 'street_name',
            'cross_street_1', 'cross_street_2', 'intersection_street_1',
            'intersection_street_2', 'address_type', 'landmark'
        ]) }} AS address_key,

        location_type,
        zip,
        incident_address,
        city,
        street_name,
        cross_street_1,
        cross_street_2,
        intersection_street_1,
        intersection_street_2,
        address_type,
        landmark

    FROM distinct_addresses

),

-- Null placeholder row: requests with no location information map to this key
null_placeholder AS (

    SELECT
        '-1' AS address_key,
        CAST(NULL AS STRING) AS location_type,
        CAST(NULL AS STRING) AS zip,
        CAST(NULL AS STRING) AS incident_address,
        CAST(NULL AS STRING) AS city,
        CAST(NULL AS STRING) AS street_name,
        CAST(NULL AS STRING) AS cross_street_1,
        CAST(NULL AS STRING) AS cross_street_2,
        CAST(NULL AS STRING) AS intersection_street_1,
        CAST(NULL AS STRING) AS intersection_street_2,
        CAST(NULL AS STRING) AS address_type,
        CAST(NULL AS STRING) AS landmark

)

SELECT * FROM address_dimension
UNION ALL
SELECT * FROM null_placeholder