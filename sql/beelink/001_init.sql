-- Beelink 재무 DB 초기 스키마
-- 문서: DB-SCHEMA-001 v0.1
-- 대상: PostgreSQL 16 (Beelink SER9 Pro 로컬)

BEGIN;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- categories -----------------------------------------------------------------
CREATE TABLE categories (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id  uuid        NOT NULL,
    name          text        NOT NULL,
    kind          text        NOT NULL CHECK (kind IN ('income', 'expense')),
    parent_id     uuid        REFERENCES categories(id) ON DELETE SET NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (auth_user_id, name, kind)
);

CREATE INDEX idx_categories_user ON categories (auth_user_id);

-- transactions ---------------------------------------------------------------
CREATE TABLE transactions (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id  uuid        NOT NULL,
    tx_date       date        NOT NULL,
    kind          text        NOT NULL CHECK (kind IN ('income', 'expense')),
    category_id   uuid        NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    amount_enc    bytea       NOT NULL,
    memo_enc      bytea,
    source        text        NOT NULL DEFAULT 'manual'
                              CHECK (source IN ('manual', 'import', 'openclaw')),
    external_ref  text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_tx_user_date ON transactions (auth_user_id, tx_date DESC);
CREATE INDEX idx_tx_category  ON transactions (category_id);
CREATE UNIQUE INDEX uq_tx_external_ref
    ON transactions (auth_user_id, external_ref)
    WHERE external_ref IS NOT NULL;

-- 복호화 뷰: 애플리케이션은 이 뷰를 통해서만 조회.
-- 키는 세션 변수 app.enc_key 로 주입 (SET app.enc_key = '...').
CREATE OR REPLACE VIEW v_transactions AS
SELECT
    t.id,
    t.auth_user_id,
    t.tx_date,
    t.kind,
    t.category_id,
    pgp_sym_decrypt(t.amount_enc, current_setting('app.enc_key'))::bigint AS amount,
    CASE WHEN t.memo_enc IS NULL THEN NULL
         ELSE pgp_sym_decrypt(t.memo_enc, current_setting('app.enc_key'))
    END AS memo,
    t.source,
    t.external_ref,
    t.created_at,
    t.updated_at
FROM transactions t;

-- budgets --------------------------------------------------------------------
CREATE TABLE budgets (
    auth_user_id  uuid        NOT NULL,
    yyyymm        int         NOT NULL CHECK (yyyymm BETWEEN 202001 AND 209912),
    category_id   uuid        NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    limit_amount  bigint      NOT NULL CHECK (limit_amount > 0),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (auth_user_id, yyyymm, category_id)
);

-- tax_deductions -------------------------------------------------------------
CREATE TABLE tax_deductions (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id  uuid        NOT NULL,
    year          smallint    NOT NULL CHECK (year BETWEEN 2020 AND 2099),
    type          text        NOT NULL,
    amount        bigint      NOT NULL CHECK (amount >= 0),
    evidence_url  text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (auth_user_id, year, type)
);

CREATE INDEX idx_deductions_user_year ON tax_deductions (auth_user_id, year);

-- tax_rules ------------------------------------------------------------------
CREATE TABLE tax_rules (
    year            smallint    NOT NULL CHECK (year BETWEEN 2020 AND 2099),
    rule_key        text        NOT NULL,
    value           jsonb       NOT NULL,
    effective_from  date        NOT NULL,
    source_url      text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (year, rule_key)
);

-- tax_rules_changelog --------------------------------------------------------
CREATE TABLE tax_rules_changelog (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    year         smallint    NOT NULL,
    rule_key     text        NOT NULL,
    old_value    jsonb,
    new_value    jsonb       NOT NULL,
    source_url   text        NOT NULL,
    detected_at  timestamptz NOT NULL DEFAULT now(),
    notified_at  timestamptz
);

CREATE INDEX idx_changelog_detected ON tax_rules_changelog (detected_at DESC);

-- audit_log ------------------------------------------------------------------
CREATE TABLE audit_log (
    id            bigserial   PRIMARY KEY,
    actor         text        NOT NULL,
    action        text        NOT NULL,
    target_table  text        NOT NULL,
    target_id     text,
    meta          jsonb,
    at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_at    ON audit_log (at DESC);
CREATE INDEX idx_audit_actor ON audit_log (actor);

-- updated_at 자동 갱신 트리거 ------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_categories_updated      BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_transactions_updated    BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_budgets_updated         BEFORE UPDATE ON budgets
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_deductions_updated      BEFORE UPDATE ON tax_deductions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
