//
//  MeloTTSInfer.h
//  meloTTS
//
//  Created by lyla on 8/28/25.
//

#ifndef MeloTTSInfer_h
#define MeloTTSInfer_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// TTS 추론 결과 구조체
typedef struct {
    float* audio_data;
    int audio_length;
    int sample_rate;
} TTSResult;

// TTS 추론 파라미터 구조체
typedef struct {
    const char* text;
    int speaker_id;
    float speed;
    float noise_scale;
    float noise_scale_w;
    float sdp_ratio;
} TTSParams;

// ONNX Runtime 초기화 (경로는 Swift에서 전달)
int initializeONNXRuntime(const char* bert_model_path, const char* tts_model_path);

// TTS 추론 실행 (구조체 방식 - 현재 사용 안 함)
TTSResult* runTTSInference(TTSParams* params);

// TTS 추론 실행 (개별 파라미터 방식)
TTSResult* runTTSInferenceWithParams(
    const char* text,
    int speaker_id,
    float speed,
    float noise_scale,
    float noise_scale_w,
    float sdp_ratio
);

// TTS 추론 실행 (BERT 특성 포함) - phone 데이터 추가
TTSResult* runTTSInferenceWithBertFeatures(
    const char* text,
    int speaker_id,
    float speed,
    float noise_scale,
    float noise_scale_w,
    float sdp_ratio,
    const float* bert_features,
    const float* ja_bert_features,
    int bert_length,
    int ja_bert_length,
    const int64_t* phone_data,
    const int64_t* tone_data,
    int phone_length
);

// BERT 추론 결과 구조체
typedef struct {
    float* bert_features;     // [batch_size * max_length * hidden_size]
    int batch_size;
    int max_length; 
    int hidden_size;
} BertResult;

// BERT 추론 실행 (텍스트 방식 - deprecated)
BertResult* runBertInference(const char* text);

// BERT 추론 실행 (토큰화된 IDs 방식 - 권장)
BertResult* runBertInferenceWithTokens(
    const int64_t* input_ids,
    const int64_t* attention_mask, 
    const int64_t* token_type_ids,
    int sequence_length
);

// BERT 결과 정리
void freeBertResult(BertResult* result);

// 결과 정리
void freeTTSResult(TTSResult* result);

// ONNX Runtime 정리
void cleanupONNXRuntime(void);

// Android 앱과 동일한 TTS 추론 (새로운 모델용)
TTSResult* runAndroidCompatibleTTS(
    const char* text,
    int32_t speaker_id,
    float speed,
    float noise_scale,
    float noise_scale_w,
    float sdp_ratio,
    const float* bert_features,
    const float* ja_bert_features,
    int32_t bert_length,
    int32_t ja_bert_length,
    const int64_t* phone_data,
    const int64_t* tone_data,
    int32_t phone_length
);

#ifdef __cplusplus
}
#endif

#endif /* MeloTTSInfer_h */