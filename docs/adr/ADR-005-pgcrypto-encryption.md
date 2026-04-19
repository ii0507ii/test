# ADR-005 — pgcrypto `pgp_sym_encrypt` 선택

- **상태**: Accepted
- **일자**: 2026-04-19
- **관련**: SRS-N-02-04, DB-SCHEMA v0.1 §1.3

## 맥락
`transactions.amount`, `transactions.memo`는 가장 민감한 컬럼이다. Beelink OS 전체 디스크 암호화(LUKS)로 데이터가 at-rest 보호되지만, 이는 전원 차단 시점에만 유효하다. DB가 가동 중 노출(메모리 덤프, 백업 파일 유출)되는 경우에도 데이터가 평문이 아니어야 한다.

## 결정
PostgreSQL `pgcrypto` 확장의 **`pgp_sym_encrypt()` / `pgp_sym_decrypt()`**로 컬럼 단위 대칭키 암호화를 적용한다.
- 저장: `amount_enc bytea`, `memo_enc bytea`
- 키는 Beelink OS Keychain(`secret-tool`)에 보관, 애플리케이션 시작 시 세션 변수 `app.enc_key`로 주입
- 복호화는 뷰 `v_transactions`에서만 수행 (일반 SELECT는 뷰 경유)
- 키 로테이션: 연 1회 + 수동 트리거. 신규 컬럼 + 백필 방식 (컬럼 타입 변경 금지)

## 결과
**긍정**
- DB 파일·백업 유출 시에도 평문 노출 없음
- 애플리케이션 계정(`owen_plm_app`)의 DB 권한만으로는 복호화 불가 (키 보유자 분리)
- 표준 PostgreSQL 확장 — 서드파티 라이브러리 없음

**부정 / 비용**
- 인덱스 기반 범위 조회(`WHERE amount > X`) 불가 → 모든 금액 필터는 애플리케이션 또는 복호화 후 처리
- 집계 쿼리는 `v_transactions` 경유로 인해 CPU 비용 증가 → 월 데이터량이 작아 허용
- 키 분실 시 데이터 복구 불가 → 오프라인 2부 백업 필수

## 대안
1. **애플리케이션 레이어 AES-GCM**: 라이브러리·키 주입 복잡도 유사하나 SQL 집계 시 전량 복호화 필요.
2. **Transparent Data Encryption (pg_tde 등)**: 파일 수준만 보호 → LUKS와 중복 효용, 컬럼 노출 리스크 해소 불가.
3. **암호화 미적용**: SRS-N-02-04 위배.
