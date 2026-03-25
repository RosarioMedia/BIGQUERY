-- Migration: add Stripe enrichment columns to promoapp.leads
-- Safe to run repeatedly — ADD COLUMN IF NOT EXISTS is idempotent.

ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_customer_id STRING;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_customer_created TIMESTAMP;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_subscription_id STRING;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_subscription_status STRING;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_plan_name STRING;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_product_id STRING;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_amount FLOAT64;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_currency STRING;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_subscription_interval STRING;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_current_period_start TIMESTAMP;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_current_period_end TIMESTAMP;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_matched_at TIMESTAMP;
ALTER TABLE promoapp.leads ADD COLUMN IF NOT EXISTS stripe_matched_on STRING;
