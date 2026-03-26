-- Migration: add Stripe enrichment columns to promoapp.leads
-- Safe to run repeatedly — ADD COLUMN IF NOT EXISTS is idempotent.
--
-- Use a single ALTER TABLE (not one ALTER per column). BigQuery rate-limits
-- rapid schema updates on the same table; many ALTERs in a row hit this limit.

ALTER TABLE promoapp.leads
  ADD COLUMN IF NOT EXISTS stripe_customer_id STRING,
  ADD COLUMN IF NOT EXISTS stripe_customer_created TIMESTAMP,
  ADD COLUMN IF NOT EXISTS stripe_subscription_id STRING,
  ADD COLUMN IF NOT EXISTS stripe_subscription_status STRING,
  ADD COLUMN IF NOT EXISTS stripe_plan_name STRING,
  ADD COLUMN IF NOT EXISTS stripe_product_id STRING,
  ADD COLUMN IF NOT EXISTS stripe_amount FLOAT64,
  ADD COLUMN IF NOT EXISTS stripe_currency STRING,
  ADD COLUMN IF NOT EXISTS stripe_subscription_interval STRING,
  ADD COLUMN IF NOT EXISTS stripe_current_period_start TIMESTAMP,
  ADD COLUMN IF NOT EXISTS stripe_current_period_end TIMESTAMP,
  ADD COLUMN IF NOT EXISTS stripe_matched_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS stripe_matched_on STRING;
