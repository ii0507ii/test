-- Beelink DB 역할 및 권한
-- 문서: DB-SCHEMA-001 §3.9

BEGIN;

-- 애플리케이션 기본 역할
CREATE ROLE owen_plm_app LOGIN PASSWORD :'app_password';
GRANT CONNECT ON DATABASE :"dbname" TO owen_plm_app;
GRANT USAGE ON SCHEMA public TO owen_plm_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO owen_plm_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO owen_plm_app;

-- OpenClaw 스캔 전용 역할 (읽기 + changelog INSERT)
CREATE ROLE openclaw_ro LOGIN PASSWORD :'openclaw_password';
GRANT CONNECT ON DATABASE :"dbname" TO openclaw_ro;
GRANT USAGE ON SCHEMA public TO openclaw_ro;
GRANT SELECT ON tax_rules, tax_rules_changelog, transactions TO openclaw_ro;
GRANT INSERT ON tax_rules_changelog TO openclaw_ro;
GRANT USAGE, SELECT ON SEQUENCE audit_log_id_seq TO openclaw_ro;
GRANT INSERT ON audit_log TO openclaw_ro;

-- 마이그레이션 전용 (DDL)
CREATE ROLE owen_plm_migration LOGIN PASSWORD :'migration_password';
GRANT ALL PRIVILEGES ON DATABASE :"dbname" TO owen_plm_migration;

COMMIT;
