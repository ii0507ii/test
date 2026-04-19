# SRS — 재무 관리사 Warboy (Owen's PLM)

- **문서 ID**: SRS-2026-001
- **버전**: v0.1 (초안)
- **작성일**: 2026-04-19
- **작성자**: Owen (바이브 코딩 w. Claude)
- **상위 문서**: URD v0.2, FS-2026-001
- **대상 마일스톤**: M3 (2026-04-29)
- **범위**: Phase 1 MVP (FR-01, FR-05, NFR-01/02/04/05)

---

## 1. 개요

### 1.1 목적
본 문서는 URD v0.2에서 정의된 사용자 요구사항을 시스템 수준 요구사항으로 구체화한다. V-Model의 설계·구현 단계와 검증(AT)의 기준선을 제공한다.

### 1.2 범위
Phase 1 MVP 대상 기능(FR-01, FR-05) 및 전 Phase 공통 비기능(NFR-01, 02, 04, 05)을 다룬다. Phase 2 기능(FR-02~04, NFR-03)은 §9 부록 "Phase 2 Forward Hooks"에서 인터페이스 여지만 기술한다.

### 1.3 용어
| 용어 | 정의 |
|---|---|
| PLM | Personal Lifecycle Manager — 본 시스템의 정식 명칭 |
| Beelink | 재무 데이터 로컬 호스트 (Beelink SER9 Pro) |
| OpenClaw | 로컬 자동화 에이전트 (국세청/금융 데이터 모니터링) |
| Cowork | PM 자동화 도우미 (주간 보고서, 스프린트 계획) |
| 재무 DB | Beelink 로컬 PostgreSQL (거래/예산/세제/포트폴리오) |
| PM DB | Supabase PostgreSQL (프로젝트 관리·인증 전용) |

---

## 2. 시스템 개요

### 2.1 아키텍처 요약
```
[사용자] ─► [Vercel PWA] ─► Cloudflare Tunnel ─► [Beelink SER9 Pro]
                  │                                  ├ API (Node.js/FastAPI)
                  │                                  ├ PostgreSQL (재무)
                  │                                  ├ OpenClaw
                  │                                  └ Owen's PLM + Cowork
                  └─► [Supabase] ─ Auth · PM DB
```

### 2.2 핵심 원칙
- **재무 개인정보 로컬화**: 모든 재무 데이터는 Beelink 로컬 PostgreSQL에만 저장.
- **PM 데이터 클라우드화**: 태스크·마일스톤·리뷰 로그만 Supabase에 저장.
- **인증 일원화**: Supabase Auth JWT를 Beelink API가 검증하여 재무 데이터 접근 허용.

---

## 3. 시스템 요구사항 — Functional

### 3.1 FR-01 월별 수입/지출 추적
유도 URD: FR-01. 우선순위: 높음.

| ID | 시스템 요구사항 | 수용 기준 |
|---|---|---|
| SRS-F-01-01 | 거래 입력 API: `POST /api/transactions` — 필드: `date`, `type(income/expense)`, `category_id`, `amount`, `memo` | 유효 필드 저장 성공률 100%, 필수 누락 시 400 반환 |
| SRS-F-01-02 | 월별 수지 집계 API: `GET /api/reports/monthly?yyyymm=...` | 집계 결과 = 거래합계 (오차 0원), 응답 ≤ 500ms |
| SRS-F-01-03 | 예산 설정 API: `POST /api/budgets` — 필드: `yyyymm`, `category_id`, `limit_amount` | 월·카테고리 당 단일 레코드, UPSERT 지원 |
| SRS-F-01-04 | OpenClaw 예산 초과 알림: 일간 스캔으로 `지출 ≥ 예산 × 0.9` 시 PWA Push | 알림 누락 0건 / 일 (단위 테스트 기준) |
| SRS-F-01-05 | 대시보드 카드: 당월 수입/지출/잔액/Top 3 지출 카테고리 표시 | Lighthouse 성능 점수 ≥ 80 |

### 3.2 FR-05 연말정산 세제 혜택 최적화
유도 URD: FR-05. 우선순위: 높음.

| ID | 시스템 요구사항 | 수용 기준 |
|---|---|---|
| SRS-F-05-01 | 공제 항목 CRUD API: `/api/tax-deductions` — IRP·연금저축·청약저축·신용카드 등 | 항목당 연도별 이력 관리 |
| SRS-F-05-02 | 세액 재계산 엔진: 공제 항목 변경 이벤트 ≤ 200ms 내 예상 환급액 재계산 | 테스트 케이스 20건 오차 ≤ 1,000원 |
| SRS-F-05-03 | 절세 액션 알림: 연말 3개월 전 미달 공제 한도 감지 시 알림 | 한도 미달률 ≥ 20% 시 알림 발생 |
| SRS-F-05-04 | 세제 룰셋 버전 관리: `tax_rules` 테이블에 연도별 규칙 저장 | 연도 전환 시 과거 계산 이력 불변 |
| SRS-F-05-05 | 세법 변경 모니터링: OpenClaw가 국세청 공지 주 1회 스캔, 변경 감지 시 관리자 알림 | 주간 스캔 실패 0건 / 월 |

---

## 4. 시스템 요구사항 — Non-Functional

| ID | 유도 URD | 시스템 요구사항 | 측정 기준 |
|---|---|---|---|
| SRS-N-01-01 | NFR-01 | PWA 매니페스트 + Service Worker로 오프라인 읽기 지원 | iOS/Android/Desktop Chrome 3개 플랫폼 동작 |
| SRS-N-01-02 | NFR-01 | 반응형 UI (320px ~ 1920px) | 시각 회귀 테스트 통과 |
| SRS-N-02-01 | NFR-02 | Supabase Auth 이메일/비밀번호 + OTP | 인증 실패 로그 기록 |
| SRS-N-02-02 | NFR-02 | Beelink API는 JWT `aud=owen-plm` 검증 후 요청 수락 | 미검증 요청 100% 거부 |
| SRS-N-02-03 | NFR-02 | OpenClaw DB 계정은 `SELECT` 권한만 보유 | DDL/DML 시도 시 실패 및 감사 로그 |
| SRS-N-02-04 | NFR-02 | 재무 DB 저장 시 `amount`·`memo` 열 AES-256 암호화 (at rest) | 복호화 키는 Beelink 로컬 Keychain |
| SRS-N-04-01 | NFR-04 | 대시보드 Time-to-Interactive ≤ 3초 (4G 기준) | Lighthouse ≥ 80 |
| SRS-N-04-02 | NFR-04 | API P95 ≤ 500ms (로컬 네트워크) | k6 부하 테스트 RPS 20 |
| SRS-N-05-01 | NFR-05 | Vercel Preview → Production 자동 배포 (main push) | 배포 실패 롤백 자동 |
| SRS-N-05-02 | NFR-05 | Cloudflare Tunnel Uptime ≥ 99% / 월 | UptimeRobot 5분 간격 모니터 |

---

## 5. 외부 인터페이스

### 5.1 API 요약 (Beelink)
| 경로 | 메서드 | 설명 | 인증 |
|---|---|---|---|
| `/api/transactions` | GET/POST/PUT/DELETE | 거래 CRUD | JWT |
| `/api/categories` | GET/POST/PUT | 카테고리 | JWT |
| `/api/budgets` | GET/POST | 월별 예산 | JWT |
| `/api/tax-deductions` | GET/POST/PUT | 공제 항목 | JWT |
| `/api/tax/estimate` | POST | 환급액 재계산 | JWT |
| `/api/reports/monthly` | GET | 월별 수지 집계 | JWT |
| `/health` | GET | 헬스 체크 | 없음 |

### 5.2 인증 흐름
1. PWA → Supabase Auth 로그인 → JWT 수신
2. PWA → Cloudflare Tunnel → Beelink API 호출 (`Authorization: Bearer <JWT>`)
3. Beelink API가 Supabase JWKS로 서명 검증 → 사용자 ID 추출 → RLS 적용

### 5.3 OpenClaw 연동
- 국세청 공지 RSS/스크레이퍼 주 1회 실행
- 변경 감지 시 `tax_rules_changelog` INSERT + 관리자 Push
- 재무 DB 접근 계정: `openclaw_ro` (SELECT only)

---

## 6. 데이터 요구사항 (요약 스키마, 상세는 DB-SCHEMA-001에서)

| 테이블 | 위치 | 주요 컬럼 |
|---|---|---|
| `users` | Supabase | `id`, `email`, `created_at` |
| `transactions` | Beelink | `id`, `user_id`, `date`, `type`, `category_id`, `amount_enc`, `memo_enc` |
| `categories` | Beelink | `id`, `user_id`, `name`, `parent_id` |
| `budgets` | Beelink | `user_id`, `yyyymm`, `category_id`, `limit_amount` (PK 복합) |
| `tax_deductions` | Beelink | `id`, `user_id`, `year`, `type`, `amount`, `evidence_url` |
| `tax_rules` | Beelink | `year`, `rule_key`, `value`, `effective_from` |
| `tax_rules_changelog` | Beelink | `id`, `rule_key`, `old_value`, `new_value`, `source_url`, `detected_at` |
| `audit_log` | Beelink | `id`, `actor`, `action`, `target`, `at` |

---

## 7. 검증 전략 (V-Model RHS 대응)

| 요구사항 ID | 검증 방법 | 산출물 |
|---|---|---|
| SRS-F-01-01~05 | 단위 + 통합 테스트 | `tests/transactions/`, Playwright 대시보드 시나리오 |
| SRS-F-05-01~05 | 케이스 기반 회귀 테스트 (세액 20건 골든셋) | `tests/tax/fixtures/` |
| SRS-N-02-01~04 | 보안 리뷰 체크리스트 + OWASP ZAP 스캔 | `security/zap-baseline.md` |
| SRS-N-04-01~02 | Lighthouse CI, k6 부하 | `perf/reports/` |
| SRS-N-05-01~02 | 배포 smoke test + UptimeRobot 리포트 | 월간 운영 보고서 |

---

## 8. 추적성 매트릭스

| URD | SRS |
|---|---|
| FR-01 | SRS-F-01-01 ~ 05 |
| FR-05 | SRS-F-05-01 ~ 05 |
| NFR-01 | SRS-N-01-01 ~ 02 |
| NFR-02 | SRS-N-02-01 ~ 04 |
| NFR-04 | SRS-N-04-01 ~ 02 |
| NFR-05 | SRS-N-05-01 ~ 02 |

---

## 9. 부록 — Phase 2 Forward Hooks

Phase 2 구현 시 영향이 큰 인터페이스 포인트만 명시. 실제 요구사항은 SRS v0.3에서 확장.

- **FR-02 (투자 포트폴리오)**: `portfolios`, `holdings` 테이블 자리 예약, `/api/portfolios` 네임스페이스 보전.
- **FR-03 (목표 저축)**: `goals` 테이블 (목표일, 목표액, 자동 기여율) 예약. 2041년 자녀 교육비 기본 목표로 시드.
- **FR-04 (대출/부채)**: `loans` + `loan_schedule` 스키마 예약. 원리금 균등/원금 균등 분기 계산기 모듈화.
- **NFR-03 (멀티 유저)**: `transactions.user_id` 인덱스 유지, RLS 정책을 `household_id` 기반으로 확장 가능하게 설계.

---

## 10. 미결 사항

- [ ] AES-256 키 로테이션 주기 확정 (후보: 연 1회 + 수동 트리거)
- [ ] Supabase Free Tier 사용량 초과 시 폴백 전략
- [ ] OpenClaw 스캔 실패 재시도 정책 (지수 백오프 vs. 고정 간격)
- [ ] 세액 계산 골든셋 출처 확정 (국세청 샘플 vs. 전년 본인 자료)

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|---|---|---|
| 2026-04-19 | v0.1 | 초안 작성 — Phase 1 MVP 범위 |
