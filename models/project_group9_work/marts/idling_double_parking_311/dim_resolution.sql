-- Resolution dimension for 311 service requests
-- Grain: one row per distinct resolution_description
-- Derived category groups the standard NYPD response templates into outcomes
-- (older "The Police Department..." and newer "The New York City Police Department..."
-- wordings of the same outcome map to the same category)

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_subset') }}
),

distinct_resolutions AS (

    SELECT DISTINCT resolution_description
    FROM stg_311
    WHERE resolution_description IS NOT NULL

),

enriched AS (

    SELECT
        resolution_description,

        -- Derived category based on keywords (case insensitive)
        -- Order matters: the first matching WHEN wins
        CASE
            WHEN LOWER(resolution_description) LIKE '%summons%' THEN 'summons issued'
            WHEN LOWER(resolution_description) LIKE '%arrest%' THEN 'arrest made'
            WHEN LOWER(resolution_description) LIKE '%took action%' THEN 'action taken'
            WHEN LOWER(resolution_description) LIKE '%violation of law occurred%' THEN 'violation found'
            WHEN LOWER(resolution_description) LIKE '%report was prepared%' THEN 'report prepared'
            WHEN LOWER(resolution_description) LIKE '%were gone%' THEN 'gone on arrival'
            WHEN LOWER(resolution_description) LIKE '%unable to gain entry%' THEN 'unable to gain entry'
            WHEN LOWER(resolution_description) LIKE '%observed no%' THEN 'no violation observed'
            WHEN LOWER(resolution_description) LIKE '%not necessary%' THEN 'no action needed'
            WHEN LOWER(resolution_description) LIKE '%jurisdiction%' THEN 'outside police jurisdiction'
            WHEN LOWER(resolution_description) LIKE '%insufficient contact%' THEN 'insufficient contact information'
            WHEN LOWER(resolution_description) LIKE '%additional information%' THEN 'pending or informational'
            ELSE 'other'
        END AS resolution_category,

        -- Simple flag: did the complaint lead to police enforcement?
        LOWER(resolution_description) LIKE '%summons%'
            OR LOWER(resolution_description) LIKE '%arrest%'
            OR LOWER(resolution_description) LIKE '%took action%'
            OR LOWER(resolution_description) LIKE '%violation of law occurred%' AS is_enforcement

    FROM distinct_resolutions

),

resolution_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['resolution_description']) }} AS resolution_key,
        resolution_description,
        resolution_category,
        is_enforcement
    FROM enriched

),

-- Null placeholder row: open complaints have no resolution yet but should stay in the analysis
null_placeholder AS (

    SELECT
        '-1' AS resolution_key,
        CAST(NULL AS STRING) AS resolution_description,
        CAST(NULL AS STRING) AS resolution_category,
        CAST(NULL AS BOOLEAN) AS is_enforcement

)

SELECT * FROM resolution_dimension
UNION ALL
SELECT * FROM null_placeholder