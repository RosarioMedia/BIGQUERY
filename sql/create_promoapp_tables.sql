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
  syncedAt TIMESTAMP
)
PARTITION BY DATE(createdAt)
CLUSTER BY uuid, email, brandName
OPTIONS(
  description="PromoApp promotional leads and coupon usage records - populated by external PromoApp API"
);
