// Test script for real model4.onnx integration
import Foundation

extension SimpleTTSEngine {
    
    /// Test real model4.onnx with detailed inspection and inference
    func testRealModel() async {
        print("🧪 Starting Real model4.onnx Test...")
        print("=" * 60)
        
        do {
            // Phase 1: Initialize and Inspect Model
            print("\n🔍 Phase 1: Model Inspection")
            print("-" * 30)
            
            try await initialize()
            print("✅ Engine initialization successful")
            
            // Phase 2: Korean Text Processing Test
            print("\n📝 Phase 2: Korean Text Processing")
            print("-" * 40)
            
            let testTexts = [
                "안녕하세요",                    // Hello
                "오늘 날씨가 좋네요",             // Nice weather today
                "반갑습니다",                    // Nice to meet you
                "감사합니다",                    // Thank you
                "한국어 음성합성 테스트입니다"     // Korean TTS test
            ]
            
            for (index, text) in testTexts.enumerated() {
                print("\n🎯 Test \(index + 1): \"\(text)\"")
                
                let startTime = Date()
                let result = try await simpleTTSInference(
                    text: text,
                    speakerId: 0,
                    speed: 1.0,
                    noiseScale: 0.667,
                    noiseScaleW: 0.8,
                    sdpRatio: 0.2
                )
                let duration = Date().timeIntervalSince(startTime)
                
                if let audioData = result["audioData"] as? [Float] {
                    print("✅ Success! Generated \(audioData.count) samples in \(String(format: "%.2f", duration))s")
                    
                    // Audio quality analysis
                    analyzeAudio(audioData, text: text)
                    
                    // Save audio file for inspection
                    await saveTestAudio(audioData, filename: "test_\(index + 1)_\(text.prefix(10)).wav")
                    
                } else {
                    print("❌ Failed to generate audio")
                }
                
                // Wait between tests
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
            // Phase 3: Parameter Variation Test
            print("\n⚙️ Phase 3: Parameter Variation Test")
            print("-" * 40)
            
            let testText = "안녕하세요"
            let parameters = [
                (speed: 0.8, noise: 0.5, noiseW: 0.6),
                (speed: 1.0, noise: 0.667, noiseW: 0.8),
                (speed: 1.2, noise: 0.8, noiseW: 1.0),
            ]
            
            for (index, param) in parameters.enumerated() {
                print("\n🔧 Parameter Set \(index + 1):")
                print("   Speed: \(param.speed), Noise: \(param.noise), NoiseW: \(param.noiseW)")
                
                let result = try await simpleTTSInference(
                    text: testText,
                    speakerId: 0,
                    speed: param.speed,
                    noiseScale: param.noise,
                    noiseScaleW: param.noiseW,
                    sdpRatio: 0.2
                )
                
                if let audioData = result["audioData"] as? [Float] {
                    print("✅ Generated \(audioData.count) samples")
                    await saveTestAudio(audioData, filename: "param_test_\(index + 1).wav")
                }
            }
            
            // Final cleanup
            dispose()
            print("\n🎉 Real model4.onnx test completed successfully!")
            print("📁 Check Documents folder for generated audio files")
            
        } catch {
            print("\n❌ Test failed: \(error)")
            dispose()
        }
    }
    
    /// Analyze audio data for quality metrics
    private func analyzeAudio(_ audioData: [Float], text: String) {
        guard !audioData.isEmpty else {
            print("⚠️ No audio data to analyze")
            return
        }
        
        let maxAmplitude = audioData.map(abs).max() ?? 0
        let avgAmplitude = audioData.map(abs).reduce(0, +) / Float(audioData.count)
        let rmsAmplitude = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(audioData.count))
        
        // Check for clipping
        let clippedSamples = audioData.filter { abs($0) >= 0.99 }.count
        let clippingPercentage = Float(clippedSamples) / Float(audioData.count) * 100
        
        // Check for silence
        let silentSamples = audioData.filter { abs($0) < 0.001 }.count
        let silencePercentage = Float(silentSamples) / Float(audioData.count) * 100
        
        print("   📊 Audio Analysis:")
        print("      Max Amplitude: \(String(format: "%.4f", maxAmplitude))")
        print("      Avg Amplitude: \(String(format: "%.4f", avgAmplitude))")
        print("      RMS Amplitude: \(String(format: "%.4f", rmsAmplitude))")
        print("      Clipping: \(String(format: "%.2f", clippingPercentage))%")
        print("      Silence: \(String(format: "%.2f", silencePercentage))%")
        
        // Quality assessment
        if maxAmplitude > 0.01 && clippingPercentage < 1.0 && silencePercentage < 50.0 {
            print("      🟢 Quality: Good")
        } else if maxAmplitude > 0.001 {
            print("      🟡 Quality: Fair")
        } else {
            print("      🔴 Quality: Poor (likely silence)")
        }
    }
    
    /// Save audio data to Documents folder for inspection
    private func saveTestAudio(_ audioData: [Float], filename: String) async {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let audioURL = documentsPath.appendingPathComponent(filename)
            
            // Use existing AudioHelper to convert and save
            let wavData = AudioPlayerHelper.convertToWav(audioData, sampleRate: 22050)
            try wavData.write(to: audioURL)
            
            print("      💾 Saved: \(filename)")
            print("         Path: \(audioURL.path)")
            
        } catch {
            print("      ❌ Save failed: \(error)")
        }
    }
}

// Helper for string repetition
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// Usage:
// let engine = SimpleTTSEngine()
// await engine.testRealModel()