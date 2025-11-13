import Foundation
import AVFoundation

class AudioPlayerHelper {
    static let shared = AudioPlayerHelper()
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    // [Float]를 WAV 파일로 저장 후 재생
    static func playAudioFromFloatArray(
        _ audioData: [Float],
        sampleRate: Int = 44100 
    ) async throws -> (duration: Double, sampleRate: Int) {
        do {
            print("🎵 오디오 재생 준비: \(audioData.count) samples, \(sampleRate) Hz")
            
            // 0. 오디오 데이터 검증 및 정규화
            guard !audioData.isEmpty else {
                throw NSError(domain: "AudioHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty audio data"])
            }
            
            // 볼륨 정규화 (너무 조용할 수 있음)
            let maxAmplitude = audioData.map { abs($0) }.max() ?? 1.0
            let normalizedAudio: [Float]
            if maxAmplitude > 0.001 { // 매우 조용한 오디오 방지
                let gain = min(0.8 / maxAmplitude, 10.0) // 최대 10배 증폭, 0.8로 제한
                normalizedAudio = audioData.map { $0 * gain }
                print("📊 오디오 정규화: 최대 진폭 \(maxAmplitude) -> 게인 \(gain)")
            } else {
                normalizedAudio = audioData
                print("⚠️ 매우 조용한 오디오 데이터 감지")
            }
            
            // 1. 오디오 세션 설정
            let audioSession = AVAudioSession.sharedInstance()
            try await MainActor.run {
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
            }
            print("🔊 오디오 세션 활성화")
            
            // 2. WAV 파일로 변환
            let wavBytes = convertToWav(normalizedAudio, sampleRate: sampleRate)
            
            // 3. 임시 파일로 저장
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent("tts_audio_\(Date().timeIntervalSince1970).wav")
            try wavBytes.write(to: tempFile)
            
            print("📁 임시 파일 저장: \(tempFile.path) (\(wavBytes.count) bytes)")

            // 4. 프로젝트 내부에도 저장 (디버깅용)
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let projectFile = documentsDir.appendingPathComponent("tts_audio_\(Date().timeIntervalSince1970).wav")
            try wavBytes.write(to: projectFile)
            print("📁 프로젝트 내부 파일 저장: \(projectFile.path)")
            
            // 5. 오디오 재생
            let result = try await MainActor.run {
                shared.audioPlayer = try AVAudioPlayer(contentsOf: tempFile)
                shared.audioPlayer?.delegate = AudioPlayerDelegate.shared
                shared.audioPlayer?.volume = 1.0
                shared.audioPlayer?.prepareToPlay()
                
                // 재생 완료 후 임시 파일 삭제를 위해 파일 경로 저장
                AudioPlayerDelegate.shared.tempFileToDelete = tempFile
                
                let success = shared.audioPlayer?.play() ?? false
                
                if success {
                    let actualDuration = shared.audioPlayer?.duration ?? 0
                    print("✅ === 오디오 재생 시작 ===")
                    print("✅ AVAudioPlayer 실제 재생 시간: \(String(format: "%.2f", actualDuration))초")
                    print("✅ WAV 파일 크기: \(wavBytes.count) bytes")
                    if let player = shared.audioPlayer {
                        print("✅ 플레이어 상태: 재생중=\(player.isPlaying), 볼륨=\(player.volume)")
                        print("✅ 샘플레이트 확인: \(player.url?.absoluteString ?? "unknown")")
                    }
                    
                    // 계산된 시간과 실제 재생 시간 비교
                    let expectedDuration = Double(normalizedAudio.count) / Double(sampleRate)
                    print("✅ 예상 시간: \(String(format: "%.2f", expectedDuration))초")
                    print("✅ 실제 시간: \(String(format: "%.2f", actualDuration))초")
                    let timeDiff = abs(expectedDuration - actualDuration)
                    print("✅ 시간 차이: \(String(format: "%.2f", timeDiff))초")
                    
                    print("🔍 AudioHelper - 반환값: duration=\(actualDuration), sampleRate=\(sampleRate)")
                    print("1")
                    print((duration: actualDuration, sampleRate: sampleRate))
                    return (duration: actualDuration, sampleRate: sampleRate)  // 실제 재생 시간과 샘플레이트 반환
                } else {
                    print("❌ 오디오 재생 시작 실패")
                    return (duration: 0.0, sampleRate: sampleRate)
                }
            }
            
            return result
            
        } catch {
            print("❌ 오디오 재생 실패: \(error)")
            return (duration: 0.0, sampleRate: 0)
        }
    }
     
    // [Float]를 WAV 형식으로 변환
    static func convertToWav(_ audioData: [Float], sampleRate: Int) -> Data {
        let numChannels = 1 // 모노
        let bitsPerSample = 16
        let byteRate = sampleRate * numChannels * (bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = audioData.count * 2 // 16-bit = 2 bytes per sample
        let fileSize = 36 + dataSize
        
        var bytes = Data(count: 44 + dataSize)
        
        bytes.withUnsafeMutableBytes { rawBytes in
            let buffer = rawBytes.bindMemory(to: UInt8.self)
            
            // WAV 헤더 작성
            buffer[0] = 0x52 // 'R'
            buffer[1] = 0x49 // 'I'
            buffer[2] = 0x46 // 'F'
            buffer[3] = 0x46 // 'F'
            _ = withUnsafeBytes(of: UInt32(fileSize).littleEndian) { $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 4), count: 4)) } // 4 bytes
            buffer[8] = 0x57  // 'W'
            buffer[9] = 0x41  // 'A'
            buffer[10] = 0x56 // 'V'
            buffer[11] = 0x45 // 'E'
            buffer[12] = 0x66 // 'f'
            buffer[13] = 0x6D // 'm'
            buffer[14] = 0x74 // 't'
            buffer[15] = 0x20 // ' '
            _ = withUnsafeBytes(of: UInt32(16).littleEndian) { $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 16), count: 4)) } // Subchunk1Size
            _ = withUnsafeBytes(of: UInt16(1).littleEndian) { $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 20), count: 2)) }  // AudioFormat (PCM)
            _ = withUnsafeBytes(of: UInt16(numChannels).littleEndian) { $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 22), count: 2)) }
            _ = withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 24), count: 4)) }
            _ = withUnsafeBytes(of: UInt32(byteRate).littleEndian) { $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 28), count: 4)) }
            _ = withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 32), count: 2)) }
            _ = withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 34), count: 2)) }
            buffer[36] = 0x64 // 'd'
            buffer[37] = 0x61 // 'a'
            buffer[38] = 0x74 // 't'
            buffer[39] = 0x61 // 'a'
            _ = withUnsafeBytes(of: UInt32(dataSize).littleEndian) { $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 40), count: 4)) } // 4 bytes
            
            // 오디오 데이터 변환 (Float → Int16)
            for i in 0..<audioData.count {
                let clampedSample = max(-1.0, min(1.0, audioData[i]))
                let sample = Int16(clampedSample * 32767)
                _ = withUnsafeBytes(of: sample.littleEndian) {
                    $0.copyBytes(to: UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(buffer.baseAddress! + 44 + i * 2), count: 2)) // 2 bytes
                }
            }
        }
        
        return bytes
    }
    
    // 재생 제어 함수들
    static func stopAudio() {
        shared.audioPlayer?.stop()
    }
    
    static func pauseAudio() {
        shared.audioPlayer?.pause()
    }
    
    static func resumeAudio() {
        shared.audioPlayer?.play()
    }
    
    static func dispose() {
        shared.audioPlayer?.stop()
        shared.audioPlayer = nil
    }
}

// AVAudioPlayerDelegate를 처리하는 클래스
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()
    var tempFileToDelete: URL?
    
    private override init() {
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🎵 오디오 재생 완료: \(flag ? "성공" : "실패")")
        
        // 재생 완료 후 임시 파일 삭제
        if let tempFile = tempFileToDelete {
            do {
                if FileManager.default.fileExists(atPath: tempFile.path) {
                    try FileManager.default.removeItem(at: tempFile)
                    print("🗑️ 임시 파일 삭제됨")
                }
            } catch {
                print("❌ 임시 파일 삭제 실패: \(error)")
            }
            tempFileToDelete = nil
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ 오디오 디코드 에러: \(error?.localizedDescription ?? "Unknown error")")
    }
}
