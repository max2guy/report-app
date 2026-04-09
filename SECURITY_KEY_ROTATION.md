# Firebase 키 로테이션 체크리스트

작성일: 2026-04-09

## 1) 즉시 조치 (노출 키 무효화)

1. Firebase Console > 프로젝트 설정 > 서비스 계정으로 이동
2. 기존 노출된 private key를 `비활성/삭제` 처리
3. 필요 시 새 서비스 계정 키 1개만 발급
4. 새 키는 브라우저 코드에 절대 넣지 말고 Worker/서버 Secret으로만 저장

## 2) 서버 전용 FCM 발송 구조

클라이언트는 `/fcm-send`만 호출하고, 실제 FCM 호출은 서버(Worker)가 수행해야 함.

필수 요청 형식:

```json
{
  "targetRole": "viewerApp",
  "title": "📄 새 보고서 도착",
  "body": "알림 본문",
  "tag": "church-viewer",
  "url": "./viewer.html"
}
```

필수 헤더:

- `X-Push-Token: <서버 검증 토큰>`
- `Content-Type: application/json`

서버(Worker)에서 해야 할 일:

1. `X-Push-Token` 검증
2. RTDB 또는 저장소에서 `targetRole`에 해당하는 FCM token 조회
3. 서버 Secret(Service Account)으로 OAuth2 access token 발급
4. FCM v1 API `messages:send` 호출

## 3) 배포 후 확인

1. report 앱에서 보고서 생성 후 viewer 디바이스에 푸시 도착 확인
2. viewer 앱에서 지시사항 전송 후 report 디바이스에 푸시 도착 확인
3. 브라우저 DevTools 검색으로 `BEGIN PRIVATE KEY` 문자열 0건 확인
4. Worker 로그에서 `/fcm-send` 200 응답 확인

