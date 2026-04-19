# Architecture Design — 재무 관리사 Warboy (Owen's PLM)

- **문서 ID**: ARCH-2026-001
- **버전**: v0.1 (초안)
- **작성일**: 2026-04-19
- **상위 문서**: URD v0.2, SRS v0.1, DB-SCHEMA v0.1, FS-2026-001
- **대상 마일스톤**: M4 (2026-05-20)
- **범위**: Phase 1 MVP (FR-01, FR-05) 구현에 필요한 전 계층 아키텍처

---

## 1. 목표와 제약

### 1.1 아키텍처 품질 속성 (우선순위)
1. **기밀성** — 재무 데이터 유출 방지 (로컬 격리 + 암호화)
2. **가용성** — 단일 사용자 기준 99% Uptime
3. **유지보수성** — 주 5시간 개발 예산 내 Phase 2 확장
4. **성능** — 대시보드 TTI ≤ 3초, API P95 ≤ 500ms
5. **이식성** — Phase 3 React Native 전환 용이성

### 1.2 제약 사항
- 호스트: Beelink SER9 Pro 단일 머신 (HA 구성 불가)
- 네트워크: 가정용 인터넷 (동적 IP, NAT) → Cloudflare Tunnel로 우회
- 예산: 월 운영비 ≤ 32,000원
- 개발 공수: 주 5시간 × 18주 (MVP)

---

## 2. 아키텍처 스타일

**Modular Monolith + Edge PWA**

- 백엔드: Beelink 상의 단일 프로세스(Node.js) 내 모듈 경계 — `finance`, `tax`, `openclaw-sync`, `auth-verify`
- 프런트엔드: Vercel Edge의 PWA (React + Vite) — 오프라인 읽기 캐시
- 외부 관리형: Supabase Auth/PM DB, Cloudflare Tunnel

선택 이유: 단일 개발자·단일 사용자 환경에서 MSA의 운영 복잡도는 가치 대비 과잉. 모듈 경계만 명확히 유지하여 훗날 분리 옵션을 보존.

---

## 3. 시스템 구성도

### 3.1 컨테이너 레벨 (C4)
```
┌────────────────┐       HTTPS        ┌─────────────────────────────┐
│  Browser /     │  ────────────────► │  Vercel PWA (React + Vite)  │
│  PWA Shell     │                    │  - Service Worker           │
└────────────────┘                    │  - Supabase JS SDK          │
                                      └────────────┬────────────────┘
                                                   │ JWT in header
                                                   ▼
                               ┌───────────────────────────────────┐
                               │  Cloudflare Tunnel                │
                               │  *.warboy.example.com             │
                               └───────────────┬───────────────────┘
                                               │ mTLS (origin)
                                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Beelink SER9 Pro (Ubuntu 24.04)             │
│                                                                  │
│  ┌─────────────────────┐      ┌──────────────────────────────┐   │
│  │ API Gateway         │      │ PostgreSQL 16 (재무 DB)      │   │
│  │ (Node.js / Fastify) │◄────►│  - pgcrypto                  │   │
│  │  - /api/*           │      │  - v_transactions view       │   │
│  │  - JWT verify       │      └──────────────────────────────┘   │
│  │  - Rate limit       │                 ▲                       │
│  └──────────┬──────────┘                 │                       │
│             │                            │ SELECT only           │
│             ▼                            │                       │
│  ┌─────────────────────┐      ┌──────────┴───────────────────┐   │
│  │ Finance Module      │      │ OpenClaw Agent               │   │
│  │ Tax Module          │      │  - 국세청 RSS/스크래퍼         │   │
│  │ Notification Module │      │  - 주 1회 cron               │   │
│  └─────────────────────┘      └──────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘

           ┌────────────────────────────────────────────┐
           │  Supabase (관리형)                          │
           │  - Auth (JWT, JWKS)                        │
           │  - PM DB: pm_projects, pm_tasks …          │
           └────────────────────────────────────────────┘
```

### 3.2 모듈 레벨 (Beelink API)
| 모듈 | 책임 | 주요 의존 |
|---|---|---|
| `http/gateway` | 라우팅, JWT 검증, Rate Limit, 감사 로깅 | Fastify, jose |
| `finance` | 거래/카테고리/예산 CRUD, 집계 | PostgreSQL (`v_transactions`) |
| `tax` | 공제 항목, 환급액 계산, 룰셋 조회 | `tax_rules`, 룰 엔진 |
| `crypto` | `amount`/`memo` 암복호화 래퍼 | pgcrypto, OS Keychain |
| `openclaw-sync` | 국세청 변경 감지 → `tax_rules_changelog` | cron, HTTP client |
| `notification` | Push 발송 (Web Push VAPID) | `web-push` |

모듈 간 호출은 함수 레벨 import만 허용. 순환 의존 금지는 `madge`로 CI 검사.

---

## 4. 배포 아키텍처

### 4.1 환경 분리
| 환경 | 용도 | 데이터 |
|---|---|---|
| `local-dev` | 개발 PC | Docker Compose PostgreSQL (더미) |
| `beelink-staging` | Beelink 내 별도 포트·DB | 익명화 데이터 |
| `beelink-prod` | Beelink 본 서비스 | 실 데이터 |

### 4.2 배포 파이프라인
```
GitHub Push (main)
   ├─► Vercel: PWA 빌드 & 배포 (자동)
   │     └─ E2E Smoke (Playwright)
   └─► GitHub Action: SSH → Beelink
         ├─ pg dump (백업)
         ├─ docker compose pull && up -d
         └─ /health 체크 → 실패 시 롤백
```

### 4.3 네트워킹
- **Cloudflare Tunnel**: Beelink `cloudflared` 데몬이 Outbound 연결만 사용 → 포트 개방 불필요
- **Origin mTLS**: Cloudflare → Beelink 구간 상호 인증서 검증
- **CORS**: Vercel 도메인과 `localhost:5173`만 허용

---

## 5. 데이터 흐름 (End-to-End)

### 5.1 거래 입력 (FR-01)
```
사용자 입력 → PWA Form 검증
  → Supabase SDK로 현재 JWT 취득
  → fetch('https://api.warboy.example.com/api/transactions', JWT)
      → Cloudflare Edge → Tunnel → Beelink Fastify
      → http/gateway: JWT 서명/클레임 검증 (JWKS 캐시 1h)
      → finance.createTransaction(userId, payload)
      → crypto.encrypt(amount, memo) [세션 키]
      → INSERT INTO transactions
      → audit_log INSERT (비동기)
  → 201 응답 + 낙관적 UI 업데이트
  → Service Worker IndexedDB 캐시 갱신
```

### 5.2 월별 집계 조회 (FR-01)
```
대시보드 open → GET /api/reports/monthly?yyyymm=202604
  → finance.monthlyReport(userId, 202604)
      → SELECT FROM v_transactions WHERE auth_user_id=$1 AND tx_date BETWEEN ...
      → 카테고리별 집계 (SQL GROUP BY)
  → 200 응답 (gzip)
  → Chart.js 렌더링
```

### 5.3 세법 변경 감지 (FR-05)
```
Cron (월~일 06:00 KST)
  → openclaw-sync.scan()
      → 국세청 RSS fetch
      → 차분 계산 vs. tax_rules 현재값
      → INSERT tax_rules_changelog
      → notification.push(admin, '세법 변경 감지')
  → UI: 다음 접속 시 배너 + 재계산 안내
```

---

## 6. 보안 아키텍처

### 6.1 경계
1. **Edge 경계** (Cloudflare): DDoS, WAF, Rate Limit, TLS 종단
2. **Tunnel 경계**: Outbound-only, Origin 인증서
3. **앱 경계** (Fastify): JWT 검증, CSRF (same-origin 강제), Input schema
4. **DB 경계**: 역할 분리(`owen_plm_app`, `openclaw_ro`), pgcrypto 암호화
5. **물리 경계**: Beelink OS 전체 디스크 암호화(LUKS)

### 6.2 Secrets 관리
| 비밀 | 저장소 | 접근 |
|---|---|---|
| 재무 DB 암호화 키 | Beelink OS Keychain (`secret-tool`) | 애플리케이션 시작 시 주입 |
| Supabase 서비스 키 | Beelink `.env` (600 권한) | systemd EnvironmentFile |
| Vercel 환경변수 | Vercel Dashboard | 빌드/런타임 |
| VAPID 키 | Beelink OS Keychain | notification 모듈 |

### 6.3 위협 모델 요약 (STRIDE)
| 위협 | 대응 |
|---|---|
| Spoofing (타 사용자) | Supabase JWT + `aud` 검증 |
| Tampering (DB) | pgcrypto 암호화, audit_log |
| Repudiation | audit_log (actor/action) |
| Information Disclosure | 로컬 격리, TLS, LUKS |
| Denial of Service | Cloudflare Rate Limit + Fastify `@fastify/rate-limit` |
| Elevation of Privilege | 역할 분리, OpenClaw 읽기 전용 |

---

## 7. 성능 설계

### 7.1 목표 대비 전략
| 목표 | 전략 |
|---|---|
| 대시보드 TTI ≤ 3초 | Vite 코드 스플리팅, Edge 캐시, Service Worker precache |
| API P95 ≤ 500ms | 로컬 네트워크, 인덱스(`idx_tx_user_date`), 집계 쿼리 pre-aggregation 여지 |
| Lighthouse ≥ 80 | 이미지 최적화, 미사용 JS 제거, font-display: swap |

### 7.2 캐싱 계층
| 계층 | 대상 | TTL |
|---|---|---|
| Cloudflare | 정적 PWA assets | 1y (hashed) |
| Service Worker | 대시보드 마지막 스냅샷 | 24h stale-while-revalidate |
| Fastify 인메모리 | `tax_rules` 현재년 | 10분 |
| Supabase JWKS | JWT 검증 공개키 | 1h |

---

## 8. 가용성 & 운영

### 8.1 백업
| 대상 | 주기 | 대상소 |
|---|---|---|
| 재무 DB | 일 1회 `pg_dump` | 외장 SSD (LUKS) |
| WAL | 지속적 아카이빙 | 외장 SSD |
| Supabase PM DB | 일 1회 Supabase 자동 백업 | 관리형 |
| 재무 DB 암호화 키 | 연 1회 로테이션 + 수동 백업 | 오프라인 매체 2부 |

### 8.2 모니터링
- **UptimeRobot**: `/health` 5분 간격
- **Beelink 로컬**: `node_exporter` + `prometheus` + `grafana` (로컬 뷰만)
- **에러 트래킹**: Sentry (Free Tier, PII 스크러빙 활성)
- **알림 채널**: Telegram Bot (운영자 개인용)

### 8.3 장애 시나리오 Runbook
| 장애 | 감지 | 대응 |
|---|---|---|
| Cloudflare Tunnel 다운 | UptimeRobot | `cloudflared` 재시작 → 안 되면 임시 Tailscale |
| PostgreSQL crash | systemd alert | WAL 복구 후 재시작, 직전 `pg_dump`로 복원 |
| Beelink 전원 장애 | UPS 알림 | 배터리 지속 중 안전 종료 |
| Supabase Auth 장애 | 로그인 실패 모니터 | 읽기 전용 모드(로컬 캐시) 유지, Supabase Status 주시 |

---

## 9. 기술 스택 결정 (요약)

| 영역 | 선택 | 대안 | 선택 이유 |
|---|---|---|---|
| PWA 프레임워크 | React + Vite | Next.js | SSR 불필요, 빌드 속도 |
| API 프레임워크 | Fastify | Express | 스키마 검증 + 성능 |
| DB | PostgreSQL 16 | SQLite | 동시성, pgcrypto |
| Auth | Supabase | Auth0, 자체 | 비용 0, JWKS 제공 |
| PM DB | Supabase | Notion API | RLS, SQL 접근성 |
| 배포 프런트 | Vercel | Cloudflare Pages | 현 워크플로 익숙 |
| Tunnel | Cloudflare | ngrok, Tailscale Funnel | 무료, 도메인 연결 |
| 자동화 에이전트 | OpenClaw | n8n | 로컬 설치 + 읽기 전용 계정 쉬움 |
| Cron | systemd timer | node-cron | OS 표준, 로그 일원화 |

---

## 10. 아키텍처 결정 기록 (ADR 인덱스)

| ID | 제목 | 상태 |
|---|---|---|
| ADR-001 | 재무 데이터 로컬 저장 (Beelink) | Accepted (FS-2026-001) |
| ADR-002 | Supabase를 Auth + PM DB로만 사용 | Accepted (URD v0.2) |
| ADR-003 | Modular Monolith 채택 | Accepted (본 문서) |
| ADR-004 | Cloudflare Tunnel over 포트포워딩 | Accepted (본 문서) |
| ADR-005 | pgcrypto `pgp_sym_encrypt` 선택 | Accepted (DB-SCHEMA v0.1) |
| ADR-006 | PWA(Phase 1) → React Native(Phase 3) 로드맵 | Proposed |
| ADR-007 | OpenClaw 읽기 전용 역할 | Accepted (본 문서) |

각 ADR은 `docs/adr/ADR-XXX-*.md`로 후속 작성.

---

## 11. 리스크 매핑 (URD 리스크 → 아키텍처 대응)

| URD 리스크 | 본 문서 대응 섹션 |
|---|---|
| 세법 변경 | §5.3 OpenClaw, §7.2 `tax_rules` 캐시 |
| 금융 데이터 보안 취약점 | §6 전체 |
| 멀티 플랫폼 호환성 | §9 React + PWA, ADR-006 |
| 사이드 프로젝트 시간 부족 | §2 Modular Monolith (경량 운영) |
| OpenClaw 보안 리스크 | §6.1(4), §9 읽기 전용 역할 |

---

## 12. 구현 작업 분해 (M4 → M5 이관)

- [ ] ADR-001 ~ 007 문서화 (`docs/adr/`)
- [ ] Fastify 스캐폴딩 + JWT 검증 미들웨어
- [ ] `crypto` 모듈 + 키 로딩 유틸 (`secret-tool` 연동)
- [ ] `finance.createTransaction` + `monthlyReport` 구현
- [ ] Vercel 프로젝트 생성 + Cloudflare Tunnel 설정
- [ ] UptimeRobot · Sentry 연동
- [ ] E2E Playwright 로그인 → 거래 입력 → 대시보드 시나리오

---

## 13. 미결 사항

- [ ] React Native 전환 시점: Phase 3 기본 vs. 사용자 피드백 트리거
- [ ] Beelink 하드웨어 장애 시 대체 경로 (콜드 스탠바이 VPS?)
- [ ] OpenClaw 실패 재시도: 지수 백오프(최대 24h) vs. 고정 6h
- [ ] Sentry Free Tier 이벤트 한도 도달 시 샘플링 비율

---

## 변경 이력
| 날짜 | 버전 | 내용 |
|---|---|---|
| 2026-04-19 | v0.1 | 초안 — 컨테이너/모듈/배포/보안/운영 전 계층 |
