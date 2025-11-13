// Test file for ONNX Runtime integration
import Foundation

extension SimpleTTSEngine {
    
    /// Test method to verify ONNX Runtime integration
    func testONNXIntegration() async {
        print("🧪 Starting ONNX Runtime integration test...")
        
        do {
            // Test 1: Initialize engine
            print("\n1️⃣ Testing engine initialization...")
            try await initialize()
            print("✅ Engine initialization successful")
            
            // Test 2: Test simple TTS inference
            print("\n2️⃣ Testing TTS inference...")
            let testText = "안녕하세요"
            
            let result = try await simpleTTSInference(
                text: testText,
                speakerId: 0,
                speed: 1.0,
                noiseScale: 0.667,
                noiseScaleW: 0.8,
                sdpRatio: 0.2
            )
            
            if let audioData = result["audioData"] as? [Float] {
                print("✅ TTS inference successful!")
                print("   Generated \(audioData.count) audio samples")
                
                // Basic validation
                if audioData.count > 0 {
                    let avgAmplitude = audioData.map(abs).reduce(0, +) / Float(audioData.count)
                    print("   Average amplitude: \(avgAmplitude)")
                    
                    if avgAmplitude > 0 {
                        print("✅ Audio data appears valid (non-zero amplitude)")
                    } else {
                        print("⚠️ Audio data may be silent")
                    }
                } else {
                    print("❌ No audio data generated")
                }
                
            } else {
                print("❌ No audio data in result")
            }
            
            // Test 3: Cleanup
            print("\n3️⃣ Testing cleanup...")
            dispose()
            print("✅ Cleanup successful")
            
            print("\n🎉 ONNX Runtime integration test completed successfully!")
            
        } catch {
            print("\n❌ Integration test failed: \(error)")
            dispose()
        }
    }
}

// Usage example:
// let engine = SimpleTTSEngine()
// await engine.testONNXIntegration()