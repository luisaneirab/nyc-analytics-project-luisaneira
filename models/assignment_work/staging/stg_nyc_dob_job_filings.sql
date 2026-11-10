-- Clean and standardize DOB NOW job filing data
-- One row per job filing

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           job_filing_number,
           filing_date,
           current_status_date,
           first_permit_date,
           approved_date,
           signoff_date,
           zip,
           city,
           state,
           filing_representative_zip,
           postcode,
           borough,
           latitude,
           longitude,
           standpipe,
           antenna,
           sign,
           curb_cut,
           fence,
           scaffold,
           shed,
           total_construction_floor_area
       ),

       -- Identifiers
       CAST(job_filing_number AS STRING) AS job_filing_id,

       -- Date/Time
       CAST(filing_date AS TIMESTAMP) AS filing_date,
       CAST(current_status_date AS TIMESTAMP) AS current_status_date,
       CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
       CAST(approved_date AS TIMESTAMP) AS approved_date,
       CAST(signoff_date AS TIMESTAMP) AS signoff_date,

       -- Location - clean zip code, handling several common zip code data problems
       CASE
           WHEN UPPER(TRIM(CAST(postcode AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN UPPER(TRIM(CAST(postcode AS STRING))) = 'ANONYMOUS' THEN 'Anonymous'
           WHEN LENGTH(CAST(postcode AS STRING)) = 5 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 9 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(postcode AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(postcode AS STRING)
           ELSE NULL
       END AS zip,

       -- Other addresses, renamed so they aren't confused with zip
       CASE
           WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN UPPER(TRIM(CAST(zip AS STRING))) = 'ANONYMOUS' THEN 'Anonymous'
           WHEN LENGTH(CAST(zip AS STRING)) = 5 THEN CAST(zip AS STRING)
           WHEN LENGTH(CAST(zip AS STRING)) = 9 THEN CAST(zip AS STRING)
           WHEN LENGTH(CAST(zip AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(zip AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(zip AS STRING)
           ELSE NULL
       END AS applicant_zip,

       CASE
           WHEN UPPER(TRIM(CAST(filing_representative_zip AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN UPPER(TRIM(CAST(filing_representative_zip AS STRING))) = 'ANONYMOUS' THEN 'Anonymous'
           WHEN LENGTH(CAST(filing_representative_zip AS STRING)) = 5 THEN CAST(filing_representative_zip AS STRING)
           WHEN LENGTH(CAST(filing_representative_zip AS STRING)) = 9 THEN CAST(filing_representative_zip AS STRING)
           WHEN LENGTH(CAST(filing_representative_zip AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(filing_representative_zip AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(filing_representative_zip AS STRING)
           ELSE NULL
       END AS filing_representative_zip,

       -- Location - standardized borough, just in case 
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       -- Latitude and longitude
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- Clearer column names
       CAST(city AS STRING) AS applicant_city,
       CAST(state AS STRING) AS applicant_state,
       CAST(standpipe AS STRING) AS standpipe_work_type,
       CAST(antenna AS STRING) AS antenna_work_type,
       CAST(sign AS STRING) AS sign_work_type,
       CAST(curb_cut AS STRING) AS curb_cut_work_type,
       CAST(fence AS STRING) AS fence_work_type,
       CAST(scaffold AS STRING) AS scaffold_work_type,
       CAST(shed AS STRING) AS shed_work_type,

       -- Total_construction_area from string type to float
       SAFE_CAST(total_construction_floor_area AS FLOAT64) AS total_construction_floor_area,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE job_filing_number IS NOT NULL
   AND filing_date IS NOT NULL
   AND CAST(filing_date AS DATE) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 YEAR)
   AND borough IS NOT NULL

   -- Deduplicate
   QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY filing_date DESC) = 1
)

SELECT * FROM cleaned
-- All should be part of this table after running: stg_nyc_dob_job_filings
