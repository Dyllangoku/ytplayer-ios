# YT 플레이어 (개인용 아이폰 앱)

나만 쓰는 아이폰 앱. 앱 안에서 유튜브·유튜브 뮤직을 보고 들으며, 광고는 건너뛰고, 화면을 꺼도 계속 재생됩니다.

## 구조
- `ios-app/` 앱 껍데기 (Swift, 한 번 설치)
- `scripts/youtube.js` 차단 스크립트 — **앱이 켜질 때마다 이 파일의 새 버전을 와이파이/데이터로 받아 적용**
- `.github/workflows/build.yml` GitHub의 무료 맥에서 앱 파일(.ipa)을 만들어 Releases에 올림

## 유튜브가 광고 차단을 뚫으면
1. `scripts/youtube.js`를 고치고 맨 위 `@version`을 올린다 (예: 1.0.0 → 1.0.1)
2. 아이폰 앱 → 업데이트 탭 → 지금 업데이트 (또는 앱을 다시 열기)

## 설치
1. Releases에서 최신 `YTPlayer.ipa` 받기
2. 노트북의 AltServer + 아이폰의 AltStore로 설치 (무료 Apple ID, 7일마다 같은 와이파이에서 자동 갱신)
