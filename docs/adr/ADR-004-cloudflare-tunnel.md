# ADR-004 — Cloudflare Tunnel over 포트포워딩

- **상태**: Accepted
- **일자**: 2026-04-19
- **관련**: ARCH v0.1 §4.3, NFR-02, NFR-05

## 맥락
Beelink가 가정용 인터넷(동적 IP, NAT 뒤)에 있어 외부(PWA)에서 직접 접근할 수 없다. 전통적 방법은 공유기 포트포워딩 + DDNS지만, 인바운드 포트 개방·ISP IP 차단·TLS 인증서 수동 관리 등 리스크가 있다.

## 결정
**Cloudflare Tunnel(`cloudflared` 데몬)**을 Beelink에 설치하여 Outbound 연결만으로 외부 접근 경로를 구성한다. 도메인은 `*.warboy.example.com` (사용자 소유)을 Cloudflare DNS에 위임한다.

- Edge ↔ Origin 구간: Origin Pull mTLS로 Beelink 서명 인증서 검증
- Edge ↔ Browser 구간: Cloudflare Universal SSL
- Cloudflare Access 규칙으로 특정 국가·IP만 허용 (선택)

## 결과
**긍정**
- 인바운드 포트 0 개방 (공격 표면 최소)
- 동적 IP 문제 해소 (Tunnel이 세션 유지)
- Cloudflare WAF·Rate Limit·DDoS 방어 기본 포함
- 무료 플랜 내에서 운영

**부정 / 비용**
- Cloudflare 장애 시 외부 접근 전면 불가 → 로컬 Tailscale 대체 경로를 Runbook에 명시
- CDN 계층 추가로 P95 지연 ≈ 30~50ms 증가 → §7 성능 목표 내 허용

## 대안
1. **포트포워딩 + DDNS (Duck DNS)**: 인바운드 개방 + 인증서 수동 관리 부담.
2. **Tailscale Funnel**: 무료 한도·도메인 커스터마이즈 제약.
3. **VPS 리버스 프록시**: 월 비용 발생, 추가 서버 관리.
