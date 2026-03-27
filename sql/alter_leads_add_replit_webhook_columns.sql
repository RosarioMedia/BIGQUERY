-- Track per-Replit-app delivery of "converted to paying member" notifications.
-- Safe to re-run — ADD COLUMN IF NOT EXISTS.

ALTER TABLE promoapp.leads
  ADD COLUMN IF NOT EXISTS replit_conversion_webhook_1_sent_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS replit_conversion_webhook_2_sent_at TIMESTAMP;
