import Foundation

/// Korean Grapheme-to-Phoneme (G2P) converter
/// 
/// This is a Swift port of the g2pkk library for Korean pronunciation conversion.
/// It converts Korean text (graphemes) to their phonetic representation (phonemes).
class G2p {
    static let version = "1.0.0"
    
    // Korean character ranges
    static let hangulStart: UInt32 = 0xAC00
    static let hangulEnd: UInt32 = 0xD7A3
    static let choBase: UInt32 = 0x1100
    static let jungBase: UInt32 = 0x1161
    static let jongBase: UInt32 = 0x11A7
    
    // Jamo components
    static let chosung = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]
    
    static let jungsung = [
        "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ",
        "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"
    ]
    
    static let jongsung = [
        "", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ",
        "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    // Pronunciation transformation rules
    static let transformRules: [String: String] = [
        // Rule 23: Consonant assimilation
        "ㄱㄱ": "ㄲ", "ㄱㄷ": "ㄱㄸ", "ㄱㅂ": "ㄱㅃ", "ㄱㅅ": "ㄱㅆ", "ㄱㅈ": "ㄱㅉ",
        "ㄲㄱ": "ㄲ", "ㄲㄷ": "ㄲㄸ", "ㄲㅂ": "ㄲㅃ", "ㄲㅅ": "ㄲㅆ", "ㄲㅈ": "ㄲㅉ",
        "ㅋㄱ": "ㅋㄲ", "ㅋㄷ": "ㅋㄸ", "ㅋㅂ": "ㅋㅃ", "ㅋㅅ": "ㅋㅆ", "ㅋㅈ": "ㅋㅉ",
        
        "ㄷㄱ": "ㄷㄲ", "ㄷㄷ": "ㄸ", "ㄷㅂ": "ㄷㅃ", "ㄷㅅ": "ㄷㅆ", "ㄷㅈ": "ㄷㅉ",
        "ㅅㄱ": "ㅅㄲ", "ㅅㄷ": "ㅅㄸ", "ㅅㅂ": "ㅅㅃ", "ㅅㅅ": "ㅆ", "ㅅㅈ": "ㅅㅉ",
        "ㅆㄱ": "ㅆㄲ", "ㅆㄷ": "ㅆㄸ", "ㅆㅂ": "ㅆㅃ", "ㅆㅅ": "ㅆ", "ㅆㅈ": "ㅆㅉ",
        "ㅈㄱ": "ㅈㄲ", "ㅈㄷ": "ㅈㄸ", "ㅈㅂ": "ㅈㅃ", "ㅈㅅ": "ㅈㅆ", "ㅈㅈ": "ㅉ",
        "ㅊㄱ": "ㅊㄲ", "ㅊㄷ": "ㅊㄸ", "ㅊㅂ": "ㅊㅃ", "ㅊㅅ": "ㅊㅆ", "ㅊㅈ": "ㅊㅉ",
        "ㅌㄱ": "ㅌㄲ", "ㅌㄷ": "ㅌㄸ", "ㅌㅂ": "ㅌㅃ", "ㅌㅅ": "ㅌㅆ", "ㅌㅈ": "ㅌㅉ",
        
        "ㅂㄱ": "ㅂㄲ", "ㅂㄷ": "ㅂㄸ", "ㅂㅂ": "ㅃ", "ㅂㅅ": "ㅂㅆ", "ㅂㅈ": "ㅂㅉ",
        "ㅍㄱ": "ㅍㄲ", "ㅍㄷ": "ㅍㄸ", "ㅍㅂ": "ㅍㅃ", "ㅍㅅ": "ㅍㅆ", "ㅍㅈ": "ㅍㅉ",
        
        // Representative sound rules (Rule 9)
        "ㄲ": "ㄱ", "ㅋ": "ㄱ", "ㄳ": "ㄱ", "ㄺ": "ㄱ",
        "ㅅ": "ㄷ", "ㅆ": "ㄷ", "ㅈ": "ㄷ", "ㅊ": "ㄷ", "ㅌ": "ㄷ",
        "ㅍ": "ㅂ", "ㄼ": "ㅂ", "ㄿ": "ㅂ", "ㅄ": "ㅂ"
    ]

    // Descriptive pronunciation variants
    static let descriptiveRules: [String: String] = [
        "의": "에",  // 의 -> 에 in colloquial speech
        "계": "게"   // 계 -> 게 in colloquial speech
    ]

    // Vowel grouping for contemporary speech
    static let vowelGrouping: [String: String] = [
        "ㅒ": "ㅖ",  // ㅒ -> ㅖ
        "ㅘ": "ㅗ",  // ㅘ -> ㅗ (simplified)
        "ㅙ": "ㅞ"   // ㅙ -> ㅞ
    ]

    // Number to Korean conversion
    static let numbers: [String: String] = [
        "0": "영", "1": "일", "2": "이", "3": "삼", "4": "사",
        "5": "오", "6": "육", "7": "칠", "8": "팔", "9": "구"
    ]

    // English alphabet to Korean approximation
    static let englishToKorean: [String: String] = [
        "a": "에이", "b": "비", "c": "씨", "d": "디", "e": "이",
        "f": "에프", "g": "지", "h": "에이치", "i": "아이", "j": "제이",
        "k": "케이", "l": "엘", "m": "엠", "n": "엔", "o": "오",
        "p": "피", "q": "큐", "r": "알", "s": "에스", "t": "티",
        "u": "유", "v": "브이", "w": "더블유", "x": "엑스", "y": "와이", "z": "지"
    ]

    var descriptive: Bool
    var groupVowels: Bool
    var toSyl: Bool
    var verbose: Bool

    /// Creates a new G2p instance
    /// 
    /// - Parameters:
    ///   - descriptive: Use descriptive (colloquial) pronunciation instead of prescriptive
    ///   - groupVowels: Group similar vowels in contemporary speech
    ///   - toSyl: Return syllables instead of individual jamo
    ///   - verbose: Print detailed transformation information
    init(descriptive: Bool = false, groupVowels: Bool = false, toSyl: Bool = true, verbose: Bool = false) {
        self.descriptive = descriptive
        self.groupVowels = groupVowels
        self.toSyl = toSyl
        self.verbose = verbose
    }

    /// Main conversion function
    /// 
    /// Converts Korean text to phonetic representation
    func call(_ text: String) -> String {
        if verbose {
            print("Input: \(text)")
        }

        var result = text

        // 1. Convert numbers to Korean
        result = convertNumbers(result)
        
        // 2. Convert English to Korean approximation
        result = convertEnglish(result)
        
        // 3. Apply phonetic transformation rules
        result = applyPhoneticRules(result)
        
        // 4. Apply descriptive pronunciation if enabled
        if descriptive {
            result = applyDescriptiveRules(result)
        }
        
        // 5. Apply vowel grouping if enabled
        if groupVowels {
            result = applyVowelGrouping(result)
        }
        
        // 6. Convert to jamo if toSyl is false
        if !toSyl {
            result = convertToJamo(result)
        }

        if verbose {
            print("Output: \(result)")
        }

        return result
    }

    /// Converts Arabic numbers to Korean pronunciation
    private func convertNumbers(_ text: String) -> String {
        let regex = try! NSRegularExpression(pattern: "\\d+")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        let matches = regex.matches(in: text, options: [], range: range)
        var result = text
        
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let numberString = String(text[range])
            let koreanNumber = self.numberToKorean(numberString)
            result.replaceSubrange(range, with: koreanNumber)
        }
        
        return result
    }

    /// Converts a number string to Korean
    private func numberToKorean(_ number: String) -> String {
        if number.count == 1 {
            return G2p.numbers[number] ?? number
        }
        
        // Simple implementation for basic numbers
        // In a full implementation, this would handle complex number rules
        var result = ""
        for char in number {
            let digit = String(char)
            result += G2p.numbers[digit] ?? digit
        }
        return result
    }

    /// Converts English text to Korean approximation
    private func convertEnglish(_ text: String) -> String {
        let regex = try! NSRegularExpression(pattern: "[a-zA-Z]+")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        let matches = regex.matches(in: text, options: [], range: range)
        var result = text
        
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let matchedString = String(text[range]).lowercased()
            var koreanString = ""
            
            for char in matchedString {
                let charString = String(char)
                koreanString += G2p.englishToKorean[charString] ?? charString
            }
            
            result.replaceSubrange(range, with: koreanString)
        }
        
        return result
    }

    /// Applies Korean phonetic transformation rules
    private func applyPhoneticRules(_ text: String) -> String {
        var chars = Array(text)
        var result: [Character] = []

        for i in 0..<chars.count {
            let currentChar = String(chars[i])
            
            if isHangul(currentChar) {
                var current = decomposeHangul(currentChar)
                
                // Look ahead for liaison and consonant assimilation rules
                if i < chars.count - 1 && isHangul(String(chars[i + 1])) {
                    var next = decomposeHangul(String(chars[i + 1]))
                    
                    // Apply liaison rule (연음 규칙) - Rule 14
                    // When a final consonant meets ㅇ initial consonant
                    if !current.jongsung.isEmpty && next.chosung == "ㅇ" {
                        var liaisonConsonant = current.jongsung
                        var remainingConsonant = ""
                        
                        // Handle complex consonants in liaison
                        if current.jongsung == "ㅆ" {
                            // ㅆ -> ㅅ goes to next syllable as ㅆ, nothing stays
                            liaisonConsonant = "ㅆ"  // ㅆ로 연음됨
                            remainingConsonant = ""  // 아무것도 남지 않음
                        } else if current.jongsung == "ㄲ" {
                            // ㄲ -> ㄱ goes to next syllable, ㄱ stays
                            liaisonConsonant = "ㄱ"
                            remainingConsonant = "ㄱ"
                        } else if current.jongsung == "ㄳ" {
                            // ㄳ -> ㅅ goes to next syllable, ㄱ stays
                            liaisonConsonant = "ㅅ"
                            remainingConsonant = "ㄱ"
                        } else if current.jongsung == "ㄵ" {
                            // ㄵ -> ㅈ goes to next syllable, ㄴ stays
                            liaisonConsonant = "ㅈ"
                            remainingConsonant = "ㄴ"
                        } else if current.jongsung == "ㄶ" {
                            // ㄶ -> ㅎ goes to next syllable, ㄴ stays
                            liaisonConsonant = "ㅎ"
                            remainingConsonant = "ㄴ"
                        } else if current.jongsung == "ㄺ" {
                            // ㄺ -> ㄱ goes to next syllable, ㄹ stays
                            liaisonConsonant = "ㄱ"
                            remainingConsonant = "ㄹ"
                        } else if current.jongsung == "ㄻ" {
                            // ㄻ -> ㅁ goes to next syllable, ㄹ stays
                            liaisonConsonant = "ㅁ"
                            remainingConsonant = "ㄹ"
                        } else if current.jongsung == "ㄼ" {
                            // ㄼ -> ㅂ goes to next syllable, ㄹ stays
                            liaisonConsonant = "ㅂ"
                            remainingConsonant = "ㄹ"
                        } else if current.jongsung == "ㄽ" {
                            // ㄽ -> ㅅ goes to next syllable, ㄹ stays
                            liaisonConsonant = "ㅅ"
                            remainingConsonant = "ㄹ"
                        } else if current.jongsung == "ㄾ" {
                            // ㄾ -> ㅌ goes to next syllable, ㄹ stays
                            liaisonConsonant = "ㅌ"
                            remainingConsonant = "ㄹ"
                        } else if current.jongsung == "ㄿ" {
                            // ㄿ -> ㅂ goes to next syllable, ㄹ stays (represented as ㅍ)
                            liaisonConsonant = "ㅍ"
                            remainingConsonant = "ㄹ"
                        } else if current.jongsung == "ㅀ" {
                            // ㅀ -> ㅎ goes to next syllable, ㄹ stays
                            liaisonConsonant = "ㅎ"
                            remainingConsonant = "ㄹ"
                        } else if current.jongsung == "ㅄ" {
                            // ㅄ -> ㅅ goes to next syllable, ㅂ stays
                            liaisonConsonant = "ㅅ"
                            remainingConsonant = "ㅂ"
                        }
                        // Single consonants move entirely
                        
                        // Move final consonant to next syllable's initial position
                        next = JamoDecomposition(
                            chosung: liaisonConsonant,
                            jungsung: next.jungsung,
                            jongsung: next.jongsung
                        )
                        current = JamoDecomposition(
                            chosung: current.chosung,
                            jungsung: current.jungsung,
                            jongsung: remainingConsonant  // Empty for single consonants, partial for complex ones
                        )
                        chars[i + 1] = Character(composeHangul(next))
                        
                        if verbose {
                            print("🔗 연음 적용: \(String(chars[i]))(\(current.jongsung)) + \(String(chars[i+1]))(\(next.chosung)) → \(composeHangul(current)) + \(composeHangul(next))")
                        }
                    }
                    // Apply consonant assimilation (Rule 23) - only when no liaison occurs
                    else if !current.jongsung.isEmpty && !next.chosung.isEmpty {
                        let combination = current.jongsung + next.chosung
                        if let transformed = G2p.transformRules[combination] {
                            if transformed.count == 2 {
                                let transformedChars = Array(transformed)
                                current = JamoDecomposition(
                                    chosung: current.chosung,
                                    jungsung: current.jungsung,
                                    jongsung: String(transformedChars[0])
                                )
                                next = JamoDecomposition(
                                    chosung: String(transformedChars[1]),
                                    jungsung: next.jungsung,
                                    jongsung: next.jongsung
                                )
                                chars[i + 1] = Character(composeHangul(next))
                            }
                        }
                    }
                }
                
                // Apply representative sound rules (Rule 9) for final consonants
                if !current.jongsung.isEmpty {
                    if i == chars.count - 1 || !isHangul(String(chars[i + 1])) {
                        // Final position or before non-Hangul
                        let transformed = G2p.transformRules[current.jongsung] ?? current.jongsung
                        current = JamoDecomposition(
                            chosung: current.chosung,
                            jungsung: current.jungsung,
                            jongsung: transformed
                        )
                    }
                }
                
                result.append(Character(composeHangul(current)))
            } else {
                result.append(chars[i])
            }
        }

        return String(result)
    }

    /// Applies descriptive (colloquial) pronunciation rules
    private func applyDescriptiveRules(_ text: String) -> String {
        var result = text
        for (key, value) in G2p.descriptiveRules {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return result
    }

    /// Applies vowel grouping for contemporary speech
    private func applyVowelGrouping(_ text: String) -> String {
        var result = text
        for (key, value) in G2p.vowelGrouping {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return result
    }

    /// Converts syllables to individual jamo characters
    private func convertToJamo(_ text: String) -> String {
        var result: [String] = []
        
        for char in text {
            let charString = String(char)
            if isHangul(charString) {
                let decomposed = decomposeHangul(charString)
                result.append(decomposed.chosung)
                result.append(decomposed.jungsung)
                if !decomposed.jongsung.isEmpty {
                    result.append(decomposed.jongsung)
                }
            } else {
                result.append(charString)
            }
        }
        
        return result.joined()
    }

    /// Checks if a character is Hangul
    private func isHangul(_ char: String) -> Bool {
        guard !char.isEmpty else { return false }
        let code = char.unicodeScalars.first!.value
        return code >= G2p.hangulStart && code <= G2p.hangulEnd
    }

    /// Decomposes a Hangul syllable into jamo components
    private func decomposeHangul(_ syllable: String) -> JamoDecomposition {
        guard isHangul(syllable) else {
            return JamoDecomposition(chosung: "", jungsung: "", jongsung: "")
        }
        
        let code = Int(syllable.unicodeScalars.first!.value - G2p.hangulStart)
        let jong = code % 28
        let jung = (code - jong) % 588 / 28
        let cho = (code - jong - jung * 28) / 588
        
        return JamoDecomposition(
            chosung: G2p.chosung[cho],
            jungsung: G2p.jungsung[jung],
            jongsung: jong == 0 ? "" : G2p.jongsung[jong]
        )
    }

    /// Composes jamo components into a Hangul syllable
    private func composeHangul(_ jamo: JamoDecomposition) -> String {
        guard let cho = G2p.chosung.firstIndex(of: jamo.chosung),
              let jung = G2p.jungsung.firstIndex(of: jamo.jungsung) else {
            return jamo.chosung + jamo.jungsung + jamo.jongsung
        }
        
        let jong = jamo.jongsung.isEmpty ? 0 : (G2p.jongsung.firstIndex(of: jamo.jongsung) ?? 0)
        
        let code = G2p.hangulStart + UInt32(cho * 588 + jung * 28 + jong)
        return String(UnicodeScalar(code)!)
    }
}

/// Represents the decomposed jamo components of a Hangul syllable
struct JamoDecomposition {
    let chosung: String   // Initial consonant
    let jungsung: String  // Vowel
    let jongsung: String  // Final consonant
    
    init(chosung: String, jungsung: String, jongsung: String) {
        self.chosung = chosung
        self.jungsung = jungsung
        self.jongsung = jongsung
    }
}

/// Exception thrown when G2P conversion fails
struct G2pException: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}