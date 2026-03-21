# React Server Components

## 개요

React Server Components(RSC)는 서버에서만 실행되는 React 컴포넌트다. 클라이언트로 JavaScript 번들을 전송하지 않으므로 번들 크기를 줄이고 초기 로딩 성능을 개선할 수 있다.

## 핵심 특징

- 서버에서만 렌더링되며, 클라이언트 번들에 포함되지 않음
- 데이터베이스나 파일 시스템에 직접 접근 가능
- async/await를 컴포넌트 레벨에서 사용 가능
- 'use client' 디렉티브로 클라이언트 컴포넌트와 구분

## 사용 시 주의사항

- 서버 컴포넌트에서는 useState, useEffect 등 클라이언트 훅 사용 불가
- 이벤트 핸들러(onClick 등) 사용 불가
- 클라이언트 컴포넌트는 서버 컴포넌트를 import할 수 없음 (children으로 전달은 가능)
