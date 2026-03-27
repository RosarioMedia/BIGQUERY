-- Track per-Replit-app delivery of "converted to paying member" notifications.
-- Safe to re-run — ADD COLUMN IF NOT EXISTS.
-- 03/28/2026 - Added two columns to track per-Replit-app delivery of "converted to paying member" notifications.
ALTER TABLE promoapp.leads
  ADD COLUMN IF NOT EXISTS replit_conversion_webhook_1_sent_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS replit_conversion_webhook_2_sent_at TIMESTAMP;
