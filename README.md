# iOS TTS App with MeloTTS

**English** | [한국어](#한국어)

---

## 📱 Overview

A high-quality Korean Text-to-Speech (TTS) iOS application that provides real-time on-device speech synthesis using the MeloTTS ONNX model. This app delivers natural Korean speech synthesis with advanced grapheme-to-phoneme (G2P) processing, real-time audio visualization, and a modern SwiftUI interface.

## ✨ Features

- **High-Quality Korean Speech Synthesis**: Natural Korean TTS powered by MeloTTS ONNX models
- **Advanced G2P Processing**: Complete Korean phonetic conversion with liaison rules, consonant assimilation, and complex syllable handling
- **Real-Time Visualization**: Waveform and spectrogram analysis views for audio inspection
- **Modern UI**: Intuitive and responsive SwiftUI-based interface
- **Real-Time Audio Playback**: High-performance audio processing using AVAudioEngine
- **On-Device Processing**: All inference runs locally on the device for privacy and offline capability

## 🏗️ Architecture

### TTS Pipeline

```
Input Text → G2P Conversion → Phonetic Symbols → ONNX Model → Audio Output
     ↓            ↓                ↓              ↓            ↓
  "안녕하세요"  → Normalization  → Phonemes     → Mel-Spec   → PCM Audio
                  ↓                ↓              ↓
              Liaison Rules    → Jamo Conversion → Vocoder
```

### Detailed Pipeline

1. **Text Preprocessing** (`normalizeKoreanText`)
   - Special character removal
   - Whitespace normalization

2. **G2P Conversion** (`G2p.call`)
   - Korean phonetic conversion
   - Liaison rule application
   - Consonant cluster handling
   - Consonant assimilation

3. **Jamo Conversion** (`hangulToJamo`)
   - Decomposition of Korean syllables into jamo units
   - Mapping to phonetic symbols

4. **ONNX Model Inference** (`MeloTTSInfer`)
   - Encoder: Text → Hidden features
   - Decoder: Features → Mel-spectrogram
   - Vocoder: Mel → Audio waveform

5. **Audio Output** (`AudioHelper`)
   - PCM buffer generation
   - AVAudioEngine playback
   - Real-time visualization

## 📂 Project Structure

```
meloTTS/
├── 📱 UI Components
│   ├── ContentView.swift           # Main UI container
│   ├── WaveformView.swift          # Real-time waveform visualization
│   └── SpectrogramView.swift       # Spectrogram analysis view
│
├── 🔤 G2P (Grapheme-to-Phoneme)
│   ├── G2PKK.swift                 # Korean G2P main engine
│   ├── Jamo.swift                  # Korean jamo processing
│   └── Symbols.swift               # Phonetic symbol mapping
│
├── 🧠 TTS Engine
│   ├── TTSEngine.swift             # TTS pipeline manager
│   ├── MeloTTSInfer.h/.mm         # ONNX model C++ wrapper
│   └── MeloTTSInferWrapper.swift   # Swift interface
│
├── 🎵 Audio Processing
│   ├── AudioHelper.swift           # Audio playback and processing
│   └── Models.swift                # Data model definitions
│
└── 🤖 ML Models
    └── models/                     # ONNX model files
        ├── bert.onnx               # BERT encoder model
        ├── tts.onnx                # TTS decoder/vocoder model
        ├── config.json             # Model configuration
        ├── tokenizer.json          # Tokenizer configuration
        └── vocab.txt               # Vocabulary file
```

## 🚀 Installation

### Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
- Minimum 2GB RAM (for model loading)
- ONNX Runtime framework

### Setup Steps

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd ios-tts-app
   ```

2. **Prepare model files**:
   ```bash
   # Ensure model files are in meloTTS/models/ directory
   # Required files:
   # - bert.onnx
   # - tts.onnx
   # - config.json
   # - tokenizer.json
   # - vocab.txt
   ```

3. **Open in Xcode**:
   ```bash
   open meloTTSios/meloTTS/meloTTS.xcworkspace
   ```

4. **Build and run**:
   - Select a simulator or physical device
   - Build and run the project
   - First launch will take 10-20 seconds for model loading

## 💻 Usage

### Basic Usage

```swift
// Initialize TTS engine
let ttsEngine = SimpleTTSEngine()
try await ttsEngine.initialize()

// Synthesize speech
let audioData = try await ttsEngine.synthesize(
    text: "안녕하세요, 밀리입니다!",
    speakerId: 0,
    speed: 1.0
)

// Play audio
AudioHelper.playAudio(audioData)
```

### G2P Conversion

```swift
// Test G2P conversion
let g2p = G2p(verbose: true)
let phonemes = g2p.call("좋은 하루 되세요")
// Output: "조은 하루 되세요" (with liaison applied)
```

## 🔧 Advanced Features

### G2P Improvements

The Korean G2P engine includes:

- **Liaison Rules**: Proper handling of consonant-vowel connections
  - Example: "좋은" → "조은"
  
- **Consonant Assimilation**: Natural sound changes
  - Example: "ㄱ + ㄷ" → "ㄱㄸ" (fortition)
  
- **Representative Sounds**: Proper final consonant pronunciation
  - Example: "ㄲ, ㅋ, ㄳ, ㄺ" → "ㄱ" (ㄱ series)

- **Complex Consonant Clusters**: Accurate handling of all Korean consonant combinations

### Real-Time Visualization

The app provides two visualization modes:

- **Waveform View**: Real-time audio waveform display
- **Spectrogram View**: Frequency-time analysis of generated speech

## 📊 Performance Metrics

- **Synthesis Speed**: Real-time (RTF < 0.1)
- **Model Size**: ~200MB total
- **Memory Usage**: Peak ~500MB
- **Latency**: First synthesis ~2s, subsequent ~0.5s

## 🛠️ Development

### Customizing G2P Rules

Edit `G2PKK.swift` to modify pronunciation rules:

```swift
// Add custom transformation rules
static let transformRules: [String: String] = [
    "custom_rule": "conversion_result",
    // ... existing rules
]
```

### Replacing ONNX Models

Update model paths in `MeloTTSInfer.mm` to use different TTS models. Ensure the new models match the expected input/output format.

### Adding Visualizations

Reference `WaveformView.swift` and `SpectrogramView.swift` to implement additional analysis views.

## 🐛 Troubleshooting

### Common Issues

1. **Model Loading Failure**:
   - Verify all ONNX files exist in `models/` folder
   - Check file permissions (`chmod 644 models/*.onnx`)
   - Ensure models are included in the Xcode project bundle

2. **Audio Playback Issues**:
   - Use a physical device instead of simulator for better audio support
   - Check audio session permissions
   - Verify AVAudioEngine initialization

3. **G2P Results Incorrect**:
   - Enable verbose mode: `G2p(verbose: true)`
   - Check console logs for processing steps
   - Verify Korean text normalization

4. **ONNX Runtime Errors**:
   - Ensure ONNX Runtime framework is properly linked
   - Check model file integrity
   - Verify input tensor shapes match model expectations



---

# 한국어

## 📱 개요

MeloTTS ONNX 모델을 활용한 고품질 한국어 텍스트-음성 변환(TTS) iOS 애플리케이션입니다. 이 앱은 고급 자소-음소 변환(G2P) 처리, 실시간 오디오 시각화, 모던한 SwiftUI 인터페이스를 제공하여 자연스러운 한국어 음성 합성을 제공합니다.

## ✨ 주요 기능

- **고품질 한국어 음성 합성**: MeloTTS ONNX 모델 기반의 자연스러운 한국어 TTS
- **고급 G2P 처리**: 연음 규칙, 자음 동화, 복합 받침 처리를 포함한 완전한 한국어 음성학적 변환
- **실시간 시각화**: 오디오 검사를 위한 파형 및 스펙트로그램 분석 뷰
- **모던 UI**: 직관적이고 반응형인 SwiftUI 기반 인터페이스
- **실시간 오디오 재생**: AVAudioEngine을 활용한 고성능 오디오 처리
- **온디바이스 처리**: 모든 추론이 기기에서 로컬로 실행되어 개인정보 보호 및 오프라인 기능 제공

## 🏗️ 아키텍처

### TTS 파이프라인

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

## 📂 프로젝트 구조

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
    └── models/                     # ONNX 모델 파일들
        ├── bert.onnx               # BERT 인코더 모델
        ├── tts.onnx                # TTS 디코더/보코더 모델
        ├── config.json             # 모델 설정
        ├── tokenizer.json          # 토크나이저 설정
        └── vocab.txt               # 어휘 파일
```

## 🚀 설치

### 필수 요구사항

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
- 최소 2GB RAM (모델 로딩용)
- ONNX Runtime 프레임워크

### 설치 방법

1. **저장소 클론**:
   ```bash
   git clone <repository-url>
   cd ios-tts-app
   ```

2. **모델 파일 준비**:
   ```bash
   # meloTTS/models/ 디렉토리에 모델 파일들이 있는지 확인
   # 필요한 파일:
   # - bert.onnx
   # - tts.onnx
   # - config.json
   # - tokenizer.json
   # - vocab.txt
   ```

3. **Xcode에서 열기**:
   ```bash
   open meloTTSios/meloTTS/meloTTS.xcworkspace
   ```

4. **빌드 및 실행**:
   - 시뮬레이터 또는 실제 디바이스 선택
   - 프로젝트 빌드 및 실행
   - 첫 실행 시 모델 로딩에 10-20초 소요

## 💻 사용법

### 기본 사용법

```swift
// TTS 엔진 초기화
let ttsEngine = SimpleTTSEngine()
try await ttsEngine.initialize()

// 음성 합성
let audioData = try await ttsEngine.synthesize(
    text: "안녕하세요, 밀리입니다!",
    speakerId: 0,
    speed: 1.0
)

// 오디오 재생
AudioHelper.playAudio(audioData)
```

### G2P 변환

```swift
// G2P 변환 테스트
let g2p = G2p(verbose: true)
let phonemes = g2p.call("좋은 하루 되세요")
// 출력: "조은 하루 되세요" (연음 적용됨)
```

## 🔧 고급 기능

### G2P 개선 사항

한국어 G2P 엔진에는 다음이 포함됩니다:

- **연음 규칙**: 자음-모음 연결의 적절한 처리
  - 예시: "좋은" → "조은"
  
- **자음 동화**: 자연스러운 음성 변화
  - 예시: "ㄱ + ㄷ" → "ㄱㄸ" (된소리화)
  
- **대표음 규칙**: 받침의 적절한 발음
  - 예시: "ㄲ, ㅋ, ㄳ, ㄺ" → "ㄱ" (ㄱ 계열)

- **복합 받침**: 모든 한국어 자음 조합의 정확한 처리

### 실시간 시각화

앱은 두 가지 시각화 모드를 제공합니다:

- **파형 뷰**: 실시간 오디오 파형 표시
- **스펙트로그램 뷰**: 생성된 음성의 주파수-시간 분석

## 📊 성능 지표

- **합성 속도**: 실시간 (RTF < 0.1)
- **모델 크기**: 총 ~200MB
- **메모리 사용량**: 피크 ~500MB
- **지연 시간**: 첫 합성 ~2초, 이후 ~0.5초

## 🛠️ 개발

### G2P 규칙 커스터마이징

발음 규칙을 수정하려면 `G2PKK.swift`를 편집하세요:

```swift
// 사용자 정의 변환 규칙 추가
static let transformRules: [String: String] = [
    "커스텀규칙": "변환결과",
    // ... 기존 규칙들
]
```

### ONNX 모델 교체

다른 TTS 모델을 사용하려면 `MeloTTSInfer.mm`에서 모델 경로를 업데이트하세요. 새 모델이 예상되는 입출력 형식과 일치하는지 확인하세요.

### 시각화 추가

추가 분석 뷰를 구현하려면 `WaveformView.swift`와 `SpectrogramView.swift`를 참조하세요.

## 🐛 문제 해결

### 일반적인 문제들

1. **모델 로딩 실패**:
   - `models/` 폴더에 모든 ONNX 파일이 있는지 확인
   - 파일 권한 확인 (`chmod 644 models/*.onnx`)
   - 모델이 Xcode 프로젝트 번들에 포함되어 있는지 확인

2. **오디오 재생 문제**:
   - 더 나은 오디오 지원을 위해 시뮬레이터 대신 실제 디바이스 사용
   - 오디오 세션 권한 확인
   - AVAudioEngine 초기화 확인

3. **G2P 결과가 이상함**:
   - 상세 모드 활성화: `G2p(verbose: true)`
   - 콘솔 로그에서 처리 단계 확인
   - 한국어 텍스트 정규화 확인

4. **ONNX Runtime 오류**:
   - ONNX Runtime 프레임워크가 제대로 링크되어 있는지 확인
   - 모델 파일 무결성 확인
   - 입력 텐서 형태가 모델 예상과 일치하는지 확인

