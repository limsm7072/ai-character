# AI Character - 루틴 잔소리 앱

Spine 2D 캐릭터가 사용자의 루틴을 감시하고, 딴짓하면 AI가 잔소리하는 Android 앱.

## 주요 기능

- **루틴 모니터링** - 허용/차단 앱 설정, 시간대별 루틴 스케줄링
- **AI 잔소리** - Gemini AI가 상황에 맞는 잔소리/격려 메시지 생성
- **Spine 2D 캐릭터** - 4종 캐릭터 선택 (감정표현 + 제스처 애니메이션)
- **시스템 오버레이** - 딴짓 감지 시 다른 앱 위에 캐릭터 표시
- **TTS 음성** - 잔소리를 음성으로 출력
- **통계** - 딴짓 기록 및 루틴 준수율 확인

## 캐릭터 4종

| 캐릭터 | 설명 | 특징 |
|--------|------|------|
| Spineboy | 총 든 소년 | 다양한 액션 애니메이션 |
| Chibi | 치비 스타일 | 23개+ 감정 이모트 |
| Mix & Match | 소녀 캐릭터 | 조합형 스킨 시스템 |
| Owl | 부엉이 | 심플하고 가벼움 |

## 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점 + 오버레이 진입점
├── models/
│   ├── ai_response.dart               # AI 응답 모델
│   ├── character_config.dart           # 캐릭터 설정 (에셋, 애니메이션 매핑)
│   ├── character_registry.dart         # 4종 캐릭터 정의 레지스트리
│   ├── character_state.dart            # 캐릭터 상태 (감정, 제스처, 텍스트)
│   ├── distraction_log.dart            # 딴짓 기록 모델
│   └── routine.dart                    # 루틴 모델
├── screens/
│   ├── home_screen.dart                # 홈 화면 (루틴 목록)
│   ├── character_chat_screen.dart      # 캐릭터 채팅 화면
│   ├── routine_edit_screen.dart        # 루틴 편집 화면
│   ├── routine_stats_screen.dart       # 통계 화면
│   └── settings_screen.dart            # 설정 화면
├── services/
│   ├── app_detection_service.dart      # 현재 앱 감지 (UsageStatsManager)
│   ├── character_controller.dart       # 캐릭터 행동 오케스트레이션
│   ├── distraction_log_service.dart    # 딴짓 기록 저장/조회
│   ├── gemini_service.dart             # Google Gemini AI 연동
│   ├── overlay_service.dart            # 시스템 오버레이 관리
│   ├── routine_monitor.dart            # 루틴 모니터링 (백그라운드)
│   ├── routine_service.dart            # 루틴 CRUD
│   ├── settings_service.dart           # 앱 설정 저장
│   └── tts_service.dart                # TTS 음성 출력
└── widgets/
    ├── character_widget.dart           # 캐릭터 위젯 (레거시)
    ├── overlay_character.dart          # 오버레이용 캐릭터 위젯
    └── spine_character_widget.dart     # Spine 2D 렌더링 위젯

android/app/src/main/kotlin/.../
├── MainActivity.kt                    # 메인 액티비티 + MethodChannel
├── MonitorService.kt                  # 백그라운드 모니터링 서비스
├── CharacterCanvasView.kt             # 네이티브 캐릭터 뷰
├── NagOverlay.kt                      # 네이티브 오버레이
└── SpeechListenerActivity.kt          # 음성 인식

assets/spine/
├── spineboy/                          # Spineboy 에셋
├── chibi-stickers/                    # Chibi 에셋 (12개 PNG)
├── mix-and-match/                     # Mix & Match 에셋
└── owl/                               # Owl 에셋
```

## 기술 스택

- **Flutter** 3.x + Dart
- **Spine Flutter** 4.2 - 2D 캐릭터 애니메이션
- **Google Generative AI** - Gemini API
- **Flutter Overlay Window** - 시스템 오버레이
- **Flutter TTS** - 음성 합성
- **SharedPreferences** - 로컬 데이터 저장

## 빌드

```bash
flutter build apk --debug
```

## 필요 권한 (Android)

- 사용 정보 접근 (UsageStats)
- 다른 앱 위에 표시 (Overlay)
- 알림 (Android 13+)
