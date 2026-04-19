# Inputs — 구현 착수 전 준비 사항

- **문서 ID**: INPUTS-2026-001
- **버전**: v0.1
- **작성일**: 2026-04-19
- **목적**: M5(MVP 구현) 착수 전에 사용자가 준비·제공해야 할 정보·계정·하드웨어를 한 곳에 정리

---

## 1. 계정 & 외부 서비스

| # | 항목 | 상태 | 필요한 값 | 비고 |
|---|---|---|---|---|
| 1 | Supabase 프로젝트 | ⬜ | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Free Tier |
| 2 | Vercel 프로젝트 | ⬜ | 팀·프로젝트명, GitHub 연결 | Hobby |
| 3 | Cloudflare 계정 | ⬜ | 이메일, API Token (Zone:DNS:Edit) | 무료 |
| 4 | 소유 도메인 | ⬜ | `warboy.example.com` (실 도메인으로 교체) | Cloudflare DNS 위임 |
| 5 | GitHub 저장소 | ✅ | `ii0507ii/test` | 현재 |
| 6 | Sentry 프로젝트 | ⬜ | `SENTRY_DSN` | Free Tier (PII 스크러빙) |
| 7 | UptimeRobot 계정 | ⬜ | 모니터 URL 2개(`/health`, PWA) | 무료 5분 간격 |
| 8 | Telegram Bot | ⬜ | `TG_BOT_TOKEN`, `TG_CHAT_ID` | 운영자 알림 채널 |
| 9 | VAPID 키 페어 | ⬜ | Public/Private key | `npx web-push generate-vapid-keys` |

---

## 2. 하드웨어 & 로컬 환경

| # | 항목 | 상태 | 비고 |
|---|---|---|---|
| 1 | Beelink SER9 Pro | ⬜ (~600,000원) | Ryzen 7 H 255 |
| 2 | 외장 SSD 512GB 이상 | ⬜ (~60,000원) | pg_dump·WAL 백업 |
| 3 | UPS (선택) | ⬜ (~80,000원) | 정전 안전 종료 |
| 4 | Ubuntu 24.04 LTS 설치 | ⬜ | 서버 에디션 권장 |
| 5 | LUKS 전체 디스크 암호화 | ⬜ | 설치 단계에서 활성 |
| 6 | SSH 키 페어 | ⬜ | GitHub Action 배포용 |

---

## 3. 비밀(Secrets) 체크리스트

> ⚠️ 값은 Keychain/Vercel/GitHub Secrets에 저장, 소스 코드·Notion·Slack 공유 금지.

### 3.1 Beelink OS Keychain (`secret-tool`)
| 키 이름 | 용도 | 생성 시점 |
|---|---|---|
| `owen-plm.db.enc_key` | `pgcrypto` 대칭키 (amount/memo) | 최초 배포 (최소 32자 random) |
| `owen-plm.vapid.private` | Web Push VAPID Private | 9번 생성 후 주입 |
| `owen-plm.supabase.service_role` | PM DB 관리용 (마이그레이션만) | Supabase 가입 후 |

### 3.2 Beelink `.env` (파일 권한 `600`, 소유자 `owen`)
```
DATABASE_URL=postgres://owen_plm_app:****@127.0.0.1:5432/owen_plm
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_JWKS_URL=https://xxx.supabase.co/auth/v1/.well-known/jwks.json
SUPABASE_AUD=authenticated
OPENCLAW_DB_URL=postgres://openclaw_ro:****@127.0.0.1:5432/owen_plm
SENTRY_DSN=
VAPID_PUBLIC_KEY=
TG_BOT_TOKEN=
TG_CHAT_ID=
ALLOWED_ORIGINS=https://warboy.example.com,http://localhost:5173
NODE_ENV=production
```

### 3.3 Vercel 환경변수 (PWA)
| 키 | 값 | 범위 |
|---|---|---|
| `VITE_SUPABASE_URL` | Supabase URL | Production·Preview |
| `VITE_SUPABASE_ANON_KEY` | Anon Key | Production·Preview |
| `VITE_API_BASE_URL` | `https://api.warboy.example.com` | Production·Preview |
| `VITE_VAPID_PUBLIC_KEY` | VAPID Public | Production·Preview |
| `VITE_SENTRY_DSN` | Frontend 전용 DSN | Production |

### 3.4 GitHub Actions Secrets
| 키 | 용도 |
|---|---|
| `BEELINK_SSH_HOST` | Tunnel 도메인 또는 로컬 터미널 접근 |
| `BEELINK_SSH_USER` | `owen` |
| `BEELINK_SSH_KEY` | 배포 전용 키 (pushable만) |
| `VERCEL_TOKEN` | (선택) CLI 배포용 |

---

## 4. DB 초기 시드 데이터

| 대상 | 파일 (예정) | 내용 |
|---|---|---|
| `categories` 기본값 | `seeds/categories.sql` | 식비/교통/주거/의료/교육/급여/이자 등 10~15건 |
| `tax_rules` 2026년 | `seeds/tax_rules_2026.sql` | IRP 한도·연금저축 한도·신용카드 공제율 등 |
| `pm_projects` 시드 | Supabase Studio 수동 | "재무 관리사 - Warboy" 1건 |
| `pm_milestones` M0~M6 | 동일 | `docs/TASKS.md` §1 기반 |

---

## 5. 설정 값·상수

| 항목 | 값 | 출처 |
|---|---|---|
| 시간대 | `Asia/Seoul` | OS + `pg_settings` |
| 통화 | `KRW`, `BIGINT` 저장 | DB-SCHEMA v0.1 §1.2 |
| 세션 만료 | Access 1h / Refresh 30d | Supabase 기본 |
| `tax_rules` 캐시 TTL | 10분 | ARCH v0.1 §7.2 |
| JWKS 캐시 TTL | 1시간 | ARCH v0.1 §7.2 |
| OpenClaw 스캔 주기 | 주 1회 (월 06:00 KST) | ARCH v0.1 §5.3 |
| 예산 초과 임계치 | `지출 ≥ 예산 × 0.9` | SRS-F-01-04 |
| 절세 알림 임계치 | 한도 미달률 ≥ 20% | SRS-F-05-03 |

---

## 6. 사용자 개인 정보 (최초 입력용)

최초 로그인 후 설정 마법사에서 수집:
- 표시 이름, 타임존(`Asia/Seoul`), 통화(`KRW`)
- 연령, 부양 가족 (자녀 2023년생 — 교육비 목표 2041년 시드)
- 주 소득 원천 (급여·배당·기타)
- 보유 금융 상품 (IRP/연금저축/청약저축 가입 여부)
- 월 예산 초기값 (카테고리별)

※ 위 정보는 모두 Beelink 로컬 DB에 저장. Supabase에는 표시 이름만 저장.

---

## 7. 외부 데이터 소스

| # | 소스 | 용도 | 연동 방식 |
|---|---|---|---|
| 1 | 국세청 공지 RSS | `tax_rules` 변경 감지 | OpenClaw HTTP fetch, 주 1회 |
| 2 | 국세청 종합소득세 계산기 | `tax/estimate` 검증 골든셋 | 수동 추출 20건 |
| 3 | KOSPI/KOSDAQ 시세 (Phase 2) | 포트폴리오 수익률 | 미정 (pykrx vs. 증권사 API) |

---

## 8. 법·세제 레퍼런스 (결정 필요)

- [ ] `tax_rules.value` JSON 스키마 버전 관리 정책 (DB-SCHEMA §7)
- [ ] 세액 골든셋 20건 출처: **국세청 샘플 vs. 본인 2025년 실 자료**
- [ ] 신용카드 공제율·한도 2026년 개정 반영 일자 확정

---

## 9. 남은 의사결정 (문서별)

| 출처 | 미결 항목 |
|---|---|
| SRS §10 | AES-256 키 로테이션 주기, Supabase Free Tier 초과 시 폴백, OpenClaw 재시도 정책, 세액 골든셋 출처 |
| DB-SCHEMA §7 | `external_ref` 포맷, `tax_rules.value` 스키마 버전, 백업 주기(pg_dump vs. WAL), Supabase Row 정리 |
| ARCH §13 | RN 전환 트리거, Beelink 장애 콜드 스탠바이, OpenClaw 재시도, Sentry 샘플링 |
| ADR-006 | PWA→RN 전환 조건, 코드 공유 경계 |

---

## 10. 상태 요약

| 범주 | 준비 완료 | 진행 중 | 대기 |
|---|---|---|---|
| 계정·서비스 | 1 (GitHub) | - | 8 |
| 하드웨어 | - | - | 6 |
| 비밀·설정 | - | - | 전체 |
| DB 시드 | - | - | 4 |
| 의사결정 | - | - | 13 |

M5 착수 가능 조건: **§1 1~4**(Supabase/Vercel/Cloudflare/도메인) + **§2 1~5**(Beelink 설치) + **§3.1 keychain 키 3종** 완료.

---

## 변경 이력
| 날짜 | 버전 | 내용 |
|---|---|---|
| 2026-04-19 | v0.1 | 초안 — 계정/하드웨어/비밀/시드/의사결정 체크리스트 |
