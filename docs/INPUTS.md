# Inputs — 구현 착수 전 준비 사항

- **문서 ID**: INPUTS-2026-001 · **버전**: v0.2 (시각화) · **작성일**: 2026-04-19
- **목적**: M5(MVP 구현) 착수 전에 사용자가 준비·제공해야 할 정보·계정·하드웨어를 한 곳에 정리

---

## 📊 한눈에 보기

```
전체 준비 현황 (총 24개 항목)

계정·서비스   ▓░░░░░░░░░ 11%   1 / 9   ✅ GitHub
하드웨어      ░░░░░░░░░░  0%   0 / 6   ⬜ Beelink·SSD·UPS·OS·LUKS·SSH
비밀·설정     ░░░░░░░░░░  0%   0 / 3   ⬜ Keychain 키 3종
DB 시드       ░░░░░░░░░░  0%   0 / 4   ⬜ categories·tax_rules·pm_*
의사결정      ░░░░░░░░░░  0%   0 / 13  ⬜ SRS/DB/ARCH/ADR 미결

총 진행률    ▓░░░░░░░░░  4%   1 / 35
```

> 🔴 **블로커**: §1 1~4 (Supabase·Vercel·Cloudflare·도메인) 미완 → M5 착수 불가
> 🟡 **선행 필요**: §2 1~5 (Beelink 셋업) → 모든 백엔드 작업의 전제

---

## 🗺️ 의존성 맵 (M5 착수까지)

```mermaid
flowchart LR
    classDef done fill:#d4f4dd,stroke:#2a9d4f,color:#0a3d1f
    classDef todo fill:#fde7e7,stroke:#c44,color:#5c0d0d
    classDef wait fill:#fff3cd,stroke:#d4a017,color:#5c4400

    GH[GitHub Repo]:::done

    subgraph 클라우드 계정
      SB[Supabase 프로젝트]:::todo
      VC[Vercel 프로젝트]:::todo
      CF[Cloudflare 계정]:::todo
      DOM[소유 도메인]:::todo
    end

    subgraph 하드웨어
      HW[Beelink SER9 Pro]:::todo
      OS[Ubuntu 24.04 + LUKS]:::todo
      KC[OS Keychain 키 3종]:::todo
    end

    subgraph 부가
      VAPID[VAPID 키 페어]:::wait
      SENT[Sentry DSN]:::wait
      UR[UptimeRobot]:::wait
      TG[Telegram Bot]:::wait
    end

    SB --> KC
    DOM --> CF
    HW --> OS --> KC
    KC --> M5[🚀 M5 착수]
    SB --> M5
    VC --> M5
    CF --> M5
    DOM --> M5
    VAPID -.-> M5
    SENT -.-> M5
    UR -.-> M5
    TG -.-> M5
    GH --> M5
```

---

## 💰 비용 시각화

```
초기 투자 (~740,000원)
Beelink SER9 Pro      ████████████████████████  600,000원  ████ 81%
외장 SSD 512GB        ███                        60,000원  ▏     8%
UPS (선택)            ████                       80,000원  ▎    11%

월 운영비 (~32,000원)
Claude Max            █████████████              28,000원  ████ 88%
Beelink 전기 (24/7)   ██                          4,000원  ▏    12%
Supabase Free          —                              0원
Vercel Hobby           —                              0원
Cloudflare Tunnel      —                              0원
```

---

## 1. 🌐 계정 & 외부 서비스 (1/9)

| # | 항목 | 상태 | 필요한 값 | 비고 |
|---|---|:---:|---|---|
| 1 | Supabase 프로젝트 | 🔴 | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Free Tier · **블로커** |
| 2 | Vercel 프로젝트 | 🔴 | 팀·프로젝트명, GitHub 연결 | Hobby · **블로커** |
| 3 | Cloudflare 계정 | 🔴 | 이메일, API Token (Zone:DNS:Edit) | 무료 · **블로커** |
| 4 | 소유 도메인 | 🔴 | `warboy.example.com` (실 도메인 교체) | Cloudflare DNS 위임 · **블로커** |
| 5 | GitHub 저장소 | ✅ | `ii0507ii/test` | 현재 |
| 6 | Sentry 프로젝트 | 🟡 | `SENTRY_DSN` | Free Tier (PII 스크러빙) |
| 7 | UptimeRobot | 🟡 | 모니터 URL 2개(`/health`, PWA) | 무료 5분 |
| 8 | Telegram Bot | 🟡 | `TG_BOT_TOKEN`, `TG_CHAT_ID` | 운영자 알림 |
| 9 | VAPID 키 페어 | 🟡 | Public/Private | `npx web-push generate-vapid-keys` |

> 🔴 블로커  ·  🟡 출시 전까지 필요  ·  ✅ 완료

---

## 2. 🖥️ 하드웨어 & 로컬 환경 (0/6)

| # | 항목 | 상태 | 비용 | 비고 |
|---|---|:---:|---:|---|
| 1 | Beelink SER9 Pro | 🔴 | ~600,000원 | Ryzen 7 H 255 |
| 2 | 외장 SSD 512GB+ | 🔴 | ~60,000원 | pg_dump · WAL 백업 |
| 3 | UPS (선택) | 🟡 | ~80,000원 | 정전 안전 종료 |
| 4 | Ubuntu 24.04 LTS | 🔴 | 0원 | 서버 에디션 권장 |
| 5 | LUKS 전체 디스크 암호화 | 🔴 | 0원 | 설치 단계에서 활성 |
| 6 | SSH 키 페어 | 🟡 | 0원 | GitHub Action 배포용 |

---

## 3. 🔐 비밀(Secrets) 체크리스트

> ⚠️ 값은 Keychain/Vercel/GitHub Secrets에 저장. **소스 코드·Notion·Slack 공유 금지**.

### 3.1 Beelink OS Keychain (`secret-tool`) — 0/3
| 키 | 용도 | 생성 시점 |
|---|---|---|
| 🔴 `owen-plm.db.enc_key` | `pgcrypto` 대칭키 (amount/memo) | 최초 배포 (≥32자 random) |
| 🔴 `owen-plm.vapid.private` | Web Push VAPID Private | 9번 생성 후 주입 |
| 🔴 `owen-plm.supabase.service_role` | PM DB 마이그레이션 전용 | Supabase 가입 후 |

### 3.2 Beelink `.env` (권한 `600`)
```ini
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
| `BEELINK_SSH_HOST` | Tunnel 도메인 또는 로컬 접근 |
| `BEELINK_SSH_USER` | `owen` |
| `BEELINK_SSH_KEY` | 배포 전용 키 (pushable만) |
| `VERCEL_TOKEN` | (선택) CLI 배포용 |

---

## 4. 🌱 DB 시드 데이터 (0/4)

| 대상 | 파일(예정) | 상태 |
|---|---|:---:|
| `categories` 기본값 | `seeds/categories.sql` (10~15건) | 🔴 |
| `tax_rules` 2026년 | `seeds/tax_rules_2026.sql` | 🔴 |
| `pm_projects` 시드 | Supabase Studio 수동 | 🔴 |
| `pm_milestones` M0~M6 | 동일 (`docs/TASKS.md` §1 기반) | 🔴 |

---

## 5. ⚙️ 설정 값·상수

| 항목 | 값 | 출처 |
|---|---|---|
| 시간대 | `Asia/Seoul` | OS + `pg_settings` |
| 통화 | `KRW`, `BIGINT` 저장 | DB-SCHEMA §1.2 |
| 세션 만료 | Access 1h / Refresh 30d | Supabase 기본 |
| `tax_rules` 캐시 TTL | 10분 | ARCH §7.2 |
| JWKS 캐시 TTL | 1시간 | ARCH §7.2 |
| OpenClaw 스캔 주기 | 주 1회 (월 06:00 KST) | ARCH §5.3 |
| 예산 초과 임계치 | `지출 ≥ 예산 × 0.9` | SRS-F-01-04 |
| 절세 알림 임계치 | 한도 미달률 ≥ 20% | SRS-F-05-03 |

---

## 6. 👤 사용자 개인 정보 (최초 설정 마법사)

```
┌─ 기본 ───────────────────────────────────┐
│ 표시 이름 · 타임존(Asia/Seoul) · 통화(KRW) │
└──────────────────────────────────────────┘
┌─ 가족 ───────────────────────────────────┐
│ 자녀 2023년생 → 교육비 목표 2041년 시드     │
└──────────────────────────────────────────┘
┌─ 소득 ───────────────────────────────────┐
│ 급여 · 배당 · 기타                          │
└──────────────────────────────────────────┘
┌─ 금융 상품 ───────────────────────────────┐
│ IRP · 연금저축 · 청약저축 가입 여부            │
└──────────────────────────────────────────┘
┌─ 예산 ───────────────────────────────────┐
│ 카테고리별 월 예산 초기값                     │
└──────────────────────────────────────────┘
```

> 위 정보는 모두 **Beelink 로컬 DB**에 저장. Supabase에는 표시 이름만 저장.

---

## 7. 🔌 외부 데이터 소스

| # | 소스 | 용도 | 연동 방식 |
|---|---|---|---|
| 1 | 국세청 공지 RSS | `tax_rules` 변경 감지 | OpenClaw HTTP fetch · 주 1회 |
| 2 | 국세청 종합소득세 계산기 | `tax/estimate` 골든셋 | 수동 추출 20건 |
| 3 | KOSPI/KOSDAQ 시세 (Phase 2) | 포트폴리오 수익률 | 미정 (pykrx vs. 증권사 API) |

---

## 8. 📜 법·세제 레퍼런스 결정 필요

- [ ] `tax_rules.value` JSON 스키마 버전 관리 정책
- [ ] 세액 골든셋 20건 출처: **국세청 샘플 vs. 본인 2025년 실 자료**
- [ ] 신용카드 공제율·한도 2026년 개정 반영 일자

---

## 9. 🧭 남은 의사결정 (총 13건)

| 출처 | 미결 | 건수 |
|---|---|:---:|
| SRS §10 | AES-256 키 로테이션 / Supabase 한도 폴백 / OpenClaw 재시도 / 세액 골든셋 | 4 |
| DB-SCHEMA §7 | `external_ref` 포맷 / `tax_rules.value` 스키마 / 백업 주기 / Supabase Row 정리 | 4 |
| ARCH §13 | RN 전환 트리거 / Beelink 콜드 스탠바이 / OpenClaw 재시도 / Sentry 샘플링 | 4 |
| ADR-006 | PWA→RN 전환 조건 (코드 공유 경계 별도) | 1 |

---

## 10. 🚦 M5 착수 게이트

```mermaid
flowchart LR
    classDef gate fill:#fde7e7,stroke:#c44,color:#5c0d0d,stroke-width:2px
    classDef opt fill:#fff3cd,stroke:#d4a017,color:#5c4400

    G1[§1 1~4 클라우드 4종]:::gate
    G2[§2 1~5 Beelink 셋업]:::gate
    G3[§3.1 Keychain 3종]:::gate
    O1[§1 6~9 부가 서비스]:::opt
    O2[§4 시드 데이터]:::opt

    G1 --> READY[🚀 M5 착수]
    G2 --> READY
    G3 --> READY
    O1 -.후속.-> READY
    O2 -.후속.-> READY
```

---

## 변경 이력
| 날짜 | 버전 | 내용 |
|---|---|---|
| 2026-04-19 | v0.1 | 초안 |
| 2026-04-19 | v0.2 | 시각화 추가 (진행 차트·의존성 맵·비용 시각화·게이트 다이어그램) |
