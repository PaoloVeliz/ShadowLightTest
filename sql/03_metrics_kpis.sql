WITH anchor AS (
  SELECT (MAX(date) + 1)::date AS anchor_end FROM ads_spend
),
bounds AS (
  SELECT
    (anchor_end - INTERVAL '30 days')::date AS last_start,
    anchor_end                              AS last_end,
    (anchor_end - INTERVAL '60 days')::date AS prior_start,
    (anchor_end - INTERVAL '30 days')::date AS prior_end
  FROM anchor
),
sums AS (
  SELECT
    COALESCE(SUM(CASE WHEN a.date >= b.last_start  AND a.date < b.last_end  THEN spend       END),0)::numeric AS last_spend,
    COALESCE(SUM(CASE WHEN a.date >= b.last_start  AND a.date < b.last_end  THEN conversions END),0)::numeric AS last_conv,
    COALESCE(SUM(CASE WHEN a.date >= b.prior_start AND a.date < b.prior_end THEN spend       END),0)::numeric AS prior_spend,
    COALESCE(SUM(CASE WHEN a.date >= b.prior_start AND a.date < b.prior_end THEN conversions END),0)::numeric AS prior_conv
  FROM ads_spend a
  CROSS JOIN bounds b
)
SELECT
  -- CAC
  ROUND(last_spend/NULLIF(last_conv,0), 2)                                       AS cac_last_30,
  ROUND(prior_spend/NULLIF(prior_conv,0), 2)                                     AS cac_prior_30,
  ROUND((last_spend/NULLIF(last_conv,0))-(prior_spend/NULLIF(prior_conv,0)), 2)  AS cac_delta_abs,
  CASE WHEN prior_conv IS NULL OR prior_conv=0 THEN NULL
       ELSE ROUND( ((last_spend/NULLIF(last_conv,0))-(prior_spend/NULLIF(prior_conv,0))) / (prior_spend/NULLIF(prior_conv,0)), 4)
  END AS cac_delta_pct,
  -- ROAS (revenue = conv*100)
  ROUND((last_conv*100)/NULLIF(last_spend,0), 2)                                  AS roas_last_30,
  ROUND((prior_conv*100)/NULLIF(prior_spend,0), 2)                                AS roas_prior_30,
  ROUND(((last_conv*100)/NULLIF(last_spend,0))-((prior_conv*100)/NULLIF(prior_spend,0)), 2) AS roas_delta_abs,
  CASE WHEN prior_spend IS NULL OR prior_spend=0 THEN NULL
       ELSE ROUND( ( ((last_conv*100)/NULLIF(last_spend,0)) - ((prior_conv*100)/NULLIF(prior_spend,0)) ) / ((prior_conv*100)/NULLIF(prior_spend,0)), 4)
  END AS roas_delta_pct
FROM sums;
