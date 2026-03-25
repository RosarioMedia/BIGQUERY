-- PromoApp dataset tables

-- Leads: one row per promotional lead/coupon entry
CREATE TABLE IF NOT EXISTS promoapp.leads (
  id INTEGER,
  uuid STRING NOT NULL,
  name STRING,
  email STRING,
  phone STRING,
  customData STRING,                  -- JSON string for arbitrary extra fields
  whatsappConsent BOOLEAN,
  isUsed BOOLEAN,
  usedAt TIMESTAMP,
  usedByEmployeeId INTEGER,
  createdAt TIMESTAMP,
  offerId INTEGER,
  offerName STRING,
  promotionName STRING,
  brandName STRING,
  syncedAt TIMESTAMP,

  -- Stripe enrichment columns (populated by daily sync MERGE)
  stripe_customer_id STRING,
  stripe_customer_created TIMESTAMP,
  stripe_subscription_id STRING,
  stripe_subscription_status STRING,
  stripe_plan_name STRING,
  stripe_product_id STRING,
  stripe_amount FLOAT64,
  stripe_currency STRING,
  stripe_subscription_interval STRING,
  stripe_current_period_start TIMESTAMP,
  stripe_current_period_end TIMESTAMP,
  stripe_matched_at TIMESTAMP,
  stripe_matched_on STRING               -- 'email' or 'phone'
)
PARTITION BY DATE(createdAt)
CLUSTER BY uuid, email, brandName
OPTIONS(
  description="PromoApp promotional leads and coupon usage records - populated by external PromoApp API, enriched with Stripe subscription data by daily sync"
);
