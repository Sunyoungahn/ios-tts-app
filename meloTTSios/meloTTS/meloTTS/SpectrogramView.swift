import SwiftUI
import Accelerate

// MARK: - Spectrogram Data Processing
class SpectrogramProcessor {
    static func calculateSpectrogram(audioData: [Float], sampleRate: Int = 44100) -> [[Float]] {
        let windowSize = 1024
        let hopSize = 512
        let numFrames = (audioData.count - windowSize) / hopSize + 1
        let numFrequencyBins = windowSize / 2 + 1
        
        var spectrogram: [[Float]] = []
        
        // Hanning window for better frequency resolution
        let window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: windowSize, isHalfWindow: false)
        
        for frame in 0..<numFrames {
            let startIndex = frame * hopSize
            let endIndex = min(startIndex + windowSize, audioData.count)
            
            // Extract frame
            var frameData = Array(audioData[startIndex..<endIndex])
            
            // Pad with zeros if necessary
            while frameData.count < windowSize {
                frameData.append(0.0)
            }
            
            // Apply window
            vDSP.multiply(frameData, window, result: &frameData)
            
            // Prepare for FFT
            var realParts = frameData
            var imaginaryParts = Array(repeating: Float(0), count: windowSize)
            
            // Perform FFT
            let log2n = vDSP_Length(log2(Float(windowSize)))
            guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
                continue
            }
            
            var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imaginaryParts)
            
            // Convert to split complex format
            realParts.withUnsafeMutableBufferPointer { realBuffer in
                imaginaryParts.withUnsafeMutableBufferPointer { imagBuffer in
                    var complex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                    frameData.withUnsafeBufferPointer { inputBuffer in
                        inputBuffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: windowSize / 2) { complexBuffer in
                            vDSP_ctoz(complexBuffer, 2, &complex, 1, vDSP_Length(windowSize / 2))
                        }
                    }
                    
                    // Perform FFT
                    vDSP_fft_zrip(fftSetup, &complex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // Calculate magnitude spectrum
                    var magnitudes = Array(repeating: Float(0), count: numFrequencyBins)
                    
                    // DC component
                    magnitudes[0] = abs(complex.realp[0])
                    
                    // Other frequency bins
                    for i in 1..<numFrequencyBins-1 {
                        let real = complex.realp[i]
                        let imag = complex.imagp[i]
                        magnitudes[i] = sqrt(real * real + imag * imag)
                    }
                    
                    // Nyquist frequency
                    if numFrequencyBins > 1 {
                        magnitudes[numFrequencyBins-1] = abs(complex.realp[windowSize/2])
                    }
                    
                    // Convert to dB scale
                    for i in 0..<magnitudes.count {
                        magnitudes[i] = 20 * log10(max(magnitudes[i], 1e-10))
                    }
                    
                    spectrogram.append(magnitudes)
                }
            }
            
            vDSP_destroy_fftsetup(fftSetup)
        }
        
        return spectrogram
    }
    
    static func normalizeSpectrogram(_ spectrogram: [[Float]]) -> [[Float]] {
        guard !spectrogram.isEmpty && !spectrogram[0].isEmpty else { return spectrogram }
        
        // Find global min and max
        var globalMin: Float = Float.infinity
        var globalMax: Float = -Float.infinity
        
        for frame in spectrogram {
            for value in frame {
                globalMin = min(globalMin, value)
                globalMax = max(globalMax, value)
            }
        }
        
        let range = globalMax - globalMin
        guard range > 0 else { return spectrogram }
        
        // Normalize to 0-1 range
        return spectrogram.map { frame in
            frame.map { value in
                (value - globalMin) / range
            }
        }
    }
}

// MARK: - Spectrogram Visualization View
struct SpectrogramView: View {
    let audioData: [Float]
    let sampleRate: Int
    @State private var spectrogram: [[Float]] = []
    @State private var isCalculating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 스펙트로그램")
                .font(.headline)
                .foregroundColor(.primary)
            
            if isCalculating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("스펙트로그램 계산 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else if spectrogram.isEmpty {
                VStack {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("스펙트로그램을 생성하려면\n음성을 먼저 합성해주세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
            } else {
                spectrogramCanvas
                spectrogramInfo
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            if !audioData.isEmpty {
                calculateSpectrogram()
            }
        }
        .onChange(of: audioData) { _ in
            if !audioData.isEmpty {
                calculateSpectrogram()
            }
        }
    }
    
    private var spectrogramCanvas: some View {
        Canvas { context, size in
            guard !spectrogram.isEmpty && !spectrogram[0].isEmpty else { return }
            
            let normalizedSpectrogram = SpectrogramProcessor.normalizeSpectrogram(spectrogram)
            let frameWidth = size.width / CGFloat(normalizedSpectrogram.count)
            let binHeight = size.height / CGFloat(normalizedSpectrogram[0].count)
            
            for (frameIndex, frame) in normalizedSpectrogram.enumerated() {
                let x = CGFloat(frameIndex) * frameWidth
                
                for (binIndex, magnitude) in frame.enumerated().reversed() {
                    let y = CGFloat(binIndex) * binHeight
                    let rect = CGRect(x: x, y: y, width: frameWidth, height: binHeight)
                    
                    // Color mapping: blue (low) -> green -> yellow -> red (high)
                    let color = spectrogramColor(magnitude: magnitude)
                    context.fill(Path(rect), with: .color(color))
                }
            }
            
            // Add frequency labels
            let maxFreq = sampleRate / 2
            let freqStep = maxFreq / 5
            
            for i in 0...5 {
                let freq = i * freqStep
                let y = size.height - (CGFloat(i) / 5.0) * size.height
                
                context.draw(Text("\(freq/1000, specifier: "%.1f")kHz")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary),
                    at: CGPoint(x: 10, y: y))
            }
        }
        .frame(height: 200)
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var spectrogramInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("🎵 주파수 범위: 0 - \(sampleRate/2000)kHz")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("⏱️ 시간 길이: \(String(format: "%.2f", Double(audioData.count) / Double(sampleRate)))초")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("📊 프레임 수: \(spectrogram.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Color legend
            VStack(alignment: .trailing, spacing: 2) {
                Text("강도")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Rectangle()
                            .fill(spectrogramColor(magnitude: Float(i) / 4.0))
                            .frame(width: 15, height: 8)
                    }
                }
                
                HStack {
                    Text("낮음")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("높음")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(width: 75)
            }
        }
    }
    
    private func spectrogramColor(magnitude: Float) -> Color {
        let clampedMagnitude = max(0, min(1, magnitude))
        
        if clampedMagnitude < 0.25 {
            // Blue to Cyan
            let t = clampedMagnitude / 0.25
            return Color(red: 0, green: Double(t), blue: 1)
        } else if clampedMagnitude < 0.5 {
            // Cyan to Green
            let t = (clampedMagnitude - 0.25) / 0.25
            return Color(red: 0, green: 1, blue: Double(1 - t))
        } else if clampedMagnitude < 0.75 {
            // Green to Yellow
            let t = (clampedMagnitude - 0.5) / 0.25
            return Color(red: Double(t), green: 1, blue: 0)
        } else {
            // Yellow to Red
            let t = (clampedMagnitude - 0.75) / 0.25
            return Color(red: 1, green: Double(1 - t), blue: 0)
        }
    }
    
    private func calculateSpectrogram() {
        isCalculating = true
        
        Task.detached(priority: .background) {
            let calculatedSpectrogram = SpectrogramProcessor.calculateSpectrogram(
                audioData: audioData,
                sampleRate: sampleRate
            )
            
            await MainActor.run {
                spectrogram = calculatedSpectrogram
                isCalculating = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    // Generate sample audio data (1kHz sine wave)
    let sampleRate = 44100
    let frequency = 1000.0
    let duration = 1.0
    let sampleCount = Int(Double(sampleRate) * duration)
    
    let sampleAudio = (0..<sampleCount).map { i in
        Float(sin(2.0 * Double.pi * frequency * Double(i) / Double(sampleRate)) * 0.5)
    }
    
    return SpectrogramView(audioData: sampleAudio, sampleRate: sampleRate)
        .padding()
}