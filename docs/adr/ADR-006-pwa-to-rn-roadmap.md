# ADR-006 — PWA(Phase 1) → React Native(Phase 3) 로드맵

- **상태**: Proposed
- **일자**: 2026-04-19
- **관련**: URD NFR-01, 리스크 "멀티 플랫폼 호환성"

## 맥락
Phase 1 MVP는 PWA로 웹/모바일을 동일 코드베이스로 커버한다. 그러나 iOS PWA는 Push 알림·Biometric·Background Sync 등이 제한적이고, Android 일부 기종에서도 홈 화면 설치 UX가 부자연스럽다. Phase 3에서는 가족 단위 사용 확장(NFR-03)과 알림/생체 인증이 중요해질 가능성이 높다.

## 결정 (제안)
단계적 로드맵을 채택한다.
1. **Phase 1 (MVP)**: React + Vite PWA, Service Worker로 오프라인 읽기
2. **Phase 2**: PWA 유지하되 Web Push(VAPID)로 알림 강화
3. **Phase 3**: React Native(Expo) 앱으로 모바일 전환. 공통 로직을 `packages/core`로 분리하여 재사용

## 결과
**긍정 (제안 수용 시)**
- Phase 1에서 단일 코드베이스로 빠른 검증
- Phase 3 전환 시 비즈니스 로직(`finance`, `tax`) 재사용 가능
- iOS 알림·위젯·생체 인증 등 네이티브 가치 확보

**부정 / 비용**
- Phase 3에서 UI 재구현 필요
- Expo 의존 추가 (빌드·OTA 업데이트 학습 비용)

## 미결
- 트리거 조건: 기본 시점(Phase 3 일정) vs. 사용자 피드백(가족 확장 요청 시점)
- 코드 공유 경계: UI 컴포넌트(React Native Web)까지 공유 vs. 로직만 공유

## 대안
1. **PWA 영구 유지**: iOS 제약으로 기능 천장 존재.
2. **Phase 1부터 React Native**: MVP 일정 내 인증/배포 경험 부족 → 리스크.
3. **Flutter**: 공통 로직(JS/TS) 재사용 불가 → 재작성 비용.
