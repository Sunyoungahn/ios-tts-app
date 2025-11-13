// Python의 g2p 결과와 동일한 구조
struct G2PResult {
    let phones: [String]
    let tones: [Int]
    let word2ph: [Int]
    
    init(phones: [String], tones: [Int], word2ph: [Int]) {
        self.phones = phones
        self.tones = tones
        self.word2ph = word2ph
    }
}


struct TextSequenceResult {
    let phones: [Int]
    let tones: [Int]
    let languages: [Int]
    
    init(phones: [Int], tones: [Int], languages: [Int]) {
        self.phones = phones
        self.tones = tones
        self.languages = languages
    }
    
    var description: String {
        return "TextSequenceResult(phones: \(phones), tones: \(tones), languages: \(languages))"
    }
}



enum SimpleTTSError: Error {
    case notInitialized(String)
    case modelNotFound(String)
    case modelLoadFailed(String)
    case resourceNotFound(String)
}
