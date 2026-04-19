# Project Instructions for Codex

## Goal
- 이 프로젝트는 작은 단위로 안전하게 수정한다.
- 기존 구조와 동작을 최대한 유지한다.
- 큰 리팩터링보다 최소 수정으로 문제를 해결한다.

## Before Editing
- 관련 파일을 먼저 읽고 현재 구조를 파악한다.
- 작업 범위를 벗어나는 수정은 피한다.
- 바로 대규모 리팩터링하지 않는다.
- 기존 프로젝트의 관례와 구조를 우선 따른다.

## Package Manager
- pnpm을 우선 사용한다.
- 기존 프로젝트가 npm 또는 yarn을 명확히 사용 중이면 그 규칙을 유지한다.

## Commands
- install: pnpm install
- dev: pnpm dev
- build: pnpm build
- lint: pnpm lint
- typecheck: pnpm typecheck
- test: pnpm test

## Coding Rules
- TypeScript를 우선 사용한다.
- 기존 코드 스타일을 유지한다.
- any는 꼭 필요한 경우에만 사용한다.
- 함수와 변수 이름은 역할이 드러나게 작성한다.
- 관련 없는 포맷팅 변경은 하지 않는다.
- 한 번에 너무 많은 파일을 불필요하게 수정하지 않는다.

## Validation
- 수정 후 가능하면 lint, typecheck, test를 실행한다.
- 실행 실패 시 실패 원인과 결과를 분명히 남긴다.
- 실행하지 못한 검증도 명시한다.

## Change Control
- 승인 없이 파일 구조를 크게 바꾸지 말 것
- 승인 없이 패키지를 무분별하게 추가하지 말 것
- 환경변수, 인증, 배포, DB 관련 변경은 특히 신중하게 다룰 것
- 데이터 손실 가능성이 있으면 먼저 경고할 것

## Communication
- 무엇을 왜 바꿨는지 짧게 요약할 것
- 에러가 있으면 증상과 원인을 함께 설명할 것
- 확실하지 않은 내용은 추측하지 말 것
- 초보 개발자도 이해할 수 있게 지나치게 압축하지 말 것

## Do Not
- 관련 없는 코드까지 정리하지 말 것
- 승인 없이 의존성 마이그레이션을 진행하지 말 것
- 현재 동작을 바꾸는 리팩터링을 우선하지 말 것
- 불확실한 내용을 단정하지 말 것
