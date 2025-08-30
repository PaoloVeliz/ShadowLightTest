INSERT INTO ads_spend (
  date, platform, account, campaign, country, device,
  spend, clicks, impressions, conversions,
  load_date, source_file_name
)
SELECT
  CAST(NULLIF(date,'') AS DATE),
  platform, account, campaign, country, device,
  CAST(NULLIF(spend,'') AS NUMERIC(18,2)),
  CAST(NULLIF(clicks,'') AS INTEGER),
  CAST(NULLIF(impressions,'') AS BIGINT),
  CAST(NULLIF(conversions,'') AS INTEGER),
  NOW(),        
  $1            
FROM staging_ads
ON CONFLICT (date, platform, account, campaign, country, device) DO NOTHING;


INSERT INTO load_log(source_file_name, load_date)
VALUES ($1, NOW())
ON CONFLICT (source_file_name) DO NOTHING;

TRUNCATE staging_ads;
