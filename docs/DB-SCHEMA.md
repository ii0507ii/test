# DB Schema — 재무 관리사 Warboy (Owen's PLM)

- **문서 ID**: DB-SCHEMA-001
- **버전**: v0.1 (초안)
- **작성일**: 2026-04-19
- **상위 문서**: SRS v0.1 §6, URD v0.2
- **대상 마일스톤**: M3 (2026-04-29)
- **대상 DBMS**: PostgreSQL 16 (Beelink 로컬 · Supabase Managed)

---

## 1. 개요

### 1.1 이중 DB 구조
| DB | 위치 | 용도 | 특징 |
|---|---|---|---|
| **Beelink DB** | Beelink SER9 Pro 로컬 | 재무·세제 원장 | 로컬 격리, `pgcrypto` 암호화 |
| **Supabase DB** | 클라우드 | Auth · PM 데이터 | RLS, JWT 발급 |

두 DB는 **`auth_user_id` (uuid)**를 키로 논리적 참조하되, 물리 FK는 없다 (네트워크 경계).

### 1.2 명명 규칙
- 테이블: `snake_case`, 복수형
- PK: `id uuid DEFAULT gen_random_uuid()`
- 감사 컬럼: `created_at`, `updated_at` (TIMESTAMPTZ)
- 논리 삭제 대신 물리 삭제 + `audit_log` 기록
- 금액 단위: 원 (KRW), `BIGINT` 저장 (부동소수 금지)
- 날짜/월: `DATE` / `yyyymm` 은 `SMALLINT * 100 + month` 형태의 `INT` (예: 202604)

### 1.3 암호화 정책 (SRS-N-02-04 대응)
- 대상: `transactions.amount`, `transactions.memo`
- 방식: `pgcrypto` `pgp_sym_encrypt()` + 로컬 Keychain에 저장된 대칭키 (애플리케이션 주입)
- 컬럼 네이밍: 암호화 열은 `_enc` 접미사 (`BYTEA`), 복호화는 뷰 `v_transactions`에서 수행

---

## 2. ERD 개요

```
─── Supabase ───────────────────────────────
           users (Supabase Auth)
             │ id (uuid)
             ▼
    pm_projects ──┬── pm_milestones
                  └── pm_tasks
                         │
                         └── pm_task_comments

─── Beelink ────────────────────────────────
  (auth_user_id: Supabase users.id, 논리 FK)
                  │
     ┌────────────┼──────────────────────────┐
     ▼            ▼                          ▼
categories   transactions (enc) ──► budgets
     │            │
     │            └──► accounts (v0.2 예정)
     ▼
tax_deductions ──► tax_rules ──► tax_rules_changelog

audit_log  (cross-cutting)
```

---

## 3. Beelink 재무 DB

### 3.1 확장(extensions)
```sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gist";
```

### 3.2 `categories` — 수입/지출 카테고리
| 컬럼 | 타입 | 제약 | 설명 |
|---|---|---|---|
| `id` | uuid | PK | |
| `auth_user_id` | uuid | NOT NULL | Supabase 사용자 논리 FK |
| `name` | text | NOT NULL | 표시명 (예: "식비") |
| `kind` | text | CHECK (`income`/`expense`) | 수입·지출 구분 |
| `parent_id` | uuid | FK → categories.id (ON DELETE SET NULL) | 계층 구조 |
| `created_at` | timestamptz | DEFAULT now() | |
| `updated_at` | timestamptz | DEFAULT now() | |
| UNIQUE | (`auth_user_id`, `name`, `kind`) | | 동명 카테고리 방지 |

### 3.3 `transactions` — 거래 원장
| 컬럼 | 타입 | 제약 | 설명 |
|---|---|---|---|
| `id` | uuid | PK | |
| `auth_user_id` | uuid | NOT NULL | |
| `tx_date` | date | NOT NULL | 거래일 |
| `kind` | text | CHECK (`income`/`expense`) | |
| `category_id` | uuid | FK → categories.id (ON DELETE RESTRICT) | |
| `amount_enc` | bytea | NOT NULL | pgcrypto 암호화된 금액 |
| `memo_enc` | bytea | NULL | 선택 메모 암호화 |
| `source` | text | NOT NULL DEFAULT 'manual' | `manual`/`import`/`openclaw` |
| `external_ref` | text | NULL | 은행 거래 고유 ID (중복 방지) |
| `created_at` | timestamptz | DEFAULT now() | |
| `updated_at` | timestamptz | DEFAULT now() | |
| UNIQUE | (`auth_user_id`, `external_ref`) WHERE `external_ref` IS NOT NULL | | 외부 중복 차단 |

**인덱스**
- `idx_tx_user_date` (`auth_user_id`, `tx_date` DESC) — 월별 집계용
- `idx_tx_category` (`category_id`) — 카테고리 집계

**뷰 `v_transactions` (복호화)**: 애플리케이션은 항상 뷰 경유 조회.

### 3.4 `budgets` — 월별 예산
| 컬럼 | 타입 | 제약 | 설명 |
|---|---|---|---|
| `auth_user_id` | uuid | PK (part) | |
| `yyyymm` | int | PK (part), CHECK (`202001 ≤ yyyymm ≤ 209912`) | |
| `category_id` | uuid | PK (part), FK → categories.id | |
| `limit_amount` | bigint | NOT NULL CHECK (> 0) | 단위: KRW |
| `created_at` | timestamptz | DEFAULT now() | |
| `updated_at` | timestamptz | DEFAULT now() | |

복합 PK: (`auth_user_id`, `yyyymm`, `category_id`).

### 3.5 `tax_deductions` — 연말정산 공제 항목
| 컬럼 | 타입 | 제약 | 설명 |
|---|---|---|---|
| `id` | uuid | PK | |
| `auth_user_id` | uuid | NOT NULL | |
| `year` | smallint | NOT NULL CHECK (`2020 ≤ year ≤ 2099`) | 과세 연도 |
| `type` | text | NOT NULL | `irp`/`pension`/`housing`/`credit_card` 등 |
| `amount` | bigint | NOT NULL CHECK (>= 0) | 납입/사용액 (KRW) |
| `evidence_url` | text | NULL | 증빙 문서 링크 |
| `created_at` | timestamptz | DEFAULT now() | |
| `updated_at` | timestamptz | DEFAULT now() | |
| UNIQUE | (`auth_user_id`, `year`, `type`) | | 연·유형당 하나 |

### 3.6 `tax_rules` — 연도별 세제 규칙
| 컬럼 | 타입 | 제약 | 설명 |
|---|---|---|---|
| `year` | smallint | PK (part) | |
| `rule_key` | text | PK (part) | 예: `irp_limit`, `credit_card_rate` |
| `value` | jsonb | NOT NULL | 스칼라/구조 값 |
| `effective_from` | date | NOT NULL | |
| `source_url` | text | NULL | 국세청 링크 |
| `created_at` | timestamptz | DEFAULT now() | |

### 3.7 `tax_rules_changelog` — 세법 변경 이력 (OpenClaw)
| 컬럼 | 타입 | 제약 | 설명 |
|---|---|---|---|
| `id` | uuid | PK | |
| `year` | smallint | NOT NULL | |
| `rule_key` | text | NOT NULL | |
| `old_value` | jsonb | NULL | |
| `new_value` | jsonb | NOT NULL | |
| `source_url` | text | NOT NULL | |
| `detected_at` | timestamptz | NOT NULL DEFAULT now() | |
| `notified_at` | timestamptz | NULL | Push 발송 시각 |

### 3.8 `audit_log` — 감사 로그
| 컬럼 | 타입 | 제약 | 설명 |
|---|---|---|---|
| `id` | bigserial | PK | |
| `actor` | text | NOT NULL | `auth_user_id` 또는 `openclaw`/`system` |
| `action` | text | NOT NULL | `insert`/`update`/`delete`/`auth_fail` |
| `target_table` | text | NOT NULL | |
| `target_id` | text | NULL | |
| `meta` | jsonb | NULL | |
| `at` | timestamptz | NOT NULL DEFAULT now() | |

**인덱스**: `idx_audit_at` (`at` DESC), `idx_audit_actor` (`actor`).

### 3.9 역할 & 권한
| 역할 | 권한 |
|---|---|
| `owen_plm_app` | ALL on 재무 테이블 (앱 기본 계정) |
| `openclaw_ro` | SELECT on `tax_rules`, `tax_rules_changelog`, `transactions` (스캔 분석 전용) / INSERT on `tax_rules_changelog` |
| `owen_plm_migration` | DDL 전용 (마이그레이션) |

### 3.10 Forward Hooks (Phase 2)
- `accounts` — 계좌(은행/증권) 매핑. `transactions.account_id` 예약.
- `portfolios`, `holdings` — FR-02.
- `goals` — FR-03. 2041년 자녀 교육비 시드.
- `loans`, `loan_schedule` — FR-04.
- `households` — NFR-03 확장 시 `auth_user_id` → `household_id` 이관.

---

## 4. Supabase PM DB

> Supabase Auth `auth.users`는 내장 — 본 스키마는 `public` 스키마에 PM 테이블만 정의하고 RLS로 보호.

### 4.1 `pm_projects`
| 컬럼 | 타입 | 제약 |
|---|---|---|
| `id` | uuid | PK DEFAULT gen_random_uuid() |
| `owner_id` | uuid | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE |
| `name` | text | NOT NULL |
| `description` | text | NULL |
| `status` | text | CHECK (`active`/`archived`) DEFAULT `active` |
| `created_at` | timestamptz | DEFAULT now() |

### 4.2 `pm_milestones`
| 컬럼 | 타입 | 제약 |
|---|---|---|
| `id` | uuid | PK |
| `project_id` | uuid | FK → pm_projects (CASCADE) |
| `code` | text | NOT NULL (예: `M3`) |
| `title` | text | NOT NULL |
| `due_date` | date | NULL |
| `status` | text | CHECK (`planned`/`in_progress`/`done`) |
| UNIQUE | (`project_id`, `code`) | |

### 4.3 `pm_tasks`
| 컬럼 | 타입 | 제약 |
|---|---|---|
| `id` | uuid | PK |
| `project_id` | uuid | FK → pm_projects (CASCADE) |
| `milestone_id` | uuid | FK → pm_milestones (SET NULL) |
| `title` | text | NOT NULL |
| `description` | text | NULL |
| `priority` | text | CHECK (`low`/`mid`/`high`) DEFAULT `mid` |
| `status` | text | CHECK (`todo`/`doing`/`done`/`blocked`) DEFAULT `todo` |
| `estimate_hours` | numeric(6,2) | NULL |
| `owen_requirement_ref` | text | NULL (예: `FR-01`, `SRS-F-01-02`) |
| `created_at` | timestamptz | DEFAULT now() |
| `updated_at` | timestamptz | DEFAULT now() |

### 4.4 `pm_task_comments`
| 컬럼 | 타입 | 제약 |
|---|---|---|
| `id` | uuid | PK |
| `task_id` | uuid | FK → pm_tasks (CASCADE) |
| `author_id` | uuid | FK → auth.users |
| `body` | text | NOT NULL |
| `created_at` | timestamptz | DEFAULT now() |

### 4.5 RLS 정책 (핵심 샘플)
- 모든 PM 테이블: `owner_id = auth.uid()` 또는 `project.owner_id = auth.uid()` 인 행만 SELECT/UPDATE/DELETE.
- INSERT: `owner_id = auth.uid()` 강제.

---

## 5. 마이그레이션 전략

- **도구**: `node-pg-migrate` (애플리케이션) + Supabase CLI (PM DB)
- **순서**:
  1. `001_init_beelink.sql` — Beelink 확장/테이블/인덱스/뷰 생성
  2. `002_beelink_rls_noop.sql` — 로컬 DB는 RLS 미사용 (단일 사용자)
  3. `003_openclaw_role.sql` — OpenClaw 전용 역할 & 권한
  4. `001_init_supabase.sql` — PM 테이블 + RLS 정책
- **롤백**: 각 파일당 `down` 블록 필수. 암호화 컬럼 타입 변경은 금지 (migration 아니라 신규 컬럼 + 백필).

---

## 6. 검증 체크리스트

- [ ] `transactions.amount_enc` 암호화 round-trip 단위 테스트
- [ ] `budgets` 복합 PK UPSERT 동작 확인
- [ ] 월별 집계 쿼리 EXPLAIN에서 `idx_tx_user_date` 사용 확인
- [ ] Supabase RLS 정책 negative test (타 사용자 행 접근 거부)
- [ ] `openclaw_ro` 역할의 DDL/DML 시도 실패 확인

---

## 7. 미결 사항

- [ ] `external_ref` 포맷 표준 (은행사별 prefix)
- [ ] `tax_rules.value` 스키마 버전 관리 (`$schema` 키 포함 여부)
- [ ] Beelink DB 백업 주기 및 대상 (외장 SSD pg_dump vs. WAL 아카이빙)
- [ ] Supabase Free Tier Row 한도 도달 시 정리 정책

---

## 변경 이력
| 날짜 | 버전 | 내용 |
|---|---|---|
| 2026-04-19 | v0.1 | 초안 — Phase 1 MVP 범위, Beelink + Supabase 분리 |
