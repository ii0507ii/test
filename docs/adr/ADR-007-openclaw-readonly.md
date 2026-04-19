# ADR-007 — OpenClaw 읽기 전용 역할

- **상태**: Accepted
- **일자**: 2026-04-19
- **관련**: URD 리스크 "OpenClaw 보안 리스크", SRS-N-02-03

## 맥락
OpenClaw는 국세청 공지 모니터링과 거래 분석을 위해 DB에 접근해야 한다. 범용 자동화 에이전트 특성상 **프롬프트 인젝션·의도치 않은 명령 실행** 가능성이 있어, 전체 재무 DB에 대해 쓰기 권한을 주면 치명적이다.

## 결정
OpenClaw 전용 DB 역할 **`openclaw_ro`**를 정의하고 다음 권한만 부여한다.
- `SELECT` on `transactions`, `tax_rules`, `tax_rules_changelog`
- `INSERT` on `tax_rules_changelog` (감지 이벤트 기록 전용)
- `INSERT` on `audit_log`
- 그 외 테이블·DDL·DROP/UPDATE/DELETE 일체 금지

OpenClaw가 사용자 알림을 트리거해야 할 경우 `tax_rules_changelog`에 INSERT만 하고, 알림 발송은 Fastify의 `notification` 모듈이 주기적으로 스캔하여 처리한다.

## 결과
**긍정**
- OpenClaw 장악 시에도 재무 데이터 변조 불가
- 권한 분리 원칙(Least Privilege) 준수
- 감사 로그에서 OpenClaw 행위 추적 가능

**부정 / 비용**
- 알림 즉시성 저하 (스캔 주기만큼 지연) → 분 단위 스캔으로 허용
- OpenClaw 기능 확장 시마다 권한 재검토 필요

## 대안
1. **애플리케이션 계정 공유**: 권한 과잉, ADR 목적 위배.
2. **DB 직접 접근 대신 API 경유**: API 서명 키 관리 필요, 복잡도 증가. (장기적으로 고려 가치 있음)
3. **읽기조차 차단하고 CSV Export만 사용**: 자동화 가치 상실.
