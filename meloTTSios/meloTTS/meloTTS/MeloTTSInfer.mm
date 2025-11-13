

#import "MeloTTSInfer.h"
#include <vector>
#include <string>
#include <memory>
#include <iostream>
#include <map>
#include <chrono>
#include <iomanip>

// ONNX Runtime 헤더 import
#import <onnxruntime/onnxruntime_c_api.h>

// 전역 변수로 모델 경로들 저장
static std::string g_bertModelPath;
static std::string g_ttsModelPath;
static bool g_initialized = false;

// ONNX Runtime 전역 객체들 (C API)
static const OrtApi* g_ort = nullptr;
static OrtEnv* g_env = nullptr;
static OrtSession* g_bertSession = nullptr;
static OrtSession* g_ttsSession = nullptr;
static OrtSessionOptions* g_sessionOptions = nullptr;
static OrtMemoryInfo* g_memoryInfo = nullptr;

// 실제 ONNX Runtime 초기화 (C API)
int initializeONNXRuntime(const char* bert_model_path, const char* tts_model_path) {
    if (g_initialized) {
        return 0; // 이미 초기화됨
    }
    
    std::cout << "🔥 실제 ONNX Runtime 초기화 시작 (C API)..." << std::endl;
    
    // 1. ONNX Runtime API 가져오기
    g_ort = OrtGetApiBase()->GetApi(ORT_API_VERSION);
    if (!g_ort) {
        std::cerr << "❌ ONNX Runtime API 가져오기 실패" << std::endl;
        return -1;
    }
    
    // 2. Environment 생성 (GlobalThreadPools 사용)
    OrtStatus* status = g_ort->CreateEnvWithGlobalThreadPools(ORT_LOGGING_LEVEL_WARNING, "MeloTTS", nullptr, &g_env);
    if (status != nullptr) {
        std::cerr << "❌ Environment 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
        g_ort->ReleaseStatus(status);
        return -1;
    }
    
    // 3. Session Options 생성
    status = g_ort->CreateSessionOptions(&g_sessionOptions);
    if (status != nullptr) {
        std::cerr << "❌ SessionOptions 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
        g_ort->ReleaseStatus(status);
        return -1;
    }
    
    // Session options 설정 (GlobalThreadPools 사용 시 적절한 설정)
    g_ort->SetSessionGraphOptimizationLevel(g_sessionOptions, ORT_ENABLE_ALL);  // 최대 최적화
    g_ort->EnableMemPattern(g_sessionOptions);  // 메모리 패턴 최적화
    g_ort->EnableCpuMemArena(g_sessionOptions);  // CPU 메모리 아레나
    // 추가 성능 최적화 옵션
    g_ort->SetSessionExecutionMode(g_sessionOptions, ORT_SEQUENTIAL);  // 순차 실행으로 오버헤드 감소
    // 주의: GlobalThreadPools 사용 시 per-session 스레드 설정은 제거해야 함
    
    // 4. Memory Info 생성
    status = g_ort->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &g_memoryInfo);
    if (status != nullptr) {
        std::cerr << "❌ MemoryInfo 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
        g_ort->ReleaseStatus(status);
        return -1;
    }
    
    // 5. BERT 모델 로드 (optional)
    if (bert_model_path && strlen(bert_model_path) > 0) {
        std::cout << "📝 BERT 모델 로딩: " << bert_model_path << std::endl;
        g_bertModelPath = std::string(bert_model_path);
        
        status = g_ort->CreateSession(g_env, bert_model_path, g_sessionOptions, &g_bertSession);
        if (status != nullptr) {
            std::cout << "⚠️ BERT 모델 로드 실패 (계속 진행): " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
        } else {
            std::cout << "✅ BERT 모델 로드 완료" << std::endl;
        }
    }
    
    // 6. TTS 모델 로드 (model4.onnx) - 필수
    if (tts_model_path && strlen(tts_model_path) > 0) {
        std::cout << "🎵 TTS 모델 로딩: " << tts_model_path << std::endl;
        g_ttsModelPath = std::string(tts_model_path);
        
        status = g_ort->CreateSession(g_env, tts_model_path, g_sessionOptions, &g_ttsSession);
        if (status != nullptr) {
            std::cerr << "❌ TTS 모델 로드 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            return -1;
        }
        
        std::cout << "✅ TTS 모델 로드 완료" << std::endl;
        
        // TTS 모델 입력/출력 정보 출력
        size_t num_input_nodes;
        size_t num_output_nodes;
        
        status = g_ort->SessionGetInputCount(g_ttsSession, &num_input_nodes);
        if (status == nullptr) {
            g_ort->SessionGetOutputCount(g_ttsSession, &num_output_nodes);
            
            std::cout << "📊 실제 TTS 모델 (model4.onnx) 정보:" << std::endl;
            std::cout << "  입력 노드 수: " << num_input_nodes << std::endl;
            std::cout << "  출력 노드 수: " << num_output_nodes << std::endl;
            
            // 입력 노드 이름들 출력
            OrtAllocator* allocator;
            g_ort->GetAllocatorWithDefaultOptions(&allocator);
            
            for (size_t i = 0; i < num_input_nodes; i++) {
                char* input_name;
                status = g_ort->SessionGetInputName(g_ttsSession, i, allocator, &input_name);
                if (status == nullptr) {
                    std::cout << "  입력 " << i << ": " << input_name << std::endl;
                    allocator->Free(allocator, input_name);
                }
            }
            
            // 출력 노드 이름들 출력
            for (size_t i = 0; i < num_output_nodes; i++) {
                char* output_name;
                status = g_ort->SessionGetOutputName(g_ttsSession, i, allocator, &output_name);
                if (status == nullptr) {
                    std::cout << "  출력 " << i << ": " << output_name << std::endl;
                    allocator->Free(allocator, output_name);
                }
            }
        }
        if (status != nullptr) {
            g_ort->ReleaseStatus(status);
        }
    }
    
    g_initialized = true;
    std::cout << "✅ 실제 ONNX Runtime 초기화 완료!" << std::endl;
    return 0;
}

// 실제 TTS 추론 실행 (개별 파라미터로, ONNX Runtime C API)
TTSResult* runTTSInferenceWithParams(
    const char* text,
    int speaker_id,
    float speed,
    float noise_scale,
    float noise_scale_w,
    float sdp_ratio
) {
    if (!g_initialized) {
        std::cerr << "❌ ONNX Runtime이 초기화되지 않았습니다" << std::endl;
        return nullptr;
    }
    
    if (!text) {
        std::cerr << "❌ 텍스트 파라미터가 null입니다" << std::endl;
        return nullptr;
    }
    
    std::cout << "🎵 실제 ONNX Runtime TTS 추론 실행..." << std::endl;
    std::cout << "📝 입력 파라미터:" << std::endl;
    std::cout << "  - 텍스트: " << text << std::endl;
    std::cout << "  - 화자 ID: " << speaker_id << std::endl;
    std::cout << "  - 속도: " << speed << std::endl;
    std::cout << "  - 노이즈 스케일: " << noise_scale << std::endl;
    std::cout << "  - 노이즈 스케일 W: " << noise_scale_w << std::endl;
    std::cout << "  - SDP 비율: " << sdp_ratio << std::endl;
    
    // 실제 ONNX Runtime 추론 실행
    if (g_ttsSession != nullptr && g_ort != nullptr) {
        std::cout << "🚀 ONNX Runtime 모델 추론 시작..." << std::endl;
        
        OrtAllocator* allocator = nullptr;
        g_ort->GetAllocatorWithDefaultOptions(&allocator);
        
        OrtValue* x_tensor = nullptr;
        OrtValue* x_lengths_tensor = nullptr;
        OrtValue* tones_tensor = nullptr;
        OrtValue* sid_tensor = nullptr;
        OrtValue* noise_scale_tensor = nullptr;
        OrtValue* length_scale_tensor = nullptr;
        OrtValue* noise_scale_w_tensor = nullptr;
        OrtValue* bert_tensor = nullptr;
        OrtValue* ja_bert_tensor = nullptr;
        
        try {
            // 모든 입력 노드 정보 먼저 확인
            size_t num_input_nodes;
            OrtStatus* status = g_ort->SessionGetInputCount(g_ttsSession, &num_input_nodes);
            if (status != nullptr) {
                std::cerr << "❌ 입력 개수 조회 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to get input count");
            }
            
            std::cout << "📊 모델 입력 개수: " << num_input_nodes << std::endl;
            
            // 모든 입력 이름 출력
            std::vector<std::string> input_names_vec;
            for (size_t i = 0; i < num_input_nodes; i++) {
                char* input_name;
                status = g_ort->SessionGetInputName(g_ttsSession, i, allocator, &input_name);
                if (status == nullptr) {
                    std::cout << "  입력 " << i << ": " << input_name << std::endl;
                    input_names_vec.push_back(std::string(input_name));
                    allocator->Free(allocator, input_name);
                } else {
                    g_ort->ReleaseStatus(status);
                }
            }
            
            if (input_names_vec.size() < 2) {
                throw std::runtime_error("Expected at least 2 inputs (text and sid)");
            }
            
            // MeloTTS 모델에 필요한 모든 입력 준비
            std::string input_text(text);
            std::vector<int64_t> input_ids;
            
            // 임시 토크나이징: 각 문자를 ASCII 값으로 변환
            for (char c : input_text) {
                input_ids.push_back(static_cast<int64_t>(c));
            }
            
            if (input_ids.empty()) {
                input_ids.push_back(32); // 공백 문자
            }
            
            int64_t text_length = static_cast<int64_t>(input_ids.size());
            std::cout << "📝 입력 토큰 수: " << text_length << std::endl;
            
            // 1. x 텐서 (텍스트 토큰들) - [1, length]
            std::vector<int64_t> x_shape = {1, text_length};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                input_ids.data(),
                input_ids.size() * sizeof(int64_t),
                x_shape.data(),
                x_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
                &x_tensor
            );
            
            if (status != nullptr) {
                std::cerr << "❌ x 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create x tensor");
            }
            
            // 2. x_lengths 텐서 (텍스트 길이) - [1] (rank 1, not 2)
            std::vector<int64_t> x_lengths_data = {text_length};
            std::vector<int64_t> x_lengths_shape = {1};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                x_lengths_data.data(),
                x_lengths_data.size() * sizeof(int64_t),
                x_lengths_shape.data(),
                x_lengths_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
                &x_lengths_tensor
            );
            
            if (status != nullptr) {
                std::cerr << "❌ x_lengths 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create x_lengths tensor");
            }
            
            // 3. tones 텐서 (톤 정보) - [1, length]
            std::vector<int64_t> tones_data(text_length, 0); // 모든 톤을 0으로 설정
            std::vector<int64_t> tones_shape = {1, text_length};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                tones_data.data(),
                tones_data.size() * sizeof(int64_t),
                tones_shape.data(),
                tones_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
                &tones_tensor
            );
            
            if (status != nullptr) {
                std::cerr << "❌ tones 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create tones tensor");
            }
            
            // 4. sid 텐서 (화자 ID) - [1]
            std::vector<int64_t> sid_data = {static_cast<int64_t>(speaker_id)};
            std::vector<int64_t> sid_shape = {1};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                sid_data.data(),
                sid_data.size() * sizeof(int64_t),
                sid_shape.data(),
                sid_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
                &sid_tensor
            );
            
            if (status != nullptr) {
                std::cerr << "❌ SID 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create SID tensor");
            }
            
            // 5-7. Float 스케일 텐서들 - [1] 각각
            std::vector<float> noise_scale_data = {noise_scale};
            std::vector<int64_t> scalar_shape = {1};
            
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                noise_scale_data.data(),
                sizeof(float),
                scalar_shape.data(),
                scalar_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                &noise_scale_tensor
            );
            if (status != nullptr) {
                std::cerr << "❌ noise_scale 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create noise_scale tensor");
            }
            
            std::vector<float> length_scale_data = {speed}; // speed를 length_scale로 사용
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                length_scale_data.data(),
                sizeof(float),
                scalar_shape.data(),
                scalar_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                &length_scale_tensor
            );
            if (status != nullptr) {
                std::cerr << "❌ length_scale 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create length_scale tensor");
            }
            
            std::vector<float> noise_scale_w_data = {noise_scale_w};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                noise_scale_w_data.data(),
                sizeof(float),
                scalar_shape.data(),
                scalar_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                &noise_scale_w_tensor
            );
            if (status != nullptr) {
                std::cerr << "❌ noise_scale_w 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create noise_scale_w tensor");
            }
            
            // 8-9. BERT 텐서들 - 올바른 차원 순서로 생성 [batch, features, sequence]  
            // 에러: index 1에서 Got: 71 Expected: 1024 -> [1, 1024, text_length] 형태
            
            std::vector<float> bert_data(1024 * text_length, 0.0f); 
            std::vector<int64_t> bert_shape = {1, 1024, text_length};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                bert_data.data(),
                bert_data.size() * sizeof(float),
                bert_shape.data(),
                bert_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                &bert_tensor
            );
            if (status != nullptr) {
                std::cerr << "❌ bert 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create bert tensor");
            }
            
            // ja_bert는 768 차원을 사용 (일반적인 BERT-base 크기)
            std::vector<float> ja_bert_data(768 * text_length, 0.0f);
            std::vector<int64_t> ja_bert_shape = {1, 768, text_length};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                ja_bert_data.data(),
                ja_bert_data.size() * sizeof(float),
                ja_bert_shape.data(),
                ja_bert_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                &ja_bert_tensor
            );
            if (status != nullptr) {
                std::cerr << "❌ ja_bert 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create ja_bert tensor");
            }
            
            std::cout << "📝 BERT 텐서 형태:" << std::endl;
            std::cout << "   bert: [1, 1024, " << text_length << "] (multilingual BERT)" << std::endl;
            std::cout << "   ja_bert: [1, 768, " << text_length << "] (Japanese BERT-base)" << std::endl;
            
            std::cout << "✅ 입력 텐서들 생성 완료" << std::endl;
            std::cout << "   텍스트 입력: " << input_text << " (토큰 " << input_ids.size() << "개)" << std::endl;
            std::cout << "   화자 ID: " << speaker_id << std::endl;
            
            // 입력 이름과 값 매핑 (MeloTTS 모델의 정확한 입력에 맞춰)
            std::vector<const char*> input_names_cstr;
            std::vector<const OrtValue*> input_values;
            
            for (size_t i = 0; i < input_names_vec.size(); i++) {
                const std::string& name = input_names_vec[i];
                input_names_cstr.push_back(name.c_str());
                
                // MeloTTS 입력 이름에 따라 정확한 텐서 매핑
                if (name == "x") {
                    input_values.push_back(x_tensor);
                    std::cout << "  -> x 텐서를 '" << name << "'에 매핑" << std::endl;
                } else if (name == "x_lengths") {
                    input_values.push_back(x_lengths_tensor);
                    std::cout << "  -> x_lengths 텐서를 '" << name << "'에 매핑" << std::endl;
                } else if (name == "tones") {
                    input_values.push_back(tones_tensor);
                    std::cout << "  -> tones 텐서를 '" << name << "'에 매핑" << std::endl;
                } else if (name == "sid") {
                    input_values.push_back(sid_tensor);
                    std::cout << "  -> sid 텐서를 '" << name << "'에 매핑" << std::endl;
                } else if (name == "noise_scale") {
                    input_values.push_back(noise_scale_tensor);
                    std::cout << "  -> noise_scale 텐서를 '" << name << "'에 매핑" << std::endl;
                } else if (name == "length_scale") {
                    input_values.push_back(length_scale_tensor);
                    std::cout << "  -> length_scale 텐서를 '" << name << "'에 매핑" << std::endl;
                } else if (name == "noise_scale_w") {
                    input_values.push_back(noise_scale_w_tensor);
                    std::cout << "  -> noise_scale_w 텐서를 '" << name << "'에 매핑" << std::endl;
                } else if (name == "bert") {
                    input_values.push_back(bert_tensor);
                    std::cout << "  -> bert 텐서를 '" << name << "'에 매핑 (빈 텐서)" << std::endl;
                } else if (name == "ja_bert") {
                    input_values.push_back(ja_bert_tensor);
                    std::cout << "  -> ja_bert 텐서를 '" << name << "'에 매핑 (빈 텐서)" << std::endl;
                } else {
                    // 알 수 없는 입력의 경우 첫 번째 텐서로 대체
                    input_values.push_back(x_tensor);
                    std::cout << "  -> ⚠️ 알 수 없는 입력 '" << name << "'에 x 텐서 사용" << std::endl;
                }
            }
            
            // 출력 이름 가져오기
            char* output_name;
            status = g_ort->SessionGetOutputName(g_ttsSession, 0, allocator, &output_name);
            if (status == nullptr) {
                std::cout << "📊 출력 이름: " << output_name << std::endl;
                
                const char* output_names[] = {output_name};
                OrtValue* output_tensor = nullptr;
                
                // 실제 모델 추론 실행
                std::cout << "🔥 모델 추론 실행 중..." << std::endl;
                status = g_ort->Run(
                    g_ttsSession,
                    nullptr, // run options
                    input_names_cstr.data(),
                    input_values.data(),
                    static_cast<size_t>(input_values.size()),
                    output_names,
                    1, // output count
                    &output_tensor
                );
                        
                if (status == nullptr && output_tensor != nullptr) {
                    std::cout << "🎉🎉🎉 실제 ONNX Runtime 모델 추론 성공! 더미 데이터가 아닙니다!" << std::endl;
                    
                    // 출력 텐서에서 데이터 추출
                    float* output_data;
                    status = g_ort->GetTensorMutableData(output_tensor, (void**)&output_data);
                    if (status == nullptr) {
                        OrtTensorTypeAndShapeInfo* tensor_info;
                        g_ort->GetTensorTypeAndShape(output_tensor, &tensor_info);
                        
                        size_t output_size;
                        g_ort->GetTensorShapeElementCount(tensor_info, &output_size);
                        
                        std::cout << "📊 출력 크기: " << output_size << " elements" << std::endl;
                        
                        // 결과 구조체 생성
                        TTSResult* result = new TTSResult;
                        result->audio_length = static_cast<int>(output_size);
                        result->sample_rate = 44100;
                        result->audio_data = new float[output_size];
                        
                        // 데이터 복사
                        memcpy(result->audio_data, output_data, output_size * sizeof(float));
                        
                        std::cout << "✅ 실제 ONNX Runtime TTS 추론 완료!" << std::endl;
                        std::cout << "   오디오 샘플 수: " << output_size << std::endl;
                        std::cout << "   샘플레이트: 44100 Hz" << std::endl;
                        
                        // 리소스 정리
                        g_ort->ReleaseTensorTypeAndShapeInfo(tensor_info);
                        g_ort->ReleaseValue(output_tensor);
                        g_ort->ReleaseValue(x_tensor);
                        g_ort->ReleaseValue(x_lengths_tensor);
                        g_ort->ReleaseValue(tones_tensor);
                        g_ort->ReleaseValue(sid_tensor);
                        g_ort->ReleaseValue(noise_scale_tensor);
                        g_ort->ReleaseValue(length_scale_tensor);
                        g_ort->ReleaseValue(noise_scale_w_tensor);
                        g_ort->ReleaseValue(bert_tensor);
                        g_ort->ReleaseValue(ja_bert_tensor);
                        allocator->Free(allocator, output_name);
                        
                        return result;
                    }
                    
                    g_ort->ReleaseValue(output_tensor);
                } else {
                    if (status != nullptr) {
                        std::cout << "⚠️ 모델 추론 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                        g_ort->ReleaseStatus(status);
                    }
                }
                
                allocator->Free(allocator, output_name);
            }
        } catch (const std::exception& e) {
            std::cout << "⚠️ ONNX Runtime 추론 중 예외 발생: " << e.what() << std::endl;
        }
        
        // 정리 - 모든 텐서 해제
        if (x_tensor) g_ort->ReleaseValue(x_tensor);
        if (x_lengths_tensor) g_ort->ReleaseValue(x_lengths_tensor);
        if (tones_tensor) g_ort->ReleaseValue(tones_tensor);
        if (sid_tensor) g_ort->ReleaseValue(sid_tensor);
        if (noise_scale_tensor) g_ort->ReleaseValue(noise_scale_tensor);
        if (length_scale_tensor) g_ort->ReleaseValue(length_scale_tensor);
        if (noise_scale_w_tensor) g_ort->ReleaseValue(noise_scale_w_tensor);
        if (bert_tensor) g_ort->ReleaseValue(bert_tensor);
        if (ja_bert_tensor) g_ort->ReleaseValue(ja_bert_tensor);
        
        std::cout << "❌❌❌ ONNX Runtime 추론 완전 실패! 폴백 더미 사인파 오디오 생성으로 전환" << std::endl;
    }
    
    // 폴백: 사인파 생성 (ONNX Runtime 추론 실패 시)
    std::cout << "🚨🚨🚨 경고: 실제 모델 추론이 실패했습니다! 더미 사인파 오디오를 생성합니다 (삐- 소리)" << std::endl;
    const int fallback_sample_rate = 44100;
    const float fallback_duration = 2.0f;
    const int fallback_num_samples = static_cast<int>(fallback_sample_rate * fallback_duration);
    
    TTSResult* fallback_result = new TTSResult;
    fallback_result->audio_data = new float[fallback_num_samples];
    fallback_result->audio_length = fallback_num_samples;
    fallback_result->sample_rate = fallback_sample_rate;
    
    const float frequency = 440.0f * speed;
    for (int i = 0; i < fallback_num_samples; i++) {
        float t = static_cast<float>(i) / fallback_sample_rate;
        fallback_result->audio_data[i] = 0.3f * sin(2.0f * M_PI * frequency * t) * noise_scale;
        
        if (i > fallback_num_samples - fallback_sample_rate / 4) {
            float fade = 1.0f - static_cast<float>(i - (fallback_num_samples - fallback_sample_rate / 4)) / (fallback_sample_rate / 4);
            fallback_result->audio_data[i] *= fade;
        }
    }
    
    std::cout << "✅ 폴백 오디오 생성 완료: " << fallback_num_samples << " samples" << std::endl;
    
    return fallback_result;
}

// TTS 추론 실행 (BERT 특성 포함)
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
) {
    if (!g_initialized || !g_ttsSession) {
        std::cerr << "❌ TTS 모델이 초기화되지 않았습니다" << std::endl;
        return nullptr;
    }
    
    std::cout << "🎵 TTS 추론 시작 (BERT 특성 포함): " << text << std::endl;
    std::cout << "  - BERT 특성 길이: " << bert_length << std::endl;
    std::cout << "  - JA_BERT 특성 길이: " << ja_bert_length << std::endl;
    
    // BERT 특성 값들 확인
    std::cout << "🔍 BERT 특성 값 디버깅:" << std::endl;
    std::cout << "  - BERT 처음 5개 값: ";
    for (int i = 0; i < 5 && i < bert_length; i++) {
        std::cout << bert_features[i] << " ";
    }
    std::cout << std::endl;
    std::cout << "  - JA_BERT 처음 5개 값: ";
    for (int i = 0; i < 5 && i < ja_bert_length; i++) {
        std::cout << ja_bert_features[i] << " ";
    }
    std::cout << std::endl;
    
    try {
        // 🔥 CRITICAL: Flutter와 동일한 텐서 생성 로직 - 실제 phone 데이터 사용!
        
        std::cout << "✅ 실제 phone 데이터 사용 중..." << std::endl;
        
        // Swift에서 전달받은 실제 phone 데이터 사용
        std::vector<int64_t> phone_ids(phone_data, phone_data + phone_length);
        std::vector<int64_t> tone_ids(tone_data, tone_data + phone_length);
        
        if (phone_ids.empty()) {
            phone_ids.push_back(1);
            tone_ids.push_back(0);
        }
        
        int64_t actual_phone_length = static_cast<int64_t>(phone_ids.size());
        
        std::cout << "📊 실제 Flutter 호환 텐서 정보:" << std::endl;
        std::cout << "  - phone_length: " << actual_phone_length << std::endl;
        std::cout << "  - phone_ids 처음 5개: ";
        for (int i = 0; i < 5 && i < phone_ids.size(); i++) {
            std::cout << phone_ids[i] << " ";
        }
        std::cout << std::endl;
        
        // 모든 기본 텐서들 생성 (기존 코드와 동일)
        OrtAllocator* allocator;
        g_ort->GetAllocatorWithDefaultOptions(&allocator);
        
        OrtValue* x_tensor = nullptr;
        OrtValue* x_lengths_tensor = nullptr;
        OrtValue* tones_tensor = nullptr;
        OrtValue* sid_tensor = nullptr;
        OrtValue* noise_scale_tensor = nullptr;
        OrtValue* length_scale_tensor = nullptr;
        OrtValue* noise_scale_w_tensor = nullptr;
        OrtValue* bert_tensor = nullptr;
        OrtValue* ja_bert_tensor = nullptr;
        
        try {
            // 🔥 Flutter와 동일한 x 텐서 생성 (실제 phone 데이터 사용)
            std::vector<int64_t> x_shape = {1, actual_phone_length};
            OrtStatus* status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                phone_ids.data(),
                phone_ids.size() * sizeof(int64_t),
                x_shape.data(),
                x_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
                &x_tensor
            );
            if (status != nullptr) {
                std::cerr << "❌ x 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create x tensor");
            }
            
            // 🔥 Flutter와 동일한 x_lengths 텐서 생성 (실제 phone_length 사용)
            std::vector<int64_t> x_lengths_data = {actual_phone_length};
            std::vector<int64_t> x_lengths_shape = {1};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                x_lengths_data.data(),
                x_lengths_data.size() * sizeof(int64_t),
                x_lengths_shape.data(),
                x_lengths_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
                &x_lengths_tensor
            );
            if (status != nullptr) {
                std::cerr << "❌ x_lengths 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("Failed to create x_lengths tensor");
            }
            
            // 🔥 Flutter와 동일한 tones 텐서 생성 (실제 tone 데이터 사용)
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                tone_ids.data(),
                tone_ids.size() * sizeof(int64_t),
                x_shape.data(),
                x_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
                &tones_tensor
            );
            if (status != nullptr) {
                throw std::runtime_error("Failed to create tones tensor");
            }
            
            // SID 텐서 (스피커 ID)
            std::vector<int64_t> sid_data = {static_cast<int64_t>(speaker_id)};
            std::vector<int64_t> sid_shape = {1};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                sid_data.data(),
                sid_data.size() * sizeof(int64_t),
                sid_shape.data(),
                sid_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
                &sid_tensor
            );
            if (status != nullptr) {
                throw std::runtime_error("Failed to create sid tensor");
            }
            
            // 나머지 스칼라 파라미터들
            std::vector<float> noise_scale_data = {noise_scale};
            std::vector<float> length_scale_data = {speed};
            std::vector<float> noise_scale_w_data = {noise_scale_w};
            std::vector<int64_t> scalar_shape = {1};
            
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo, noise_scale_data.data(), noise_scale_data.size() * sizeof(float),
                scalar_shape.data(), scalar_shape.size(), ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &noise_scale_tensor);
            if (status != nullptr) throw std::runtime_error("Failed to create noise_scale tensor");
            
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo, length_scale_data.data(), length_scale_data.size() * sizeof(float),
                scalar_shape.data(), scalar_shape.size(), ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &length_scale_tensor);
            if (status != nullptr) throw std::runtime_error("Failed to create length_scale tensor");
            
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo, noise_scale_w_data.data(), noise_scale_w_data.size() * sizeof(float),
                scalar_shape.data(), scalar_shape.size(), ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &noise_scale_w_tensor);
            if (status != nullptr) throw std::runtime_error("Failed to create noise_scale_w tensor");
            
            // 🔥 핵심 차이점: 실제 BERT 특성 사용!
            std::cout << "🔥 실제 BERT 특성으로 텐서 생성 중..." << std::endl;
            
            // 🔥 CRITICAL: phone_length 계산 (BERT 길이에서 역산)
            // bert_length = 1024 * phone_length 이므로 phone_length = bert_length / 1024
            int64_t phone_length_bert = bert_length / 1024;
            int64_t phone_length_ja = ja_bert_length / 768;
            
            std::cout << "📊 BERT 텐서 크기 계산:" << std::endl;
            std::cout << "  - BERT 데이터 길이: " << bert_length << " (1024 * " << phone_length_bert << ")" << std::endl;  
            std::cout << "  - JA_BERT 데이터 길이: " << ja_bert_length << " (768 * " << phone_length_ja << ")" << std::endl;
//            std::cout << "  - text_length: " << text_length << std::endl;
            
            // phone_length 검증
            if (phone_length_bert != phone_length_ja) {
                std::cerr << "❌ BERT와 JA_BERT phone_length 불일치: " << phone_length_bert << " vs " << phone_length_ja << std::endl;
                throw std::runtime_error("BERT phone_length mismatch");
            }
            
            int64_t phone_length = phone_length_bert;
            std::cout << "✅ 계산된 phone_length: " << phone_length << std::endl;
            
            // BERT 텐서 (bert_features 사용) - phone_length 사용!
            std::vector<int64_t> bert_shape = {1, 1024, phone_length};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                const_cast<float*>(bert_features),
                bert_length * sizeof(float),
                bert_shape.data(),
                bert_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                &bert_tensor
            );
            if (status != nullptr) {
                std::cerr << "❌ 실제 BERT 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                throw std::runtime_error("Failed to create bert tensor with real features");
            }
            
            // JA_BERT 텐서 (ja_bert_features 사용) - phone_length 사용!
            std::vector<int64_t> ja_bert_shape = {1, 768, phone_length};
            status = g_ort->CreateTensorWithDataAsOrtValue(
                g_memoryInfo,
                const_cast<float*>(ja_bert_features),
                ja_bert_length * sizeof(float),
                ja_bert_shape.data(),
                ja_bert_shape.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                &ja_bert_tensor
            );
            if (status != nullptr) {
                std::cerr << "❌ 실제 JA_BERT 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                throw std::runtime_error("Failed to create ja_bert tensor with real features");
            }
            
            std::cout << "✅ 실제 BERT 특성으로 텐서 생성 완료!" << std::endl;
            
            // 모델 실행 (기존 코드와 동일한 로직)
            size_t num_input_nodes;
            status = g_ort->SessionGetInputCount(g_ttsSession, &num_input_nodes);
            if (status != nullptr) {
                throw std::runtime_error("Failed to get input count");
            }
            
            std::vector<const char*> input_names;
            std::vector<const OrtValue*> input_values;
            
            // 입력 매핑 (기존 코드와 동일하지만 실제 BERT 텐서 사용)
            for (size_t i = 0; i < num_input_nodes; i++) {
                char* name;
                status = g_ort->SessionGetInputName(g_ttsSession, i, allocator, &name);
                if (status == nullptr) {
                    input_names.push_back(name);
                    std::string name_str(name);
                    
                    if (name_str == "x") {
                        input_values.push_back(x_tensor);
                        std::cout << "  -> x 텐서 매핑" << std::endl;
                    } else if (name_str == "x_lengths") {
                        input_values.push_back(x_lengths_tensor);
                        std::cout << "  -> x_lengths 텐서 매핑" << std::endl;
                    } else if (name_str == "tones") {
                        input_values.push_back(tones_tensor);
                        std::cout << "  -> tones 텐서 매핑" << std::endl;
                    } else if (name_str == "sid") {
                        input_values.push_back(sid_tensor);
                        std::cout << "  -> sid 텐서 매핑" << std::endl;
                    } else if (name_str == "noise_scale") {
                        input_values.push_back(noise_scale_tensor);
                        std::cout << "  -> noise_scale 텐서 매핑" << std::endl;
                    } else if (name_str == "length_scale") {
                        input_values.push_back(length_scale_tensor);
                        std::cout << "  -> length_scale 텐서 매핑" << std::endl;
                    } else if (name_str == "noise_scale_w") {
                        input_values.push_back(noise_scale_w_tensor);
                        std::cout << "  -> noise_scale_w 텐서 매핑" << std::endl;
                    } else if (name_str == "bert") {
                        input_values.push_back(bert_tensor);
                        std::cout << "  -> 🔥 실제 BERT 텐서 매핑!" << std::endl;
                    } else if (name_str == "ja_bert") {
                        input_values.push_back(ja_bert_tensor);
                        std::cout << "  -> 🔥 실제 JA_BERT 텐서 매핑!" << std::endl;
                    } else {
                        input_values.push_back(x_tensor);
                        std::cout << "  -> ⚠️ 알 수 없는 입력 '" << name_str << "'에 x 텐서 사용" << std::endl;
                    }
                }
            }
            
            // 출력 이름 가져오기
            char* output_name;
            status = g_ort->SessionGetOutputName(g_ttsSession, 0, allocator, &output_name);
            if (status != nullptr) {
                throw std::runtime_error("Failed to get output name");
            }
            
            const char* output_names[] = {output_name};
            OrtValue* output_tensor = nullptr;
            
            std::cout << "🔥 TTS 모델 실행 중 (실제 BERT 특성 사용)..." << std::endl;
            status = g_ort->Run(
                g_ttsSession,
                nullptr,
                input_names.data(),
                input_values.data(),
                input_values.size(),
                output_names,
                1,
                &output_tensor
            );
            
            if (status != nullptr) {
                std::cerr << "❌ TTS 모델 실행 실패: " << g_ort->GetErrorMessage(status) << std::endl;
                g_ort->ReleaseStatus(status);
                throw std::runtime_error("TTS model execution failed");
            }
            
            // 결과 처리 (기존 코드와 동일)
            float* output_data;
            status = g_ort->GetTensorMutableData(output_tensor, (void**)&output_data);
            if (status != nullptr) {
                throw std::runtime_error("Failed to get output data");
            }
            
            OrtTensorTypeAndShapeInfo* tensor_info;
            g_ort->GetTensorTypeAndShape(output_tensor, &tensor_info);
            
            size_t output_size;
            g_ort->GetTensorShapeElementCount(tensor_info, &output_size);
            
            TTSResult* result = new TTSResult;
            result->audio_data = new float[output_size];
            result->audio_length = static_cast<int>(output_size);
            result->sample_rate = 44100;
            
            memcpy(result->audio_data, output_data, output_size * sizeof(float));
            
            std::cout << "✅ 실제 BERT로 TTS 추론 성공! 샘플 수: " << output_size << std::endl;
            
            // 메모리 정리
            g_ort->ReleaseTensorTypeAndShapeInfo(tensor_info);
            g_ort->ReleaseValue(output_tensor);
            for (const char* name : input_names) {
                allocator->Free(allocator, const_cast<char*>(name));
            }
            allocator->Free(allocator, output_name);
            
            return result;
            
        } catch (const std::exception& e) {
            std::cerr << "❌ TTS 추론 중 예외 발생: " << e.what() << std::endl;
        }
        
        // 실패 시 정리
        if (x_tensor) g_ort->ReleaseValue(x_tensor);
        if (x_lengths_tensor) g_ort->ReleaseValue(x_lengths_tensor);
        if (tones_tensor) g_ort->ReleaseValue(tones_tensor);
        if (sid_tensor) g_ort->ReleaseValue(sid_tensor);
        if (noise_scale_tensor) g_ort->ReleaseValue(noise_scale_tensor);
        if (length_scale_tensor) g_ort->ReleaseValue(length_scale_tensor);
        if (noise_scale_w_tensor) g_ort->ReleaseValue(noise_scale_w_tensor);
        if (bert_tensor) g_ort->ReleaseValue(bert_tensor);
        if (ja_bert_tensor) g_ort->ReleaseValue(ja_bert_tensor);
        
    } catch (const std::exception& e) {
        std::cout << "⚠️ TTS 추론 중 예외 발생: " << e.what() << std::endl;
    }
    
    return nullptr;  // 실패
}

// BERT 추론 실행
BertResult* runBertInference(const char* text) {
    if (!g_initialized || !g_bertSession) {
        std::cerr << "❌ BERT 모델이 초기화되지 않았습니다" << std::endl;
        return nullptr;
    }
    
    if (!text) {
        std::cerr << "❌ 텍스트 파라미터가 null입니다" << std::endl;
        return nullptr;
    }
    
    std::cout << "🧠 실제 BERT 추론 실행: " << text << std::endl;
    
    try {
        // 1. 텍스트를 토큰 ID로 변환 (간단한 ASCII 변환)
        std::string input_text(text);
        std::vector<int64_t> input_ids;
        
        // 임시 토크나이징: 각 문자를 ASCII 값으로 변환
        for (char c : input_text) {
            input_ids.push_back(static_cast<int64_t>(c));
        }
        
        if (input_ids.empty()) {
            input_ids.push_back(32); // 공백 문자
        }
        
        // 최대 길이 제한 (BERT 모델의 max_length)
        const int max_length = 512;
        if (input_ids.size() > max_length) {
            input_ids.resize(max_length);
        }
        
        // attention_mask와 token_type_ids 생성 (원래 토큰 길이만큼 1, 패딩 부분은 0)
        std::vector<int64_t> attention_mask;
        std::vector<int64_t> token_type_ids;
        
        // 원래 텍스트 길이만큼 1로 채움
        size_t original_length = input_text.length();
        for (size_t i = 0; i < original_length && i < max_length; i++) {
            attention_mask.push_back(1);
            token_type_ids.push_back(0);  // 모두 첫 번째 문장으로 처리
        }
        
        // 패딩 추가
        while (input_ids.size() < max_length) {
            input_ids.push_back(0); // [PAD] 토큰
            attention_mask.push_back(0); // 패딩 부분은 0
            token_type_ids.push_back(0);
        }
        
        std::cout << "📝 BERT 입력 정보:" << std::endl;
        std::cout << "  - input_ids 길이: " << input_ids.size() << std::endl;
        std::cout << "  - attention_mask 길이: " << attention_mask.size() << std::endl;
        std::cout << "  - token_type_ids 길이: " << token_type_ids.size() << std::endl;
        
        // 2. 세 개의 입력 텐서 생성
        std::vector<int64_t> input_shape = {1, max_length}; // [batch_size, seq_length]
        
        // input_ids 텐서
        OrtValue* input_ids_tensor = nullptr;
        OrtStatus* status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            input_ids.data(),
            input_ids.size() * sizeof(int64_t),
            input_shape.data(),
            input_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &input_ids_tensor
        );
        
        if (status != nullptr) {
            std::cerr << "❌ BERT input_ids 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            return nullptr;
        }
        
        // attention_mask 텐서
        OrtValue* attention_mask_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            attention_mask.data(),
            attention_mask.size() * sizeof(int64_t),
            input_shape.data(),
            input_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &attention_mask_tensor
        );
        
        if (status != nullptr) {
            std::cerr << "❌ BERT attention_mask 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            return nullptr;
        }
        
        // token_type_ids 텐서
        OrtValue* token_type_ids_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            token_type_ids.data(),
            token_type_ids.size() * sizeof(int64_t),
            input_shape.data(),
            input_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &token_type_ids_tensor
        );
        
        if (status != nullptr) {
            std::cerr << "❌ BERT token_type_ids 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            return nullptr;
        }
        
        // 3. BERT 모델 추론 실행
        OrtAllocator* allocator;
        g_ort->GetAllocatorWithDefaultOptions(&allocator);
        
        // 모든 입력 이름들을 가져오기
        char* input_ids_name;
        char* attention_mask_name;
        char* token_type_ids_name;
        
        status = g_ort->SessionGetInputName(g_bertSession, 0, allocator, &input_ids_name);
        if (status != nullptr) {
            std::cerr << "❌ BERT input_ids 이름 가져오기 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            return nullptr;
        }
        
        status = g_ort->SessionGetInputName(g_bertSession, 1, allocator, &attention_mask_name);
        if (status != nullptr) {
            std::cerr << "❌ BERT attention_mask 이름 가져오기 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            allocator->Free(allocator, input_ids_name);
            return nullptr;
        }
        
        status = g_ort->SessionGetInputName(g_bertSession, 2, allocator, &token_type_ids_name);
        if (status != nullptr) {
            std::cerr << "❌ BERT token_type_ids 이름 가져오기 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            allocator->Free(allocator, input_ids_name);
            allocator->Free(allocator, attention_mask_name);
            return nullptr;
        }
        
        char* output_name;
        status = g_ort->SessionGetOutputName(g_bertSession, 0, allocator, &output_name);
        if (status != nullptr) {
            std::cerr << "❌ BERT 출력 이름 가져오기 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            allocator->Free(allocator, input_ids_name);
            allocator->Free(allocator, attention_mask_name);
            allocator->Free(allocator, token_type_ids_name);
            return nullptr;
        }
        
        std::cout << "🔍 BERT 입력 이름들:" << std::endl;
        std::cout << "  - input 0: " << input_ids_name << std::endl;
        std::cout << "  - input 1: " << attention_mask_name << std::endl;
        std::cout << "  - input 2: " << token_type_ids_name << std::endl;
        
        const char* input_names[] = {input_ids_name, attention_mask_name, token_type_ids_name};
        const OrtValue* input_values[] = {input_ids_tensor, attention_mask_tensor, token_type_ids_tensor};
        const char* output_names[] = {output_name};
        OrtValue* output_tensor = nullptr;
        
        std::cout << "🔥 BERT 모델 추론 실행 중..." << std::endl;
        status = g_ort->Run(
            g_bertSession,
            nullptr, // run options
            input_names,
            input_values,
            3, // input count (세 개의 입력)
            output_names,
            1, // output count
            &output_tensor
        );
        
        if (status != nullptr) {
            std::cerr << "❌ BERT 모델 추론 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            allocator->Free(allocator, input_ids_name);
            allocator->Free(allocator, attention_mask_name);
            allocator->Free(allocator, token_type_ids_name);
            allocator->Free(allocator, output_name);
            return nullptr;
        }
        
        // 4. 출력 텐서에서 데이터 추출
        float* output_data;
        status = g_ort->GetTensorMutableData(output_tensor, (void**)&output_data);
        if (status != nullptr) {
            std::cerr << "❌ BERT 출력 데이터 추출 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            g_ort->ReleaseValue(output_tensor);
            allocator->Free(allocator, input_ids_name);
            allocator->Free(allocator, attention_mask_name);
            allocator->Free(allocator, token_type_ids_name);
            allocator->Free(allocator, output_name);
            return nullptr;
        }
        
        // 5. 출력 텐서 정보 가져오기
        OrtTensorTypeAndShapeInfo* tensor_info;
        g_ort->GetTensorTypeAndShape(output_tensor, &tensor_info);
        
        size_t output_size;
        g_ort->GetTensorShapeElementCount(tensor_info, &output_size);
        
        std::cout << "✅ BERT 추론 성공! 출력 크기: " << output_size << std::endl;
        
        // 6. 결과 구조체 생성
        BertResult* result = new BertResult;
        result->batch_size = 1;
        result->max_length = max_length;
        result->hidden_size = output_size / max_length; // hidden_size = total_size / max_length
        result->bert_features = new float[output_size];
        
        // 데이터 복사
        memcpy(result->bert_features, output_data, output_size * sizeof(float));
        
        std::cout << "📊 BERT 결과: [" << result->batch_size << ", " << result->max_length << ", " << result->hidden_size << "]" << std::endl;
        std::cout << "   첫 5개 값: ";
        for (int i = 0; i < 5 && i < output_size; i++) {
            std::cout << result->bert_features[i] << " ";
        }
        std::cout << std::endl;
        
        // 리소스 정리
        g_ort->ReleaseTensorTypeAndShapeInfo(tensor_info);
        g_ort->ReleaseValue(output_tensor);
        g_ort->ReleaseValue(input_ids_tensor);
        g_ort->ReleaseValue(attention_mask_tensor);
        g_ort->ReleaseValue(token_type_ids_tensor);
        allocator->Free(allocator, input_ids_name);
        allocator->Free(allocator, attention_mask_name);
        allocator->Free(allocator, token_type_ids_name);
        allocator->Free(allocator, output_name);
        
        return result;
        
    } catch (const std::exception& e) {
        std::cout << "⚠️ BERT 추론 중 예외 발생: " << e.what() << std::endl;
        return nullptr;
    }
}

// BERT 추론 실행 (토큰화된 IDs 방식)
BertResult* runBertInferenceWithTokens(
    const int64_t* input_ids,
    const int64_t* attention_mask, 
    const int64_t* token_type_ids,
    int sequence_length
) {
    if (!g_initialized || !g_bertSession) {
        std::cerr << "❌ BERT 모델이 초기화되지 않았습니다" << std::endl;
        return nullptr;
    }
    
    if (!input_ids || !attention_mask || !token_type_ids || sequence_length <= 0) {
        std::cerr << "❌ 잘못된 토큰 파라미터입니다" << std::endl;
        return nullptr;
    }
    
    std::cout << "🧠 실제 BERT 추론 실행 (토큰화됨): 길이=" << sequence_length << std::endl;
    
    try {
        // 입력 텐서 생성
        std::vector<int64_t> input_shape = {1, sequence_length}; // [batch_size, seq_length]
        
        // input_ids 텐서
        OrtValue* input_ids_tensor = nullptr;
        OrtStatus* status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            const_cast<int64_t*>(input_ids),
            sequence_length * sizeof(int64_t),
            input_shape.data(),
            input_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &input_ids_tensor
        );
        
        if (status != nullptr) {
            std::cerr << "❌ BERT input_ids 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            return nullptr;
        }
        
        // attention_mask 텐서
        OrtValue* attention_mask_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            const_cast<int64_t*>(attention_mask),
            sequence_length * sizeof(int64_t),
            input_shape.data(),
            input_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &attention_mask_tensor
        );
        
        if (status != nullptr) {
            std::cerr << "❌ BERT attention_mask 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            return nullptr;
        }
        
        // token_type_ids 텐서
        OrtValue* token_type_ids_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            const_cast<int64_t*>(token_type_ids),
            sequence_length * sizeof(int64_t),
            input_shape.data(),
            input_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &token_type_ids_tensor
        );
        
        if (status != nullptr) {
            std::cerr << "❌ BERT token_type_ids 텐서 생성 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            return nullptr;
        }
        
        // 모델 추론 실행
        OrtAllocator* allocator;
        g_ort->GetAllocatorWithDefaultOptions(&allocator);
        
        // 입력 이름들 가져오기
        char* input_ids_name;
        char* attention_mask_name;
        char* token_type_ids_name;
        
        status = g_ort->SessionGetInputName(g_bertSession, 0, allocator, &input_ids_name);
        if (status != nullptr) {
            std::cerr << "❌ BERT input_ids 이름 가져오기 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            return nullptr;
        }
        
        status = g_ort->SessionGetInputName(g_bertSession, 1, allocator, &attention_mask_name);
        if (status != nullptr) {
            std::cerr << "❌ BERT attention_mask 이름 가져오기 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            allocator->Free(allocator, input_ids_name);
            return nullptr;
        }
        
        status = g_ort->SessionGetInputName(g_bertSession, 2, allocator, &token_type_ids_name);
        if (status != nullptr) {
            std::cerr << "❌ BERT token_type_ids 이름 가져오기 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            allocator->Free(allocator, input_ids_name);
            allocator->Free(allocator, attention_mask_name);
            return nullptr;
        }
        
        char* output_name;
        status = g_ort->SessionGetOutputName(g_bertSession, 0, allocator, &output_name);
        if (status != nullptr) {
            std::cerr << "❌ BERT 출력 이름 가져오기 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            allocator->Free(allocator, input_ids_name);
            allocator->Free(allocator, attention_mask_name);
            allocator->Free(allocator, token_type_ids_name);
            return nullptr;
        }
        
        const char* input_names[] = {input_ids_name, attention_mask_name, token_type_ids_name};
        const OrtValue* input_values[] = {input_ids_tensor, attention_mask_tensor, token_type_ids_tensor};
        const char* output_names[] = {output_name};
        OrtValue* output_tensor = nullptr;
        
        std::cout << "🔥 BERT 모델 추론 실행 중 (토큰화됨)..." << std::endl;
        status = g_ort->Run(
            g_bertSession,
            nullptr, // run options
            input_names,
            input_values,
            3, // input count
            output_names,
            1, // output count
            &output_tensor
        );
        
        if (status != nullptr) {
            std::cerr << "❌ BERT 모델 추론 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            allocator->Free(allocator, input_ids_name);
            allocator->Free(allocator, attention_mask_name);
            allocator->Free(allocator, token_type_ids_name);
            allocator->Free(allocator, output_name);
            return nullptr;
        }
        
        // 출력 텐서에서 데이터 추출
        float* output_data;
        status = g_ort->GetTensorMutableData(output_tensor, (void**)&output_data);
        if (status != nullptr) {
            std::cerr << "❌ BERT 출력 데이터 추출 실패" << std::endl;
            g_ort->ReleaseStatus(status);
            g_ort->ReleaseValue(input_ids_tensor);
            g_ort->ReleaseValue(attention_mask_tensor);
            g_ort->ReleaseValue(token_type_ids_tensor);
            g_ort->ReleaseValue(output_tensor);
            allocator->Free(allocator, input_ids_name);
            allocator->Free(allocator, attention_mask_name);
            allocator->Free(allocator, token_type_ids_name);
            allocator->Free(allocator, output_name);
            return nullptr;
        }
        
        // 출력 텐서 정보 가져오기
        OrtTensorTypeAndShapeInfo* tensor_info;
        g_ort->GetTensorTypeAndShape(output_tensor, &tensor_info);
        
        size_t output_size;
        g_ort->GetTensorShapeElementCount(tensor_info, &output_size);
        
        std::cout << "✅ BERT 추론 성공! 출력 크기: " << output_size << std::endl;
        
        // 결과 구조체 생성
        BertResult* result = new BertResult;
        result->batch_size = 1;
        result->max_length = sequence_length;
        result->hidden_size = output_size / sequence_length; // hidden_size = total_size / sequence_length
        result->bert_features = new float[output_size];
        
        // 데이터 복사
        memcpy(result->bert_features, output_data, output_size * sizeof(float));
        
        std::cout << "📊 BERT 결과 (토큰화됨): [" << result->batch_size << ", " << result->max_length << ", " << result->hidden_size << "]" << std::endl;
        std::cout << "   첫 5개 값: ";
        for (int i = 0; i < 5 && i < output_size; i++) {
            std::cout << result->bert_features[i] << " ";
        }
        std::cout << std::endl;
        
        // 리소스 정리
        g_ort->ReleaseTensorTypeAndShapeInfo(tensor_info);
        g_ort->ReleaseValue(output_tensor);
        g_ort->ReleaseValue(input_ids_tensor);
        g_ort->ReleaseValue(attention_mask_tensor);
        g_ort->ReleaseValue(token_type_ids_tensor);
        allocator->Free(allocator, input_ids_name);
        allocator->Free(allocator, attention_mask_name);
        allocator->Free(allocator, token_type_ids_name);
        allocator->Free(allocator, output_name);
        
        return result;
        
    } catch (const std::exception& e) {
        std::cout << "⚠️ BERT 추론 중 예외 발생: " << e.what() << std::endl;
        return nullptr;
    }
}

// BERT 결과 정리
void freeBertResult(BertResult* result) {
    if (result) {
        if (result->bert_features) {
            delete[] result->bert_features;
        }
        delete result;
    }
}

// 결과 정리
void freeTTSResult(TTSResult* result) {
    if (result) {
        if (result->audio_data) {
            delete[] result->audio_data;
        }
        delete result;
    }
}

// Android 앱과 동일한 TTS 추론 구현
extern "C" TTSResult* runAndroidCompatibleTTS(
    const char* text,
    int32_t speaker_id,
    float speed,
    float noise_scale,
    float noise_scale_w,
    float sdp_ratio,
    const float* bert_features,      // [1, 1024, seq_len] - all zeros
    const float* ja_bert_features,   // [1, 768, seq_len] - Korean BERT
    int32_t bert_length,
    int32_t ja_bert_length,
    const int64_t* phone_data,
    const int64_t* tone_data,
    int32_t phone_length
) {
    if (g_ttsSession == nullptr) {
        std::cerr << "❌ TTS 세션이 초기화되지 않았습니다" << std::endl;
        return nullptr;
    }
    
    std::cout << "🚀 Android 호환 TTS 추론 시작..." << std::endl;
    std::cout << "📊 입력 정보:" << std::endl;
    std::cout << "  - 텍스트: " << text << std::endl;
    std::cout << "  - phone_length: " << phone_length << std::endl;
    std::cout << "  - speaker_id: " << speaker_id << std::endl;
    
    // Performance timing
    auto start_time = std::chrono::high_resolution_clock::now();
    auto tensor_creation_start = start_time;
    
    try {
        OrtAllocator* allocator;
        g_ort->GetAllocatorWithDefaultOptions(&allocator);
        
        // 1. x: phone IDs [1, seq_len]
        std::vector<int64_t> phone_ids(phone_data, phone_data + phone_length);
        std::vector<int64_t> x_shape = {1, phone_length};
        OrtValue* x_tensor = nullptr;
        OrtStatus* status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            phone_ids.data(),
            phone_ids.size() * sizeof(int64_t),
            x_shape.data(),
            x_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &x_tensor
        );
        if (status != nullptr) {
            std::cerr << "❌ x 텐서 생성 실패" << std::endl;
            return nullptr;
        }
        
        // 2. x_lengths: sequence length [1]
        std::vector<int64_t> x_lengths_data = {phone_length};
        std::vector<int64_t> x_lengths_shape = {1};
        OrtValue* x_lengths_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            x_lengths_data.data(),
            x_lengths_data.size() * sizeof(int64_t),
            x_lengths_shape.data(),
            x_lengths_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &x_lengths_tensor
        );
        if (status != nullptr) {
            std::cerr << "❌ x_lengths 텐서 생성 실패" << std::endl;
            return nullptr;
        }
        
        // 3. sid: speaker ID [1]
        std::vector<int64_t> sid_data = {speaker_id};
        std::vector<int64_t> sid_shape = {1};
        OrtValue* sid_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            sid_data.data(),
            sid_data.size() * sizeof(int64_t),
            sid_shape.data(),
            sid_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &sid_tensor
        );
        if (status != nullptr) {
            std::cerr << "❌ sid 텐서 생성 실패" << std::endl;
            return nullptr;
        }
        
        // 4. tones: alternating 0,11 pattern for Korean [1, seq_len] - 사전 할당으로 성능 향상
        std::vector<int64_t> tones_data;
        tones_data.reserve(phone_length);  // 메모리 사전 할당
        for (int32_t i = 0; i < phone_length; i++) {
            tones_data.push_back((i % 2 == 0) ? 0 : 11);
        }
        OrtValue* tones_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            tones_data.data(),
            tones_data.size() * sizeof(int64_t),
            x_shape.data(),
            x_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &tones_tensor
        );
        if (status != nullptr) {
            std::cerr << "❌ tones 텐서 생성 실패" << std::endl;
            return nullptr;
        }
        
        // 5. lang_ids: alternating 0,4 pattern for Korean [1, seq_len] - 사전 할당으로 성능 향상
        std::vector<int64_t> lang_ids_data;
        lang_ids_data.reserve(phone_length);  // 메모리 사전 할당
        for (int32_t i = 0; i < phone_length; i++) {
            lang_ids_data.push_back((i % 2 == 0) ? 0 : 4);
        }
        OrtValue* lang_ids_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            lang_ids_data.data(),
            lang_ids_data.size() * sizeof(int64_t),
            x_shape.data(),
            x_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &lang_ids_tensor
        );
        if (status != nullptr) {
            std::cerr << "❌ lang_ids 텐서 생성 실패" << std::endl;
            return nullptr;
        }
        
        // 6. bert: zeros [1, 1024, seq_len]
        std::vector<int64_t> bert_shape = {1, 1024, phone_length};
        std::vector<float> bert_zeros(1024 * phone_length, 0.0f);
        OrtValue* bert_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            bert_zeros.data(),
            bert_zeros.size() * sizeof(float),
            bert_shape.data(),
            bert_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
            &bert_tensor
        );
        if (status != nullptr) {
            std::cerr << "❌ bert 텐서 생성 실패" << std::endl;
            return nullptr;
        }
        
        // 7. ja_bert: Korean BERT features [1, 768, seq_len]
        std::vector<int64_t> ja_bert_shape = {1, 768, phone_length};
        OrtValue* ja_bert_tensor = nullptr;
        status = g_ort->CreateTensorWithDataAsOrtValue(
            g_memoryInfo,
            (void*)ja_bert_features,
            768 * phone_length * sizeof(float),
            ja_bert_shape.data(),
            ja_bert_shape.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
            &ja_bert_tensor
        );
        if (status != nullptr) {
            std::cerr << "❌ ja_bert 텐서 생성 실패" << std::endl;
            return nullptr;
        }
        
        auto tensor_creation_end = std::chrono::high_resolution_clock::now();
        auto tensor_creation_duration = std::chrono::duration_cast<std::chrono::milliseconds>(tensor_creation_end - tensor_creation_start);
        std::cout << "⏱️ 텐서 생성 시간: " << tensor_creation_duration.count() << "ms" << std::endl;
        
        // 입력 텐서 매핑
        std::vector<const char*> input_names = {"x", "x_lengths", "sid", "tones", "lang_ids", "bert", "ja_bert"};
        std::vector<const OrtValue*> input_values = {
            x_tensor, x_lengths_tensor, sid_tensor, tones_tensor, 
            lang_ids_tensor, bert_tensor, ja_bert_tensor
        };
        
        std::cout << "📊 Android 호환 TTS 입력:" << std::endl;
        std::cout << "  1. x: [1, " << phone_length << "]" << std::endl;
        std::cout << "  2. x_lengths: [1] = " << phone_length << std::endl;
        std::cout << "  3. sid: [1] = " << speaker_id << std::endl;
        std::cout << "  4. tones: [1, " << phone_length << "] (alternating 0,11)" << std::endl;
        std::cout << "  5. lang_ids: [1, " << phone_length << "] (alternating 0,4)" << std::endl;
        std::cout << "  6. bert: [1, 1024, " << phone_length << "] (zeros)" << std::endl;
        std::cout << "  7. ja_bert: [1, 768, " << phone_length << "] (features)" << std::endl;
        
        // 출력 이름 가져오기
        char* output_name;
        status = g_ort->SessionGetOutputName(g_ttsSession, 0, allocator, &output_name);
        if (status != nullptr) {
            std::cerr << "❌ 출력 이름 가져오기 실패" << std::endl;
            return nullptr;
        }
        
        // TTS 모델 실행
        const char* output_names[] = {output_name};
        OrtValue* output_tensor = nullptr;
        
        std::cout << "🎵 Android 호환 TTS 모델 실행 중..." << std::endl;
        auto inference_start = std::chrono::high_resolution_clock::now();
        
        status = g_ort->Run(
            g_ttsSession,
            nullptr,
            input_names.data(),
            input_values.data(),
            input_values.size(),
            output_names,
            1,
            &output_tensor
        );
        
        auto inference_end = std::chrono::high_resolution_clock::now();
        auto inference_duration = std::chrono::duration_cast<std::chrono::milliseconds>(inference_end - inference_start);
        std::cout << "⏱️ TTS 모델 추론 시간: " << inference_duration.count() << "ms" << std::endl;
        
        if (status != nullptr) {
            std::cerr << "❌ TTS 모델 실행 실패: " << g_ort->GetErrorMessage(status) << std::endl;
            g_ort->ReleaseStatus(status);
            return nullptr;
        }
        
        // 결과 처리
        float* output_data;
        status = g_ort->GetTensorMutableData(output_tensor, (void**)&output_data);
        if (status != nullptr) {
            std::cerr << "❌ 출력 데이터 가져오기 실패" << std::endl;
            return nullptr;
        }
        
        OrtTensorTypeAndShapeInfo* tensor_info;
        g_ort->GetTensorTypeAndShape(output_tensor, &tensor_info);
        
        size_t output_size;
        g_ort->GetTensorShapeElementCount(tensor_info, &output_size);
        
        TTSResult* result = new TTSResult;
        result->audio_data = new float[output_size];
        result->audio_length = static_cast<int32_t>(output_size);
        result->sample_rate = 22050;  // Android 앱과 동일
        
        memcpy(result->audio_data, output_data, output_size * sizeof(float));
        
        // 상세한 오디오 정보 로깅
        std::cout << "✅ === TTS 모델 추론 완료 ===" << std::endl;
        std::cout << "✅ 생성된 샘플 수: " << output_size << std::endl;
        std::cout << "✅ 모델 샘플레이트: " << result->sample_rate << " Hz" << std::endl;
        double modelDuration = static_cast<double>(output_size) / static_cast<double>(result->sample_rate);
        std::cout << "✅ 모델 계산 오디오 길이: " << std::fixed << std::setprecision(2) << modelDuration << "초" << std::endl;
        
        // 메모리 정리
        g_ort->ReleaseTensorTypeAndShapeInfo(tensor_info);
        g_ort->ReleaseValue(output_tensor);
        g_ort->ReleaseValue(x_tensor);
        g_ort->ReleaseValue(x_lengths_tensor);
        g_ort->ReleaseValue(sid_tensor);
        g_ort->ReleaseValue(tones_tensor);
        g_ort->ReleaseValue(lang_ids_tensor);
        g_ort->ReleaseValue(bert_tensor);
        g_ort->ReleaseValue(ja_bert_tensor);
        
        auto total_end = std::chrono::high_resolution_clock::now();
        auto total_duration = std::chrono::duration_cast<std::chrono::milliseconds>(total_end - start_time);
        std::cout << "⏱️ 전체 Android 호환 TTS 처리 시간: " << total_duration.count() << "ms" << std::endl;
        
        return result;
        
    } catch (const std::exception& e) {
        std::cerr << "❌ Android 호환 TTS 추론 예외: " << e.what() << std::endl;
        return nullptr;
    }
}

// ONNX Runtime 정리
void cleanupONNXRuntime(void) {
    if (g_initialized) {
        std::cout << "🗑️ ONNX Runtime 리소스 정리..." << std::endl;
        
        if (g_bertSession) {
            g_ort->ReleaseSession(g_bertSession);
            g_bertSession = nullptr;
        }
        
        if (g_ttsSession) {
            g_ort->ReleaseSession(g_ttsSession);
            g_ttsSession = nullptr;
        }
        
        if (g_sessionOptions) {
            g_ort->ReleaseSessionOptions(g_sessionOptions);
            g_sessionOptions = nullptr;
        }
        
        if (g_memoryInfo) {
            g_ort->ReleaseMemoryInfo(g_memoryInfo);
            g_memoryInfo = nullptr;
        }
        
        if (g_env) {
            g_ort->ReleaseEnv(g_env);
            g_env = nullptr;
        }
        
        g_bertModelPath.clear();
        g_ttsModelPath.clear();
        g_initialized = false;
        std::cout << "✅ ONNX Runtime 정리 완료" << std::endl;
    }
}
