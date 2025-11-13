//
//  MeloTTSInferWrapper.swift
//  meloTTS
//
//  Created by lyla on 8/28/25.
//

import Foundation

// MARK: - C Function Declarations

/// ONNX Runtime 초기화
@_silgen_name("initializeONNXRuntime")
func initializeONNXRuntime(_ bertModelPath: UnsafePointer<Int8>, _ ttsModelPath: UnsafePointer<Int8>) -> Int32

/// TTS 추론 실행 (개별 파라미터로)
@_silgen_name("runTTSInferenceWithParams")
func runTTSInferenceWithParams(
    _ text: UnsafePointer<Int8>,
    _ speakerId: Int32,
    _ speed: Float,
    _ noiseScale: Float,
    _ noiseScaleW: Float,
    _ sdpRatio: Float
) -> UnsafeMutablePointer<TTSResult>?

/// 결과 정리
@_silgen_name("freeTTSResult")
func freeTTSResult(_ result: UnsafeMutablePointer<TTSResult>)

/// BERT 추론 실행
@_silgen_name("runBertInference")
func runBertInferenceC(_ text: UnsafePointer<Int8>) -> UnsafeMutablePointer<BertResult>?

/// BERT 추론 실행 (토큰화된 방식)
@_silgen_name("runBertInferenceWithTokens")
func runBertInferenceWithTokensC(
    _ input_ids: UnsafePointer<Int64>,
    _ attention_mask: UnsafePointer<Int64>,
    _ token_type_ids: UnsafePointer<Int64>,
    _ sequence_length: Int32
) -> UnsafeMutablePointer<BertResult>?

/// TTS 추론 실행 (BERT 특성 포함) - phone 데이터 추가
@_silgen_name("runTTSInferenceWithBertFeatures")
func runTTSInferenceWithBertFeaturesC(
    _ text: UnsafePointer<Int8>,
    _ speaker_id: Int32,
    _ speed: Float,
    _ noise_scale: Float,
    _ noise_scale_w: Float,
    _ sdp_ratio: Float,
    _ bert_features: UnsafePointer<Float>,
    _ ja_bert_features: UnsafePointer<Float>,
    _ bert_length: Int32,
    _ ja_bert_length: Int32,
    _ phone_data: UnsafePointer<Int64>,
    _ tone_data: UnsafePointer<Int64>,
    _ phone_length: Int32
) -> UnsafeMutablePointer<TTSResult>?

/// BERT 결과 정리
@_silgen_name("freeBertResult")
func freeBertResult(_ result: UnsafeMutablePointer<BertResult>)

/// ONNX Runtime 정리
@_silgen_name("cleanupONNXRuntime")
func cleanupONNXRuntime()

/// Android 앱과 동일한 TTS 추론
@_silgen_name("runAndroidCompatibleTTS")
func runAndroidCompatibleTTS(
    _ text: UnsafePointer<Int8>,
    _ speaker_id: Int32,
    _ speed: Float,
    _ noise_scale: Float,
    _ noise_scale_w: Float,
    _ sdp_ratio: Float,
    _ bert_features: UnsafePointer<Float>,
    _ ja_bert_features: UnsafePointer<Float>,
    _ bert_length: Int32,
    _ ja_bert_length: Int32,
    _ phone_data: UnsafePointer<Int64>,
    _ tone_data: UnsafePointer<Int64>,
    _ phone_length: Int32
) -> UnsafeMutablePointer<TTSResult>?

// MARK: - C Structure Declarations

/// TTS 추론 결과 (C 구조체)
struct TTSResult {
    let audio_data: UnsafeMutablePointer<Float>
    let audio_length: Int32
    let sample_rate: Int32
}

/// BERT 추론 결과 (C 구조체)
struct BertResult {
    let bert_features: UnsafeMutablePointer<Float>
    let batch_size: Int32
    let max_length: Int32
    let hidden_size: Int32
}

/// TTS 추론 파라미터 구조체
struct TTSParams {
    let text: String
    let speakerId: Int
    let speed: Float
    let noiseScale: Float
    let noiseScaleW: Float
    let sdpRatio: Float
    
    init(
        text: String,
        speakerId: Int = 0,
        speed: Float = 1.0,
        noiseScale: Float = 0.667,
        noiseScaleW: Float = 0.8,
        sdpRatio: Float = 0.2
    ) {
        self.text = text
        self.speakerId = speakerId
        self.speed = speed
        self.noiseScale = noiseScale
        self.noiseScaleW = noiseScaleW
        self.sdpRatio = sdpRatio
    }
}

/// ONNX Runtime을 사용한 TTS 추론을 위한 Swift 래퍼 클래스
class MeloTTSInferWrapper {
    
    // MARK: - Properties
    private var isInitialized = false
    
    // MARK: - Initialization
    
    /// ONNX Runtime 초기화
    /// - Parameters:
    ///   - bertModelPath: BERT 모델 파일 경로
    ///   - ttsModelPath: TTS 모델 파일 경로
    /// - Returns: 초기화 성공 여부
    func initialize(bertModelPath: String, ttsModelPath: String) -> Bool {
        guard !isInitialized else {
            print("⚠️ 이미 초기화됨")
            return true
        }
        
        let result = bertModelPath.withCString { bertPtr in
            ttsModelPath.withCString { ttsPtr in
                initializeONNXRuntime(bertPtr, ttsPtr)
            }
        }
        if result == 0 {
            isInitialized = true
            print("✅ ONNX Runtime 초기화 완료")
            return true
        } else {
            print("❌ ONNX Runtime 초기화 실패: \(result)")
            return false
        }
    }
    
    // MARK: - TTS Inference
    
    /// TTS 추론 실행
    /// - Parameter params: TTS 추론 파라미터
    /// - Returns: 오디오 데이터 배열
    func runInference(params: TTSParams) -> [Float]? {
        guard isInitialized else {
            print("❌ ONNX Runtime이 초기화되지 않음")
            return nil
        }
        
        // Swift String을 C char*로 변환하여 C 함수 호출
        return params.text.withCString { textPtr in
            // C 함수 호출 - 포인터를 직접 전달
            guard let result = runTTSInferenceWithParams(
                textPtr,
                Int32(params.speakerId),
                params.speed,
                params.noiseScale,
                params.noiseScaleW,
                params.sdpRatio
            ) else {
                print("❌ TTS 추론 실패")
                return nil
            }
            
            // 결과를 Swift 배열로 변환
            let audioData = Array(UnsafeBufferPointer<Float>(
                start: result.pointee.audio_data,
                count: Int(result.pointee.audio_length)
            ))
            
            // 메모리 정리
            freeTTSResult(result)
            
            print("✅ TTS 추론 완료: \(audioData.count) samples")
            return audioData
        }
    }
    
    // MARK: - Cleanup
    
    /// 리소스 정리
    func cleanup() {
        guard isInitialized else { return }
        
        cleanupONNXRuntime()
        isInitialized = false
        print("🗑️ ONNX Runtime 리소스 정리 완료")
    }
    
    // MARK: - Deinitializer
    
    deinit {
        cleanup()
    }
    
    // MARK: - Model Inspection
    
    
    /// BERT 추론 실행
    /// - Parameter text: BERT 처리할 텍스트
    /// - Returns: BERT 특성 배열 [max_length * hidden_size]
    func runBertInference(text: String) -> [Float]? {
        guard isInitialized else {
            print("❌ ONNX Runtime이 초기화되지 않음")
            return nil
        }
        
        return text.withCString { textPtr in
            guard let result = runBertInferenceC(textPtr) else {
                print("❌ BERT 추론 실패")
                return nil
            }
            
            let totalSize = Int(result.pointee.max_length * result.pointee.hidden_size)
            let bertFeatures = Array(UnsafeBufferPointer<Float>(
                start: result.pointee.bert_features,
                count: totalSize
            ))
            
            // 메모리 정리
            freeBertResult(result)
            
            print("✅ BERT 추론 완료: [\(result.pointee.batch_size), \(result.pointee.max_length), \(result.pointee.hidden_size)]")
            return bertFeatures
        }
    }
    
    /// BERT 추론 실행 (토큰화된 방식 - 권장)
    /// - Parameters:
    ///   - inputIds: 토큰화된 input IDs 배열
    ///   - attentionMask: attention mask 배열
    ///   - tokenTypeIds: token type IDs 배열
    /// - Returns: BERT 특성 배열 [max_length * hidden_size]
    func runBertInferenceWithTokens(
        inputIds: [Int],
        attentionMask: [Int],
        tokenTypeIds: [Int]
    ) -> [Float]? {
        guard isInitialized else {
            print("❌ ONNX Runtime이 초기화되지 않음")
            return nil
        }
        
        guard inputIds.count == attentionMask.count && attentionMask.count == tokenTypeIds.count else {
            print("❌ 토큰 배열 길이가 일치하지 않음")
            return nil
        }
        
        let sequenceLength = inputIds.count
        
        print("🔥 runBertInferenceWithTokens 호출됨:")
        print("  - sequenceLength: \(sequenceLength)")
        print("  - inputIds 처음 10개: \(Array(inputIds.prefix(10)))")
        
        // Int를 Int64로 변환
        let inputIds64 = inputIds.map { Int64($0) }
        let attentionMask64 = attentionMask.map { Int64($0) }
        let tokenTypeIds64 = tokenTypeIds.map { Int64($0) }
        
        let result = inputIds64.withUnsafeBufferPointer { inputIdsPtr in
            attentionMask64.withUnsafeBufferPointer { attentionMaskPtr in
                tokenTypeIds64.withUnsafeBufferPointer { tokenTypeIdsPtr in
                    return runBertInferenceWithTokensC(
                        inputIdsPtr.baseAddress!,
                        attentionMaskPtr.baseAddress!,
                        tokenTypeIdsPtr.baseAddress!,
                        Int32(sequenceLength)
                    )
                }
            }
        }
        
        guard let result = result else {
            print("❌ BERT 추론 실패 (토큰화됨)")
            return nil
        }
        
        let totalSize = Int(result.pointee.max_length * result.pointee.hidden_size)
        let bertFeatures = Array(UnsafeBufferPointer<Float>(
            start: result.pointee.bert_features,
            count: totalSize
        ))
        
        // 메모리 정리
        freeBertResult(result)
        
        print("✅ BERT 추론 완료 (토큰화됨): [\(result.pointee.batch_size), \(result.pointee.max_length), \(result.pointee.hidden_size)]")
        return bertFeatures
    }
    
    
    /// TTS 합성 (BERT 특성 포함 - 고품질) - phone 데이터 추가
    /// - Parameters:
    ///   - text: 합성할 텍스트
    ///   - speakerId: 화자 ID
    ///   - speed: 속도
    ///   - noiseScale: 노이즈 스케일
    ///   - noiseScaleW: 노이즈 스케일 W
    ///   - sdpRatio: SDP 비율
    ///   - bertFeatures: BERT 특성 배열 (bert)
    ///   - jaBertFeatures: JA-BERT 특성 배열 (ja_bert)
    ///   - phoneData: phone 시퀀스 데이터
    ///   - toneData: tone 시퀀스 데이터
    /// - Returns: 오디오 데이터 배열
    func synthesizeWithBertFeatures(
        text: String,
        speakerId: Int = 0,
        speed: Float = 1.0,
        noiseScale: Float = 0.667,
        noiseScaleW: Float = 0.8,
        sdpRatio: Float = 0.2,
        bertFeatures: [Float],
        jaBertFeatures: [Float],
        phoneData: [Int],
        toneData: [Int]
    ) -> [Float]? {
        
        guard isInitialized else {
            print("❌ ONNX Runtime이 초기화되지 않음")
            return nil
        }
        
        print("🔥 BERT 특성 포함 TTS 합성 시작:")
        print("  - BERT 특성 길이: \(bertFeatures.count)")
        print("  - JA-BERT 특성 길이: \(jaBertFeatures.count)")
        
        return text.withCString { textPtr in
            bertFeatures.withUnsafeBufferPointer { bertPtr in
                jaBertFeatures.withUnsafeBufferPointer { jaBertPtr in
                    // Int를 Int64로 변환
                    let phoneData64 = phoneData.map { Int64($0) }
                    let toneData64 = toneData.map { Int64($0) }
                    
                    return phoneData64.withUnsafeBufferPointer { phonePtr in
                        toneData64.withUnsafeBufferPointer { tonePtr in
                            guard let result = runTTSInferenceWithBertFeaturesC(
                                textPtr,
                                Int32(speakerId),
                                speed,
                                noiseScale,
                                noiseScaleW,
                                sdpRatio,
                                bertPtr.baseAddress!,
                                jaBertPtr.baseAddress!,
                                Int32(bertFeatures.count),
                                Int32(jaBertFeatures.count),
                                phonePtr.baseAddress!,
                                tonePtr.baseAddress!,
                                Int32(phoneData.count)
                            ) else {
                                print("❌ BERT 특성 포함 TTS 추론 실패")
                                return nil
                            }
                            
                            let audioData = Array(UnsafeBufferPointer<Float>(
                                start: result.pointee.audio_data,
                                count: Int(result.pointee.audio_length)
                            ))
                            
                            // 메모리 정리
                            freeTTSResult(result)
                            
                            print("✅ BERT 특성 포함 TTS 추론 완료: \(audioData.count) samples")
                            return audioData
                        }
                    }
                }
            }
        }
        
    }
    
    /// Android 앱과 동일한 TTS 합성 (새로운 모델 형식용)
    func synthesizeWithAndroidCompatibility(
        text: String,
        speakerId: Int = 0,
        speed: Float = 1.0,
        noiseScale: Float = 0.667,
        noiseScaleW: Float = 0.8,
        sdpRatio: Float = 0.2,
        bertFeatures: [Float],
        jaBertFeatures: [Float],
        phoneData: [Int],
        toneData: [Int]
    ) -> [Float]? {
        
        guard isInitialized else {
            print("❌ ONNX Runtime이 초기화되지 않음")
            return nil
        }
        
        print("🔥 Android 호환 TTS 합성 시작:")
        print("  - BERT 특성 길이: \(bertFeatures.count)")
        print("  - JA-BERT 특성 길이: \(jaBertFeatures.count)")
        print("  - Phone 데이터 길이: \(phoneData.count)")
        
        return text.withCString { textPtr in
            bertFeatures.withUnsafeBufferPointer { bertPtr in
                jaBertFeatures.withUnsafeBufferPointer { jaBertPtr in
                    // Int를 Int64로 변환
                    let phoneData64 = phoneData.map { Int64($0) }
                    let toneData64 = toneData.map { Int64($0) }
                    
                    return phoneData64.withUnsafeBufferPointer { phonePtr in
                        toneData64.withUnsafeBufferPointer { tonePtr in
                            guard let result = runAndroidCompatibleTTS(
                                textPtr,
                                Int32(speakerId),
                                speed,
                                noiseScale,
                                noiseScaleW,
                                sdpRatio,
                                bertPtr.baseAddress!,
                                jaBertPtr.baseAddress!,
                                Int32(bertFeatures.count),
                                Int32(jaBertFeatures.count),
                                phonePtr.baseAddress!,
                                tonePtr.baseAddress!,
                                Int32(phoneData.count)
                            ) else {
                                print("❌ Android 호환 TTS 추론 실패")
                                return nil
                            }
                            
                            let audioData = Array(UnsafeBufferPointer<Float>(
                                start: result.pointee.audio_data,
                                count: Int(result.pointee.audio_length)
                            ))
                            
                            // 메모리 정리
                            freeTTSResult(result)
                            
                            print("✅ Android 호환 TTS 추론 완료: \(audioData.count) samples")
                            return audioData
                        }
                    }
                }
            }
        }
    }
}
