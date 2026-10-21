-- Pelevo Plus store billing columns.
-- Database: PostgreSQL on Laravel Forge.
-- Forge applies api/database/migrations, not this file:
--   2026_10_21_150000_add_store_billing_to_premium_subscriptions.php
--   2026_10_21_150100_create_subscription_transactions_table.php
--   2026_10_21_150200_add_plus_subscription_updated_at_trigger.php
--
-- users.id is a ULID. premium_entitlements, premium_subscriptions, and
-- provider_webhook_events already exist. These statements only add the
-- store billing fields and the append-only charge log.

ALTER TABLE premium_subscriptions
  ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE premium_subscriptions
  ADD COLUMN billing_country_code char(2) NULL,
  ADD COLUMN billing_currency char(3) NULL,
  ADD COLUMN amount_minor bigint NULL,
  ADD COLUMN grace_period_ends_at timestamptz NULL,
  ADD COLUMN is_in_intro_offer boolean NOT NULL DEFAULT false,
  ADD COLUMN current_product_id varchar(100) NULL;

CREATE TABLE subscription_transactions (
  id char(26) NOT NULL,
  premium_subscription_id char(26) NOT NULL,
  store_platform varchar(50) NOT NULL,
  store_event_id varchar(255) NOT NULL,
  event_type varchar(64) NOT NULL,
  product_id varchar(100) NOT NULL,
  billing_country_code char(2) NOT NULL,
  billing_currency char(3) NOT NULL,
  amount_minor bigint NOT NULL,
  is_intro_offer boolean NOT NULL DEFAULT false,
  period_start timestamptz NOT NULL,
  period_end timestamptz NOT NULL,
  raw_payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id),
  CONSTRAINT subscription_transactions_event_uq
    UNIQUE (store_platform, store_event_id),
  CONSTRAINT subscription_transactions_event_chk CHECK (
    event_type IN (
      'INITIAL_PURCHASE',
      'RENEWAL',
      'DID_FAIL_TO_RENEW',
      'CANCELLATION',
      'EXPIRATION'
    )
  ),
  CONSTRAINT subscription_transactions_premium_subscription_id_foreign
    FOREIGN KEY (premium_subscription_id) REFERENCES premium_subscriptions (id)
);

CREATE INDEX subscription_transactions_sub_idx
  ON subscription_transactions (premium_subscription_id, created_at);

CREATE OR REPLACE FUNCTION plus_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER premium_subscriptions_set_updated_at
  BEFORE UPDATE ON premium_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION plus_set_updated_at();

CREATE TRIGGER premium_entitlements_set_updated_at
  BEFORE UPDATE ON premium_entitlements
  FOR EACH ROW
  EXECUTE FUNCTION plus_set_updated_at();
