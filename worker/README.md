# FCM Push Worker (`/fcm-send`)

이 Worker는 클라이언트 대신 서버에서만 FCM v1 발송을 수행합니다.

## 1) 필요한 Secret 설정

`worker/` 디렉토리에서 실행:

```bash
wrangler secret put PUSH_PROXY_TOKEN
wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON
wrangler secret put FIREBASE_RTDB_URL
# 선택: DB rules가 auth를 요구할 때만
wrangler secret put FIREBASE_RTDB_AUTH
```

권장 값:

- `PUSH_PROXY_TOKEN`: 32자 이상 랜덤 문자열
- `GOOGLE_SERVICE_ACCOUNT_JSON`: Firebase 서비스 계정 JSON 전체(문자열 그대로)
- `FIREBASE_RTDB_URL`: 예) `https://yeoncheon-church-default-rtdb.asia-southeast1.firebasedatabase.app`

## 2) 배포

```bash
wrangler deploy
```

## 3) 요청 형식

- Endpoint: `POST /fcm-send`
- Header: `X-Push-Token: <PUSH_PROXY_TOKEN>`
- Body(JSON):

```json
{
  "targetRole": "viewerApp",
  "title": "📄 새 보고서 도착",
  "body": "알림 본문",
  "tag": "church-viewer",
  "url": "./viewer.html"
}
```

## 4) 동작 순서

1. `X-Push-Token` 검증
2. RTDB `fcm-tokens/<targetRole>` 조회
3. 서비스 계정 JWT로 OAuth access token 발급
4. FCM v1 API `messages:send` 호출

## 5) 점검 포인트

- Worker 로그에 `200` 응답 확인
- 앱 설정에서 `FCM Worker 토큰(pushProxyToken)` 입력 확인
- 브라우저 코드에서 `BEGIN PRIVATE KEY` 검색 결과 0건 유지
