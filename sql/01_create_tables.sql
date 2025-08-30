CREATE TABLE IF NOT EXISTS staging_ads (
  date TEXT,
  platform TEXT,
  account TEXT,
  campaign TEXT,
  country TEXT,
  device TEXT,
  spend TEXT,
  clicks TEXT,
  impressions TEXT,
  conversions TEXT
);

CREATE TABLE IF NOT EXISTS ads_spend (
  date DATE,
  platform TEXT,
  account TEXT,
  campaign TEXT,
  country TEXT,
  device TEXT,
  spend NUMERIC(18,2),
  clicks INTEGER,
  impressions BIGINT,
  conversions INTEGER,
  load_date TIMESTAMP,
  source_file_name TEXT,
  CONSTRAINT ads_spend_pk UNIQUE (date, platform, account, campaign, country, device)
);

CREATE TABLE IF NOT EXISTS load_log (
  source_file_name TEXT PRIMARY KEY,
  load_date TIMESTAMP
);
