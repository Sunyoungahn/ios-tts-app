import SwiftUI

struct ContentView: View {
    @State private var text: String = "편리해졌어요"  // 테스트 텍스트 (Android와 동일)
    @State private var isInitialized = false
    @State private var isSynthesizing = false
    @State private var statusMessage = "⏳ SimpleTTS 초기화 중..."
    @State private var timingMessage = ""
    @State private var initDuration: TimeInterval = 0
    @State private var synthesisDuration: TimeInterval = 0
    @State private var textProcessingDuration: TimeInterval = 0
    @State private var bertProcessingDuration: TimeInterval = 0
    @State private var ttsInferenceDuration: TimeInterval = 0
    @State private var actualPlaybackDuration: TimeInterval = 0
    @State private var audioSampleRate: Int = 0
    @State private var skipFileSave = true  // 빠른 재생 모드 (Android와 동일)
    @State private var showProgress = false
    
    // 현재 오디오 데이터 (재생 버튼용)
    @State private var currentAudio: [Float]?
    @State private var showSpectrogram = false
    
    private let ttsEngine = SimpleTTSEngine()
    
    // 랜덤 문장 배열 (Android와 동일한 문장들)
    private let randomSentences = [
        // 일상 대화
        "인공지능이 발전하면서 우리의 일상생활이 많이 편리해졌어요",
        "안녕하세요, 오늘 날씨가 정말 좋네요.",
        "커피 한잔 하실래요? 제가 사겠습니다.",
        "주말에 영화 보러 갈까요?",
        "맛있는 점심 드셨나요?",
        "내일 회의 시간이 언제죠?",
        
        // 감정 표현
        "이번 프로젝트 잘 진행되고 있어요.",
        "한국어 발음이 어려워요.",
        "음성 합성 기술이 많이 발전했네요.",
        "오늘 하루도 즐거운 하루 되세요.",
        "감사합니다. 덕분에 많은 도움이 되었어요.",
        
        // 질문과 제안
        "지금 몇 시인가요?",
        "저녁 뭐 먹을까요?",
        "운동 하러 가실래요?",
        "책 읽기를 좋아하세요?",
        "음악 들으면서 일하면 집중이 잘 돼요.",
        
        // 계획과 일정
        "휴가 계획 있으신가요?",
        "새로운 기술을 배우는 것은 항상 즐거워요.",
        "오늘 점심은 김치찌개 어때요?",
        "내일 아침 일찍 만나요.",
        "다음 주에 시간 되시면 같이 식사해요.",
        
        // 특수 케이스 테스트
        "3.14는 원주율이에요.",
        "100% 만족스러운 결과예요.",
        "ㅋㅋㅋ 정말 웃겨요.",
        "2024년이 벌써 지나가고 있네요.",
        "A.I. 기술이 우리 생활을 바꾸고 있어요.",
        
        // 복합어 테스트 케이스
        "최근 텍스트 음성분야가 급속도록 발전하고 있습니다.",
        "인공지능이 자연어처리를 혁신하고 있어요.",
        "기계학습을 통한 음성합성이 놀라워요.",
        "딥러닝이 음성인식을 개선했습니다.",
        "빅데이터 분석이 중요해지고 있어요.",
        
        // 한국 문화
        "한글은 세계에서 가장 과학적인 문자예요.",
        "비가 오는 날엔 파전이 최고죠.",
        "김치는 한국의 대표 음식이에요.",
        "한복은 정말 아름다워요.",
        "설날에는 떡국을 먹어요.",
        
        // 복잡한 문장
        "인공지능이 발전하면서 우리의 일상생활이 많이 편리해졌어요.",
        "기후 변화에 대응하기 위해 우리 모두의 노력이 필요합니다.",
        "건강한 식습관과 규칙적인 운동이 장수의 비결이에요.",
        "디지털 시대에도 아날로그 감성을 잃지 않는 것이 중요해요.",
        "소통과 공감이 좋은 관계를 만드는 핵심이에요."
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 진행 상태 표시 (Android ProgressBar와 동일)
                    if showProgress {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                    }
                    
                    // 상태 카드 (Android textViewStatus와 동일)
                    statusCard
                    
                    // 타이밍 카드 (Android textViewTiming과 동일)
                    if !timingMessage.isEmpty {
                        timingCard
                    }
                    
                    // 텍스트 입력 (Android editTextInput과 동일)
                    textInputSection
//                    
//                    // 빠른 재생 모드 스위치 (Android switchUltraFast와 동일)
//                    fastPlaybackToggle
                    
                    // 버튼 섹션 (Android 버튼들과 동일)
                    buttonSection
                    
                    // 파형 및 스펙트로그램 섹션 (오디오가 있을 때만 표시)
                    if let audio = currentAudio {
                        WaveformView(audioData: audio, sampleRate: audioSampleRate > 0 ? audioSampleRate : 44100)
                        
                        SpectrogramView(audioData: audio, sampleRate: audioSampleRate > 0 ? audioSampleRate : 44100)
                    }
                    
                    // TTS 추론 로직 설명 섹션
                    ttsExplanationSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("MeloTTS")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initializeTTS()
            }
            .onDisappear {
                ttsEngine.dispose()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var statusCard: some View {
        HStack {
            Image(systemName: isInitialized ? "checkmark.circle" : "hourglass")
                .foregroundColor(isInitialized ? .green : .orange)
            Text(statusMessage)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⏱️ 성능 타이머")
                .font(.headline)
            
            Text(timingMessage)
                .font(.system(size: 12))
               
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var textInputSection: some View {
        VStack(alignment: .leading) {
            Text("텍스트 입력")
                .font(.headline)
            
            TextEditor(text: $text)
                .frame(height: 100)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
    }
    
    private var fastPlaybackToggle: some View {
        HStack {
            Toggle("빠른 재생 (메모리)", isOn: $skipFileSave)
                .onChange(of: skipFileSave) { value in
                    let mode = value ? "빠른 재생 (메모리)" : "파일 저장 모드"
                    showSnackbar("🔄 \(mode)로 전환")
                }
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var buttonSection: some View {
        VStack(spacing: 12) {
            // 음성 합성 버튼 (Android buttonGenerate와 동일)
            Button(action: synthesizeAndSave) {
                HStack {
                    Image(systemName: isSynthesizing ? "waveform" : "speaker.wave.2")
                    Text(isSynthesizing ? "음성 합성 중... (INT8 모델)" : "🎯 음성 합성")
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isInitialized && !isSynthesizing ? Color.blue : Color.gray)
                .cornerRadius(8)
            }
            .disabled(!isInitialized || isSynthesizing)
            
            // 재생 버튼 (Android buttonPlay와 동일)
            Button(action: playCurrentAudio) {
                HStack {
                    Image(systemName: "play.circle")
                    Text("🔊 현재 오디오 재생")
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(currentAudio != nil ? Color.green : Color.gray)
                .cornerRadius(8)
            }
            .disabled(currentAudio == nil)
            
            // 커리어 버튼 (Android onCareerButtonClick과 동일)
//            Button(action: onCareerButtonClick) {
//                HStack {
//                    Image(systemName: "briefcase")
//                    Text("💼 커리어 질문")
//                }
//                .foregroundColor(.white)
//                .padding()
//                .frame(maxWidth: .infinity)
//                .background(Color.purple)
//                .cornerRadius(8)
//            }
            
            // 랜덤 문장 버튼 (Android onRandomButtonClick과 동일)
            Button(action: onRandomButtonClick) {
                HStack {
                    Image(systemName: "dice")
                    Text("🎲 랜덤 문장")
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
    }
    
    private var ttsExplanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📚 MeloTTS 추론 파이프라인")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("🔄 전체 과정: 텍스트 입력 → G2P 변환 → BERT 처리 → TTS 모델 추론 → 오디오 출력")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                explanationItem(
                    icon: "📝", 
                    title: "1. 텍스트 처리", 
                    description: "한국어 텍스트를 음소로 변환\n예: \"안녕하세요\" → \"ㅇㅏㄴㄴㅕㅇㅎㅏㅅㅔㅇㅛ\""
                )
                
                explanationItem(
                    icon: "🧠", 
                    title: "2. BERT 처리", 
                    description: "의미적 특징 추출 (768차원 벡터)\n자연스러운 억양과 감정 표현을 위한 컨텍스트 제공"
                )
                
                explanationItem(
                    icon: "🎵", 
                    title: "3. TTS 추론", 
                    description: "음소 + BERT 특징으로 음향 특징 생성\nVocoder를 통해 44100Hz PCM 오디오로 변환"
                )
                
                explanationItem(
                    icon: "⚡", 
                    title: "성능 최적화", 
                    description: "ONNX Runtime + INT8 양자화\nCPU 최적화로 1초 미만 생성"
                )
                
                explanationItem(
                    icon: "💡", 
                    title: "주요 특징", 
                    description: "한국어 연음 규칙 지원\n오프라인 완전 동작 (인터넷 불필요)"
                )
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func explanationItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Functions
    
    private func initializeTTS() {
        let startTime = Date()
        showProgress = true
        
        Task {
            do {
                try await ttsEngine.initialize()
                
                let duration = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    isInitialized = true
                    initDuration = duration
                    statusMessage = "✅ SimpleTTS 준비 완료"
                    showProgress = false
                    showSnackbar("✅ SimpleTTS 엔진 초기화 완료 (\(formatDuration(Int64(duration * 1000))))")
                }
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    initDuration = duration
                    statusMessage = "❌ 초기화 실패"
                    showProgress = false
                    showSnackbar("❌ SimpleTTS 초기화 실패: \(error.localizedDescription) (\(formatDuration(Int64(duration * 1000))))")
                }
            }
        }
    }
    
    // 음성 합성 및 자동 재생 (Android synthesizeAndSave와 동일)
    private func synthesizeAndSave() {
        guard isInitialized && !isSynthesizing else { return }
        
        let inputText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inputText.isEmpty else {
            showSnackbar("텍스트를 입력해주세요")
            return
        }
        
        isSynthesizing = true
        showProgress = true
        let startTime = Date()
        
        Task {
            do {
                statusMessage = "🎯 음성 합성 중... (INT8 모델)"
                
                // TTS 합성 실행 (Android와 동일한 파라미터)
                let result = try await ttsEngine.simpleTTSInference(
                    text: inputText,
                    speakerId: 0,
                    speed: 2.0,          // 초극한 속도 (Android와 동일)
                    noiseScale: 0.0,     // 노이즈 완전 제거 (Android와 동일)
                    noiseScaleW: 0.0,    // 완전 제거 (Android와 동일)
                    sdpRatio: 0.0        // SDP 완전 비활성화 (Android와 동일)
                )
                
                let audioData = result["audioData"] as! [Float]
                let duration = Date().timeIntervalSince(startTime)
                
                // Extract timing information (Android와 동일)
                let textProcessing = result["textProcessingDuration"] as! TimeInterval
                let bertProcessing = result["bertProcessingDuration"] as! TimeInterval
                let ttsInference = result["ttsInferenceDuration"] as! TimeInterval
                
                // 오디오 정보 계산 (Android와 동일)
                let audioLength = Double(audioData.count) / 44100.0  // SAMPLE_RATE
                let audioDurationSec = String(format: "%.2f", audioLength)
                let generationTimeSec = String(format: "%.2f", duration)
                
                currentAudio = audioData
                
                // 자동으로 재생 (Android와 동일)
                let audioResult = try await AudioPlayerHelper.playAudioFromFloatArray(audioData)
                
                await MainActor.run {
                    synthesisDuration = duration
                    textProcessingDuration = textProcessing
                    bertProcessingDuration = bertProcessing
                    ttsInferenceDuration = ttsInference
                    actualPlaybackDuration = audioResult.duration
                    audioSampleRate = audioResult.sampleRate
                    isSynthesizing = false
                    showProgress = false
                    
                    // Android와 동일한 상태 메시지 형식
                    statusMessage = """
                    ✅ 음성 합성 완료!
                    ⏱️ 생성 시간: \(generationTimeSec)초
                    🎵 오디오 길이: \(audioDurationSec)초
                    📊 샘플 수: \(formatNumber(audioData.count))
                    📈 Min/Max: \(String(format: "%.3f", audioData.min() ?? 0)) / \(String(format: "%.3f", audioData.max() ?? 0))
                    """
                    
                    // TTS 생성 총 시간 계산 (초기화 제외)
                    let totalTTSTime = textProcessingDuration + bertProcessingDuration + ttsInferenceDuration
                    
                    // 성능 타이밍 정보 (Android와 동일한 형식)
                    timingMessage = """
                    🔧 초기화: \(formatDuration(Int64(initDuration * 1000)))
                    -----------------------------------
                    🔊 실제 재생 시간: \(formatDuration(Int64(actualPlaybackDuration * 1000)))
                    📻 샘플 레이트: \(audioSampleRate) Hz
                    -----------------------------------
                    📝 텍스트 처리: \(formatDuration(Int64(textProcessingDuration * 1000)))
                    🧠 BERT 처리: \(formatDuration(Int64(bertProcessingDuration * 1000)))
                    🎵 TTS 추론: \(formatDuration(Int64(ttsInferenceDuration * 1000)))
                    
                    ⚡ TTS 생성 총 시간: \(formatDuration(Int64(totalTTSTime * 1000)))
                    """
                    
                    showSnackbar("✅ 음성 합성 성공! \(audioDurationSec)초 오디오 (생성: \(generationTimeSec)초)")
                }
                
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    synthesisDuration = duration
                    isSynthesizing = false
                    showProgress = false
                    statusMessage = "❌ 합성 실패"
                    showSnackbar("❌ 음성 합성 실패: \(error.localizedDescription) (\(formatDuration(Int64(duration * 1000))))")
                }
            }
        }
    }
    
    // 현재 오디오 재생 (Android playCurrentAudio와 동일)
    private func playCurrentAudio() {
        guard let audio = currentAudio else {
            showSnackbar("먼저 음성을 생성해주세요")
            return
        }
        
        Task {
            do {
                let audioResult = try await AudioPlayerHelper.playAudioFromFloatArray(audio)
                
                await MainActor.run {
                    actualPlaybackDuration = audioResult.duration
                    audioSampleRate = audioResult.sampleRate
                    
                    // TTS 생성 총 시간 계산 (초기화 제외)
                    let totalTTSTime = textProcessingDuration + bertProcessingDuration + ttsInferenceDuration
                    
                    // 타이밍 정보 업데이트
                    timingMessage = """
                    🔧 초기화: \(formatDuration(Int64(initDuration * 1000)))
                    🎤 음성 합성: \(formatDuration(Int64(synthesisDuration * 1000)))
                    ⚡ TTS 생성 총 시간: \(formatDuration(Int64(totalTTSTime * 1000)))
                    🔊 실제 재생 시간: \(formatDuration(Int64(actualPlaybackDuration * 1000)))
                    📻 샘플 레이트: \(audioSampleRate) Hz
                    📝 텍스트 처리: \(formatDuration(Int64(textProcessingDuration * 1000)))
                    🧠 BERT 처리: \(formatDuration(Int64(bertProcessingDuration * 1000)))
                    🎵 TTS 추론: \(formatDuration(Int64(ttsInferenceDuration * 1000)))
                    """
                    
                    showSnackbar("✅ 재생 완료!")
                }
            } catch {
                showSnackbar("❌ 오디오 재생 실패: \(error.localizedDescription)")
            }
        }
    }
    
    // 커리어 버튼 클릭 (Android onCareerButtonClick과 동일)
    private func onCareerButtonClick() {
        let careerText = "본 선발 부문에 지원을 결정하시게 된 계기와 입사 후 커리어 목표를 작성해 주세요."
        text = careerText
        statusMessage = "💼 커리어 질문이 선택되었습니다"
        
        // 자동으로 음성 생성 시작
        synthesizeAndSave()
    }
    
    // 랜덤 문장 버튼 클릭 (Android onRandomButtonClick과 동일)
    private func onRandomButtonClick() {
        let selectedSentence = randomSentences.randomElement() ?? "안녕하세요"
        text = selectedSentence
        
        print("🎲 랜덤 문장 선택: \(selectedSentence)")
        statusMessage = "🎲 랜덤 문장이 선택되었습니다"
        
        // 자동으로 음성 생성 시작
        synthesizeAndSave()
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ durationMs: Int64) -> String {
        switch durationMs {
        case ..<1000:
            return "\(durationMs)ms"
        case ..<60000:
            return String(format: "%.3f초", Double(durationMs) / 1000.0)
        default:
            let minutes = durationMs / 60000
            let seconds = (durationMs % 60000) / 1000
            return "\(minutes)분 \(seconds)초"
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func showSnackbar(_ message: String) {
        // iOS에서는 Toast 대신 간단한 알림 시뮬레이션
        print("📱 Snackbar: \(message)")
        // 실제 구현에서는 Toast 라이브러리나 Alert를 사용할 수 있음
    }
}

#Preview {
    ContentView()
}

// MARK: - TTS 생성 추론 로직 설명

/*
 📚 MeloTTS 추론 파이프라인 설명
 
 🔄 전체 과정:
 텍스트 입력 → G2P 변환 → BERT 처리 → TTS 모델 추론 → 오디오 출력
 
 📝 1. 텍스트 처리 (Text Processing):
 - 입력된 한국어 텍스트를 정규화
 - G2pKK를 사용해 한글을 음소(phoneme)로 변환
 - 예: "안녕하세요" → "ㅇㅏㄴㄴㅕㅇㅎㅏㅅㅔㅇㅛ"
 - 음소를 ID로 매핑하여 모델이 이해할 수 있는 숫자 배열로 변환
 
 🧠 2. BERT 처리 (BERT Processing):
 - 한국어 BERT 모델을 사용해 텍스트의 의미적 특징 추출
 - 각 음소에 대응하는 768차원 벡터 생성
 - 자연스러운 억양과 감정 표현을 위한 컨텍스트 정보 제공
 
 🎵 3. TTS 추론 (TTS Inference):
 - MeloTTS 모델이 음소 ID + BERT 특징을 입력으로 받음
 - Transformer 기반 아키텍처로 음향 특징(mel-spectrogram) 생성
 - Vocoder를 통해 음향 특징을 실제 오디오 파형으로 변환
 - 출력: 44100Hz 샘플레이트의 Float 배열 (PCM 오디오)
 
 ⚡ 성능 최적화:
 - ONNX Runtime 사용으로 추론 속도 향상
 - INT8 양자화 모델로 메모리 사용량 감소
 - CPU 최적화로 모바일 환경에서도 빠른 처리
 
 🔊 오디오 재생:
 - Float 배열을 16-bit PCM WAV 형식으로 변환
 - AVAudioPlayer를 통해 iOS에서 재생
 - 실시간 오디오 길이 및 품질 측정
 
 📊 품질 지표:
 - 생성 시간: 일반적으로 1초 미만
 - 오디오 품질: 22050Hz → 44100Hz 업샘플링
 - 자연스러운 한국어 발음과 억양 구현
 
 💡 주요 특징:
 - 한국어 연음 규칙 지원 (예: "음성이" → "음성이" 아닌 "음서기")
 - 다양한 문장 유형 지원 (평서문, 의문문, 감탄문)
 - 실시간 처리 가능한 경량화된 모델
 - 오프라인 완전 동작 (인터넷 연결 불필요)
 */
