import SwiftUI

// MARK: - Waveform Data Processing
class WaveformProcessor {
    static func downsampleAudio(_ audioData: [Float], targetSamples: Int) -> [Float] {
        guard audioData.count > targetSamples else { return audioData }
        
        let samplesPerBin = audioData.count / targetSamples
        var downsampled: [Float] = []
        
        for i in 0..<targetSamples {
            let startIndex = i * samplesPerBin
            let endIndex = min(startIndex + samplesPerBin, audioData.count)
            
            // Get RMS (Root Mean Square) for better visualization
            var sum: Float = 0
            for j in startIndex..<endIndex {
                sum += audioData[j] * audioData[j]
            }
            let rms = sqrt(sum / Float(endIndex - startIndex))
            downsampled.append(rms)
        }
        
        return downsampled
    }
    
    static func normalizeWaveform(_ waveform: [Float]) -> [Float] {
        guard !waveform.isEmpty else { return waveform }
        
        let maxAmplitude = waveform.map { abs($0) }.max() ?? 1.0
        guard maxAmplitude > 0 else { return waveform }
        
        return waveform.map { $0 / maxAmplitude }
    }
}

// MARK: - Waveform Visualization View
struct WaveformView: View {
    let audioData: [Float]
    let sampleRate: Int
    @State private var waveformData: [Float] = []
    @State private var isProcessing = false
    
    // UI customization
    let height: CGFloat = 120
    let targetSamples: Int = 200  // Number of bars to display
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎵 파형 (Waveform)")
                .font(.headline)
                .foregroundColor(.primary)
            
            if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("파형 분석 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: height)
            } else if waveformData.isEmpty {
                VStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                    Text("파형을 보려면\n음성을 먼저 합성해주세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: height)
            } else {
                waveformCanvas
                waveformInfo
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            if !audioData.isEmpty {
                processWaveform()
            }
        }
        .onChange(of: audioData) { _ in
            if !audioData.isEmpty {
                processWaveform()
            }
        }
    }
    
    private var waveformCanvas: some View {
        Canvas { context, size in
            guard !waveformData.isEmpty else { return }
            
            let barWidth = size.width / CGFloat(waveformData.count)
            let centerY = size.height / 2
            let maxBarHeight = size.height * 0.9 // Leave some padding
            
            for (index, amplitude) in waveformData.enumerated() {
                let x = CGFloat(index) * barWidth + barWidth / 2
                let barHeight = CGFloat(abs(amplitude)) * maxBarHeight / 2
                
                // Create symmetric waveform (above and below center)
                let topY = centerY - barHeight
                let bottomY = centerY + barHeight
                
                // Draw the bar
                let rect = CGRect(
                    x: x - barWidth * 0.4, // Make bars slightly thinner for gaps
                    y: topY,
                    width: barWidth * 0.8,
                    height: bottomY - topY
                )
                
                // Color based on amplitude (blue for low, green for high)
                let color = waveformColor(amplitude: abs(amplitude))
                let path = Path(roundedRect: rect, cornerRadius: barWidth * 0.1)
                context.fill(path, with: .color(color))
            }
            
            // Draw center line
            let centerPath = Path { path in
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: size.width, y: centerY))
            }
            context.stroke(centerPath, with: .color(.secondary.opacity(0.3)), lineWidth: 1)
            
            // Add time markers
            let duration = Double(audioData.count) / Double(sampleRate)
            let timeStep = duration / 4  // 4 time markers
            
            for i in 0...4 {
                let time = Double(i) * timeStep
                let x = CGFloat(i) / 4.0 * size.width
                
                context.draw(Text(String(format: "%.1fs", time))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary),
                    at: CGPoint(x: x, y: size.height - 10))
                
                // Draw tick mark
                let tickPath = Path { path in
                    path.move(to: CGPoint(x: x, y: size.height - 20))
                    path.addLine(to: CGPoint(x: x, y: size.height - 15))
                }
                context.stroke(tickPath, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
            }
        }
        .frame(height: height)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var waveformInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("⏱️ 길이: \(String(format: "%.2f", Double(audioData.count) / Double(sampleRate)))초")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("📊 샘플: \(formatNumber(audioData.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let maxAmplitude = audioData.map { abs($0) }.max() ?? 0
                Text("📈 최대 진폭: \(String(format: "%.3f", maxAmplitude))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("🎚️ 샘플 레이트: \(sampleRate) Hz")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let rms = calculateRMS(audioData)
                Text("🔊 RMS: \(String(format: "%.3f", rms))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("📏 해상도: \(waveformData.count) bars")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func waveformColor(amplitude: Float) -> Color {
        let normalizedAmplitude = min(amplitude, 1.0)
        
        if normalizedAmplitude < 0.3 {
            // Blue for low amplitude
            return Color.blue.opacity(0.7 + Double(normalizedAmplitude) * 0.3)
        } else if normalizedAmplitude < 0.7 {
            // Green for medium amplitude
            return Color.green.opacity(0.7 + Double(normalizedAmplitude) * 0.3)
        } else {
            // Orange/Red for high amplitude
            return Color.orange.opacity(0.8 + Double(normalizedAmplitude) * 0.2)
        }
    }
    
    private func processWaveform() {
        isProcessing = true
        
        Task.detached(priority: .background) {
            // Downsample audio for visualization
            let downsampledAudio = WaveformProcessor.downsampleAudio(audioData, targetSamples: targetSamples)
            
            // Normalize for better visualization
            let normalizedWaveform = WaveformProcessor.normalizeWaveform(downsampledAudio)
            
            await MainActor.run {
                waveformData = normalizedWaveform
                isProcessing = false
            }
        }
    }
    
    private func calculateRMS(_ audio: [Float]) -> Float {
        guard !audio.isEmpty else { return 0 }
        
        let sumOfSquares = audio.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(audio.count))
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Mini Waveform View (for compact display)
struct MiniWaveformView: View {
    let audioData: [Float]
    let height: CGFloat = 40
    let targetSamples: Int = 100
    @State private var waveformData: [Float] = []
    
    var body: some View {
        Canvas { context, size in
            guard !waveformData.isEmpty else { return }
            
            let barWidth = size.width / CGFloat(waveformData.count)
            let centerY = size.height / 2
            let maxBarHeight = size.height * 0.8
            
            for (index, amplitude) in waveformData.enumerated() {
                let x = CGFloat(index) * barWidth + barWidth / 2
                let barHeight = CGFloat(abs(amplitude)) * maxBarHeight / 2
                
                let topY = centerY - barHeight
                let bottomY = centerY + barHeight
                
                let rect = CGRect(
                    x: x - barWidth * 0.3,
                    y: topY,
                    width: barWidth * 0.6,
                    height: bottomY - topY
                )
                
                let path = Path(roundedRect: rect, cornerRadius: barWidth * 0.05)
                context.fill(path, with: .color(.blue.opacity(0.8)))
            }
        }
        .frame(height: height)
        .onAppear {
            if !audioData.isEmpty {
                processWaveform()
            }
        }
        .onChange(of: audioData) { _ in
            if !audioData.isEmpty {
                processWaveform()
            }
        }
    }
    
    private func processWaveform() {
        Task.detached(priority: .background) {
            let downsampledAudio = WaveformProcessor.downsampleAudio(audioData, targetSamples: targetSamples)
            let normalizedWaveform = WaveformProcessor.normalizeWaveform(downsampledAudio)
            
            await MainActor.run {
                waveformData = normalizedWaveform
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Generate sample audio data (sine wave with varying frequency)
        let sampleRate = 44100
        let duration = 2.0
        let sampleCount = Int(Double(sampleRate) * duration)
        
        let sampleAudio = (0..<sampleCount).map { i in
            let t = Double(i) / Double(sampleRate)
            let frequency = 440.0 + sin(t * 2.0) * 220.0  // Varying frequency
            let amplitude = 0.5 * (1.0 + 0.3 * sin(t * 10.0))  // Varying amplitude
            return Float(sin(2.0 * Double.pi * frequency * t) * amplitude)
        }
        
        WaveformView(audioData: sampleAudio, sampleRate: sampleRate)
        
        Text("Mini Waveform:")
            .font(.headline)
        MiniWaveformView(audioData: sampleAudio)
    }
    .padding()
}