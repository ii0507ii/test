# ADR 인덱스

본 디렉터리는 Owen's PLM 아키텍처 결정 기록(Architecture Decision Record)을 보관한다.

## 포맷
각 ADR은 다음 구조를 따른다: **맥락 → 결정 → 결과 → 대안**.

## 상태 정의
- `Proposed`: 검토 중
- `Accepted`: 채택 — 구현·운영에 적용
- `Superseded by ADR-XXX`: 후속 ADR로 대체
- `Deprecated`: 더 이상 유효하지 않음

## 목록
| ID | 제목 | 상태 | 관련 요구사항 |
|---|---|---|---|
| [ADR-001](ADR-001-local-financial-data.md) | 재무 데이터 로컬 저장 (Beelink) | Accepted | NFR-02, FS-2026-001 |
| [ADR-002](ADR-002-supabase-auth-pm-only.md) | Supabase를 Auth + PM DB로만 사용 | Accepted | URD v0.2 |
| [ADR-003](ADR-003-modular-monolith.md) | Modular Monolith 채택 | Accepted | 유지보수성 |
| [ADR-004](ADR-004-cloudflare-tunnel.md) | Cloudflare Tunnel over 포트포워딩 | Accepted | NFR-02, NFR-05 |
| [ADR-005](ADR-005-pgcrypto-encryption.md) | pgcrypto `pgp_sym_encrypt` 선택 | Accepted | SRS-N-02-04 |
| [ADR-006](ADR-006-pwa-to-rn-roadmap.md) | PWA(Phase 1) → React Native(Phase 3) 로드맵 | Proposed | NFR-01 |
| [ADR-007](ADR-007-openclaw-readonly.md) | OpenClaw 읽기 전용 역할 | Accepted | 리스크 대응 |
