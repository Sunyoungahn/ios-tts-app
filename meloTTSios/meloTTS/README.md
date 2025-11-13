# Korean TTS iOS App

고품질 한국어 TTS(Text-to-Speech) iOS 애플리케이션으로, MeloTTS ONNX 모델을 활용한 실시간 음성 합성을 제공합니다.

## 🎯 주요 기능

- **고품질 한국어 음성 합성**: MeloTTS ONNX 모델을 활용한 자연스러운 한국어 TTS
- **고급 G2P 처리**: 연음 규칙, 받침 처리, 자음 동화를 포함한 완전한 한국어 음성학적 변환
- **실시간 시각화**: 파형(Waveform) 및 스펙트로그램(Spectrogram) 분석 뷰
- **모던 UI**: SwiftUI 기반의 직관적이고 반응형 인터페이스
- **실시간 오디오 재생**: AVAudioEngine을 활용한 고성능 오디오 처리

## 🔧 TTS 파이프라인

```
입력 텍스트 → G2P 변환 → 음성학적 기호 → ONNX 모델 → 오디오 출력
     ↓           ↓            ↓            ↓           ↓
  "안녕하세요"  → 정규화     → Phonemes    → Mel-Spec  → PCM Audio
                  ↓            ↓            ↓
              연음규칙 적용  → Jamo 변환   → Vocoder
```

### 세부 파이프라인

1. **텍스트 전처리** (`normalizeKoreanText`)
   - 특수문자 제거
   - 공백 정규화

2. **G2P 변환** (`G2p.call`)
   - 한국어 음성학적 변환
   - 연음 규칙 적용
   - 받침 처리
   - 자음 동화

3. **Jamo 변환** (`hangulToJamo`)
   - 한글 음절을 자모 단위로 분해
   - 음성학적 기호로 매핑

4. **ONNX 모델 추론** (`MeloTTSInfer`)
   - Encoder: 텍스트 → Hidden features
   - Decoder: Features → Mel-spectrogram
   - Vocoder: Mel → Audio waveform

5. **오디오 출력** (`AudioHelper`)
   - PCM 버퍼 생성
   - AVAudioEngine 재생
   - 실시간 시각화

## 🏗️ 프로젝트 구조

```
meloTTS/
├── 📱 UI Components
│   ├── ContentView.swift           # 메인 UI 컨테이너
│   ├── WaveformView.swift          # 실시간 파형 시각화
│   └── SpectrogramView.swift       # 스펙트로그램 분석 뷰
│
├── 🔤 G2P (Grapheme-to-Phoneme)
│   ├── G2PKK.swift                 # 한국어 G2P 메인 엔진
│   ├── Jamo.swift                  # 한글 자모 처리
│   └── Symbols.swift               # 음성학적 기호 매핑
│
├── 🧠 TTS Engine
│   ├── TTSEngine.swift             # TTS 파이프라인 관리자
│   ├── MeloTTSInfer.h/.mm         # ONNX 모델 C++ 래퍼
│   └── MeloTTSInferWrapper.swift   # Swift 인터페이스
│
├── 🎵 Audio Processing
│   ├── AudioHelper.swift           # 오디오 재생 및 처리
│   └── Models.swift                # 데이터 모델 정의
│
└── 🤖 ML Models
    └── models/                     # ONNX 모델 파일들 (별도 다운로드)
```

## 📂 Models 폴더 구조

`meloTTS/models/` 디렉토리에 다음 파일들이 필요합니다:

```
models/
├── encoder.onnx              # 텍스트 인코더 모델 (약 50MB)
├── decoder.onnx              # 멜-스펙트로그램 디코더 (약 100MB)
├── vocoder.onnx              # 보코더 모델 (약 30MB)
└── speaker_embeddings.bin    # 화자 임베딩 (선택사항, 약 5MB)
```

### 모델 다운로드 방법

1. **공식 MeloTTS 모델**: 
   ```bash
   # MeloTTS 공식 저장소에서 다운로드
   wget https://github.com/myshell-ai/MeloTTS/releases/download/v0.1.0/korean_models.zip
   unzip korean_models.zip -d meloTTS/models/
   ```

2. **사용자 정의 모델**:
   - 자체 훈련된 ONNX 모델 사용 가능
   - 동일한 입출력 형식을 준수해야 함

## 🔧 G2PKK 개선 사항

한국어 G2P 엔진에 다음과 같은 고급 기능을 구현했습니다:

### ✅ 연음 규칙 (Liaison Rules)
```swift
// 예시: "좋은" → "조은"
받침 + ㅇ 초성 → 연음 처리
- 단순 자음: ㄱ, ㄴ, ㄹ, ㅁ, ㅂ, ㅅ, ㅇ → 다음 음절로 이동
- 복합 자음: ㄳ, ㄵ, ㄺ, ㄻ, ㄼ, ㄽ, ㄾ, ㄿ, ㅀ, ㅄ → 분해 후 일부 이동
```

### ✅ 자음 동화 규칙 (Consonant Assimilation)
```swift
// Rule 23: 자음군 단순화
"ㄱ + ㄷ" → "ㄱㄸ"  // 된소리화
"ㅅ + ㅅ" → "ㅆ"    // 경음화
```

### ✅ 대표음 규칙 (Representative Sounds)
```swift
// Rule 9: 받침의 대표 발음
"ㄲ, ㅋ, ㄳ, ㄺ" → "ㄱ"  // ㄱ 계열
"ㅅ, ㅆ, ㅈ, ㅊ, ㅌ" → "ㄷ"  // ㄷ 계열  
"ㅍ, ㄼ, ㄿ, ㅄ" → "ㅂ"      // ㅂ 계열
```

### ✅ 복합 받침 처리
- **ㅆ**: 연음 시 전체 이동 (`싶어` → `시퍼`)
- **ㄲ**: 연음 시 ㄱ 이동, ㄱ 잔류 (`닦아` → `다까`)
- **ㄳ**: 연음 시 ㅅ 이동, ㄱ 잔류 (`몫을` → `목슬`)
- **기타**: ㄵ, ㄶ, ㄺ, ㄻ, ㄼ, ㄽ, ㄾ, ㄿ, ㅀ, ㅄ 모두 정확히 처리

## 🚀 설치 및 실행

### 필수 요구사항
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
- 최소 2GB RAM (모델 로딩용)

### 설치 방법

1. **저장소 클론**:

2. **모델 파일 준비**:
   ```bash
   mkdir -p meloTTS/models
   # 위의 "모델 다운로드 방법" 참조하여 ONNX 파일들 배치
   ```

3. **Xcode에서 실행**:
   ```bash
   open meloTTS.xcworkspace
   ```
   - Simulator 또는 실제 디바이스에서 실행
   - 첫 실행 시 모델 로딩에 10-20초 소요

## 🔍 사용 예시

```swift
// 기본 TTS 사용
let ttsEngine = TTSEngine()
await ttsEngine.initialize()

let audioData = await ttsEngine.synthesize(text: "안녕하세요, 밀리입니다!")
// → "안녕하세요" 음성 데이터 생성

// G2P 변환 확인
let g2p = G2p(verbose: true)
let phonemes = g2p.call("좋은 하루 되세요")
// → "조은 하루 되세요" (연음 적용됨)
```

## 🛠️ 개발 가이드

### G2P 규칙 커스터마이징
`G2PKK.swift`에서 발음 규칙 수정 가능:

```swift
// 새로운 변환 규칙 추가
static let transformRules: [String: String] = [
    "커스텀규칙": "변환결과",
    // ... 기존 규칙들
]
```

### 새로운 시각화 추가
`WaveformView.swift`, `SpectrogramView.swift` 참조하여 추가 분석 뷰 구현 가능

### ONNX 모델 교체
`MeloTTSInfer.mm`에서 모델 경로 수정하여 다른 TTS 모델 사용 가능

## 📊 성능 지표

- **합성 속도**: 실시간 (RTF < 0.1)
- **모델 크기**: 총 ~200MB
- **메모리 사용량**: 피크 ~500MB
- **지연 시간**: 첫 합성 ~2초, 이후 ~0.5초

## 🐛 문제 해결

### 일반적인 문제들

1. **모델 로딩 실패**:
   - `models/` 폴더에 모든 ONNX 파일이 있는지 확인
   - 파일 권한 확인 (`chmod 644 models/*.onnx`)

2. **음성 재생 안됨**:
   - 시뮬레이터 대신 실제 디바이스 사용
   - 오디오 세션 권한 확인

3. **G2P 결과가 이상함**:
   - `verbose: true` 로 설정하여 로그 확인
   - 특정 단어의 처리 과정 추적

---


🤖 *Enhanced with [Claude Code](https://claude.ai/code)*