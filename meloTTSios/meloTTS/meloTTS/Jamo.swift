import Foundation

// MARK: - Korean Jamo Analysis and Conversion Library
/// Korean jamo (letter) analysis and conversion library
///
/// Syllable and jamo analysis for Korean. Default internal exchange form is
/// Hangul characters, not codepoints. Jamo exchange form is U+11xx characters,
/// not U+3xxx Hangul Compatibility Jamo (HCJ) characters or codepoints.
class Jamo {
    
    // MARK: - Constants
    private static let jamoOffset = 44032
    private static let jamoLeadOffset = 0x10ff
    private static let jamoVowelOffset = 0x1160
    private static let jamoTailOffset = 0x11a7
    
    // Jamo character ranges
    static let jamoLeads = (0x1100..<0x115F).compactMap { UnicodeScalar($0) }.map { String($0) }
    static let jamoLeadsModern = (0x1100..<0x1113).compactMap { UnicodeScalar($0) }.map { String($0) }
    static let jamoVowels = (0x1161..<0x11A8).compactMap { UnicodeScalar($0) }.map { String($0) }
    static let jamoVowelsModern = (0x1161..<0x1176).compactMap { UnicodeScalar($0) }.map { String($0) }
    static let jamoTails = (0x11A8..<0x1200).compactMap { UnicodeScalar($0) }.map { String($0) }
    static let jamoTailsModern = (0x11A8..<0x11C3).compactMap { UnicodeScalar($0) }.map { String($0) }
    
    // Unicode name mappings
    private static var jamoToName: [String: String] = [:]
    private static var jamoReverseLookup: [String: String] = [:]
    private static var hcjToName: [String: String] = [:]
    private static var hcjReverseLookup: [String: String] = [:]
    private static var dataLoaded = false
    
    // MARK: - Public Constants
    static let version = "0.4.1"
    
    // MARK: - Data Loading
    static func loadJamoData() async {
        if dataLoaded { return }
        
        do {
            // Load U+11xx.json (Jamo characters)
            if let jamoPath = Bundle.main.path(forResource: "U+11xx", ofType: "json") {
                let jamoData = try Data(contentsOf: URL(fileURLWithPath: jamoPath))
                if let jamoDict = try JSONSerialization.jsonObject(with: jamoData) as? [String: String] {
                    jamoToName = jamoDict
                    jamoReverseLookup = Dictionary(uniqueKeysWithValues: jamoDict.map { ($1, $0) })
                }
            }
            
            // Load U+31xx.json (HCJ characters)
            if let hcjPath = Bundle.main.path(forResource: "U+31xx", ofType: "json") {
                let hcjData = try Data(contentsOf: URL(fileURLWithPath: hcjPath))
                if let hcjDict = try JSONSerialization.jsonObject(with: hcjData) as? [String: String] {
                    hcjToName = hcjDict
                    hcjReverseLookup = Dictionary(uniqueKeysWithValues: hcjDict.map { ($1, $0) })
                }
            }
            
            dataLoaded = true
        } catch {
            print("Warning: Could not load jamo data files: \(error)")
            loadFallbackData()
            dataLoaded = true
        }
    }
    
    private static func loadFallbackData() {
        // Fallback data with basic mappings
        jamoToName = [
            // Lead consonants (basic set)
            String(UnicodeScalar(0x1100)!): "HANGUL CHOSEONG KIYEOK",
            String(UnicodeScalar(0x1101)!): "HANGUL CHOSEONG SSANGKIYEOK",
            String(UnicodeScalar(0x1102)!): "HANGUL CHOSEONG NIEUN",
            String(UnicodeScalar(0x1103)!): "HANGUL CHOSEONG TIKEUT",
            String(UnicodeScalar(0x1104)!): "HANGUL CHOSEONG SSANGTIKEUT",
            String(UnicodeScalar(0x1105)!): "HANGUL CHOSEONG RIEUL",
            String(UnicodeScalar(0x1106)!): "HANGUL CHOSEONG MIEUM",
            String(UnicodeScalar(0x1107)!): "HANGUL CHOSEONG PIEUP",
            String(UnicodeScalar(0x1108)!): "HANGUL CHOSEONG SSANGPIEUP",
            String(UnicodeScalar(0x1109)!): "HANGUL CHOSEONG SIOS",
            String(UnicodeScalar(0x110A)!): "HANGUL CHOSEONG SSANGSIOS",
            String(UnicodeScalar(0x110B)!): "HANGUL CHOSEONG IEUNG",
            String(UnicodeScalar(0x110C)!): "HANGUL CHOSEONG CIEUC",
            String(UnicodeScalar(0x110D)!): "HANGUL CHOSEONG SSANGCIEUC",
            String(UnicodeScalar(0x110E)!): "HANGUL CHOSEONG CHIEUCH",
            String(UnicodeScalar(0x110F)!): "HANGUL CHOSEONG KHIEUKH",
            String(UnicodeScalar(0x1110)!): "HANGUL CHOSEONG THIEUTH",
            String(UnicodeScalar(0x1111)!): "HANGUL CHOSEONG PHIEUPH",
            String(UnicodeScalar(0x1112)!): "HANGUL CHOSEONG HIEUH",
            
            // Vowels (basic set)
            String(UnicodeScalar(0x1161)!): "HANGUL JUNGSEONG A",
            String(UnicodeScalar(0x1162)!): "HANGUL JUNGSEONG AE",
            String(UnicodeScalar(0x1163)!): "HANGUL JUNGSEONG YA",
            String(UnicodeScalar(0x1164)!): "HANGUL JUNGSEONG YAE",
            String(UnicodeScalar(0x1165)!): "HANGUL JUNGSEONG EO",
            String(UnicodeScalar(0x1166)!): "HANGUL JUNGSEONG E",
            String(UnicodeScalar(0x1167)!): "HANGUL JUNGSEONG YEO",
            String(UnicodeScalar(0x1168)!): "HANGUL JUNGSEONG YE",
            String(UnicodeScalar(0x1169)!): "HANGUL JUNGSEONG O",
            String(UnicodeScalar(0x116A)!): "HANGUL JUNGSEONG WA",
            String(UnicodeScalar(0x116B)!): "HANGUL JUNGSEONG WAE",
            String(UnicodeScalar(0x116C)!): "HANGUL JUNGSEONG OE",
            String(UnicodeScalar(0x116D)!): "HANGUL JUNGSEONG YO",
            String(UnicodeScalar(0x116E)!): "HANGUL JUNGSEONG U",
            String(UnicodeScalar(0x116F)!): "HANGUL JUNGSEONG WEO",
            String(UnicodeScalar(0x1170)!): "HANGUL JUNGSEONG WE",
            String(UnicodeScalar(0x1171)!): "HANGUL JUNGSEONG WI",
            String(UnicodeScalar(0x1172)!): "HANGUL JUNGSEONG YU",
            String(UnicodeScalar(0x1173)!): "HANGUL JUNGSEONG EU",
            String(UnicodeScalar(0x1174)!): "HANGUL JUNGSEONG YI",
            String(UnicodeScalar(0x1175)!): "HANGUL JUNGSEONG I"
        ]
        
        hcjToName = [
            // Consonants (basic set)
            String(UnicodeScalar(0x3131)!): "HANGUL LETTER KIYEOK",
            String(UnicodeScalar(0x3132)!): "HANGUL LETTER SSANGKIYEOK",
            String(UnicodeScalar(0x3134)!): "HANGUL LETTER NIEUN",
            String(UnicodeScalar(0x3137)!): "HANGUL LETTER TIKEUT",
            String(UnicodeScalar(0x3139)!): "HANGUL LETTER RIEUL",
            String(UnicodeScalar(0x3141)!): "HANGUL LETTER MIEUM",
            String(UnicodeScalar(0x3142)!): "HANGUL LETTER PIEUP",
            String(UnicodeScalar(0x3145)!): "HANGUL LETTER SIOS",
            String(UnicodeScalar(0x3147)!): "HANGUL LETTER IEUNG",
            String(UnicodeScalar(0x3148)!): "HANGUL LETTER CIEUC",
            String(UnicodeScalar(0x314A)!): "HANGUL LETTER CHIEUCH",
            String(UnicodeScalar(0x314B)!): "HANGUL LETTER KHIEUKH",
            String(UnicodeScalar(0x314C)!): "HANGUL LETTER THIEUTH",
            String(UnicodeScalar(0x314D)!): "HANGUL LETTER PHIEUPH",
            String(UnicodeScalar(0x314E)!): "HANGUL LETTER HIEUH",
            
            // Vowels (basic set)
            String(UnicodeScalar(0x314F)!): "HANGUL LETTER A",
            String(UnicodeScalar(0x3150)!): "HANGUL LETTER AE",
            String(UnicodeScalar(0x3151)!): "HANGUL LETTER YA",
            String(UnicodeScalar(0x3153)!): "HANGUL LETTER EO",
            String(UnicodeScalar(0x3154)!): "HANGUL LETTER E",
            String(UnicodeScalar(0x3157)!): "HANGUL LETTER O",
            String(UnicodeScalar(0x315C)!): "HANGUL LETTER U",
            String(UnicodeScalar(0x3161)!): "HANGUL LETTER EU",
            String(UnicodeScalar(0x3163)!): "HANGUL LETTER I"
        ]
        
        // Create reverse lookups
        jamoReverseLookup = Dictionary(uniqueKeysWithValues: jamoToName.map { ($1, $0) })
        hcjReverseLookup = Dictionary(uniqueKeysWithValues: hcjToName.map { ($1, $0) })
    }
    
    // MARK: - Core Functions
    
    /// Return a tuple of lead, vowel, and tail jamo characters.
    /// Note: Non-Hangul characters are echoed back.
    private static func hangulCharToJamo(_ syllable: String) -> Any {
        if isHangulChar(syllable) {
            guard let scalar = syllable.unicodeScalars.first else { return syllable }
            let rem = Int(scalar.value) - jamoOffset
            let tail = rem % 28
            let vowel = 1 + ((rem - tail) % 588) / 28
            let lead = 1 + rem / 588
            
            if tail != 0 {
                return [
                    String(UnicodeScalar(lead + jamoLeadOffset)!),
                    String(UnicodeScalar(vowel + jamoVowelOffset)!),
                    String(UnicodeScalar(tail + jamoTailOffset)!)
                ]
            } else {
                return [
                    String(UnicodeScalar(lead + jamoLeadOffset)!),
                    String(UnicodeScalar(vowel + jamoVowelOffset)!)
                ]
            }
        } else {
            return syllable
        }
    }
    
    /// Return the Hangul character for the given jamo characters.
    private static func jamoToHangulChar(lead: String, vowel: String, tail: String? = nil) -> String {
        guard let leadScalar = lead.unicodeScalars.first,
              let vowelScalar = vowel.unicodeScalars.first else {
            return lead + vowel + (tail ?? "")
        }
        
        let leadCode = Int(leadScalar.value) - jamoLeadOffset
        let vowelCode = Int(vowelScalar.value) - jamoVowelOffset
        var tailCode = 0
        
        if let tail = tail, let tailScalar = tail.unicodeScalars.first {
            tailCode = Int(tailScalar.value) - jamoTailOffset
        }
        
        let code = tailCode + (vowelCode - 1) * 28 + (leadCode - 1) * 588 + jamoOffset
        
        if let scalar = UnicodeScalar(code) {
            return String(scalar)
        }
        
        return lead + vowel + (tail ?? "")
    }
    
    // MARK: - Character Testing Functions
    
    /// Test if a single character is a jamo character.
    static func isJamo(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let code = Int(scalar.value)
        return (0x1100 <= code && code <= 0x11FF) ||
               (0xA960 <= code && code <= 0xA97C) ||
               (0xD7B0 <= code && code <= 0xD7C6) ||
               (0xD7CB <= code && code <= 0xD7FB) ||
               isHcj(character)
    }
    
    /// Test if a single character is a modern jamo character.
    static func isJamoModern(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let code = Int(scalar.value)
        return (0x1100 <= code && code <= 0x1112) ||
               (0x1161 <= code && code <= 0x1175) ||
               (0x11A8 <= code && code <= 0x11C2) ||
               isHcjModern(character)
    }
    
    /// Test if a single character is a HCJ character.
    static func isHcj(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let code = Int(scalar.value)
        return 0x3131 <= code && code <= 0x318E && code != 0x3164
    }
    
    /// Test if a single character is a modern HCJ character.
    static func isHcjModern(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let code = Int(scalar.value)
        return (0x3131 <= code && code <= 0x314E) ||
               (0x314F <= code && code <= 0x3163)
    }
    
    /// Test if a single character is in the U+AC00 to U+D7A3 code block.
    static func isHangulChar(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let code = Int(scalar.value)
        return 0xAC00 <= code && code <= 0xD7A3
    }
    
    /// Determine if a jamo character is a lead, vowel, or tail.
    static func getJamoClass(_ jamo: String) throws -> String {
        guard !jamo.isEmpty else {
            throw InvalidJamoError("Invalid or classless jamo argument.", jamo)
        }
        
        if jamoLeads.contains(jamo) || jamo == String(UnicodeScalar(0x115F)!) {
            return "lead"
        }
        
        guard let scalar = jamo.unicodeScalars.first else {
            throw InvalidJamoError("Invalid or classless jamo argument.", jamo)
        }
        
        let code = Int(scalar.value)
        if jamoVowels.contains(jamo) || jamo == String(UnicodeScalar(0x1160)!) ||
           (0x314F <= code && code <= 0x3163) {
            return "vowel"
        }
        
        if jamoTails.contains(jamo) {
            return "tail"
        }
        
        throw InvalidJamoError("Invalid or classless jamo argument.", jamo)
    }
    
    // MARK: - Conversion Functions
    
    /// Convert jamo to HCJ.
    static func jamoToHcj(_ data: [String]) -> [String] {
        return data.map { jamoCharToHcj($0) }
    }
    
    /// Convert jamo into HCJ (string version).
    static func j2hcj(_ jamo: String) -> String {
        return jamoToHcj(Array(jamo).map(String.init)).joined()
    }
    
    /// Convert jamo character to HCJ
    private static func jamoCharToHcj(_ char: String) -> String {
        if isJamo(char) {
            if let unicodeName = getUnicodeName(char) {
                let hcjName = unicodeName.replacingOccurrences(
                    of: "(?<=HANGUL )\\w+",
                    with: "LETTER",
                    options: .regularExpression
                )
                if let hcjChar = hcjReverseLookup[hcjName] {
                    return hcjChar
                }
            }
        }
        return char
    }
    
    /// Convert HCJ character to jamo character.
    static func hcjToJamo(_ hcjChar: String, position: String = "vowel") -> String {
        let jamoClass: String
        switch position {
        case "lead":
            jamoClass = "CHOSEONG"
        case "vowel":
            jamoClass = "JUNGSEONG"
        case "tail":
            jamoClass = "JONGSEONG"
        default:
            return hcjChar
        }
        
        if let unicodeName = getUnicodeName(hcjChar) {
            let jamoName = unicodeName.replacingOccurrences(
                of: "(?<=HANGUL )\\w+",
                with: jamoClass,
                options: .regularExpression
            )
            if let jamoChar = jamoReverseLookup[jamoName] {
                return jamoChar
            }
        }
        
        return hcjChar
    }
    
    /// Convert HCJ to jamo (alias for hcjToJamo).
    static func hcj2j(_ hcjChar: String, position: String = "vowel") -> String {
        return hcjToJamo(hcjChar, position: position)
    }
    
    /// Convert a string of Hangul to jamo.
    static func hangulToJamo(_ hangulString: String) -> [String] {
        var result: [String] = []
        
        for char in hangulString {
            let charString = String(char)
            let jamoResult = hangulCharToJamo(charString)
            
            if let jamoArray = jamoResult as? [String] {
                result.append(contentsOf: jamoArray)
            } else if let jamoString = jamoResult as? String {
                result.append(jamoString)
            }
        }
        
        return result
    }
    
    /// Convert Hangul to jamo (string version).
    static func h2j(_ hangulString: String) -> String {
        return hangulToJamo(hangulString).joined()
    }
    
    /// Return the Hangul character for the given jamo input.
    static func jamoToHangul(lead: String, vowel: String, tail: String = "") throws -> String {
        // Convert everything to jamo characters
        let jamoLead = hcjToJamo(lead, position: "lead")
        let jamoVowel = hcjToJamo(vowel, position: "vowel")
        var jamoTail: String? = nil
        
        if !tail.isEmpty {
            if isHcj(tail) {
                jamoTail = hcjToJamo(tail, position: "tail")
            } else {
                jamoTail = tail
            }
        }
        
        // Validate inputs
        guard isJamo(jamoLead), try getJamoClass(jamoLead) == "lead" else {
            throw InvalidJamoError("Invalid lead consonant", lead)
        }
        
        guard isJamo(jamoVowel), try getJamoClass(jamoVowel) == "vowel" else {
            throw InvalidJamoError("Invalid vowel", vowel)
        }
        
        if let jamoTail = jamoTail {
            guard jamoTail.isEmpty || (isJamo(jamoTail) && (try? getJamoClass(jamoTail)) == "tail") else {
                throw InvalidJamoError("Invalid tail consonant", tail)
            }
        }
        
        let result = jamoToHangulChar(lead: jamoLead, vowel: jamoVowel, tail: jamoTail)
        
        if isHangulChar(result) {
            return result
        }
        
        throw InvalidJamoError("Could not synthesize characters to Hangul.", "")
    }
    
    /// Convert jamo to Hangul (alias for jamoToHangul).
    static func j2h(lead: String, vowel: String, tail: String = "") throws -> String {
        return try jamoToHangul(lead: lead, vowel: vowel, tail: tail)
    }
    
    // MARK: - Helper Functions
    
    /// Fetch the unicode name for jamo characters.
    private static func getUnicodeName(_ char: String) -> String? {
        if !jamoToName.keys.contains(char) && !hcjToName.keys.contains(char) {
            return nil
        }
        
        if isHcj(char) {
            return hcjToName[char]
        }
        return jamoToName[char]
    }
}

// MARK: - Error Types
struct InvalidJamoError: Error, LocalizedError {
    let message: String
    let jamo: String
    
    init(_ message: String, _ jamo: String) {
        self.message = message
        self.jamo = jamo
    }
    
    var errorDescription: String? {
        if let scalar = jamo.unicodeScalars.first {
            let code = Int(scalar.value)
            print("Could not parse jamo: U+\(String(format: "%04X", code))")
        }
        return "InvalidJamoError: \(message)"
    }
}

// MARK: - Global Functions (for compatibility)
/// Test if a single character is a jamo character.
func isJamo(_ character: String) -> Bool {
    return Jamo.isJamo(character)
}

/// Test if a single character is a modern jamo character.
func isJamoModern(_ character: String) -> Bool {
    return Jamo.isJamoModern(character)
}

/// Test if a single character is a HCJ character.
func isHcj(_ character: String) -> Bool {
    return Jamo.isHcj(character)
}

/// Test if a single character is a modern HCJ character.
func isHcjModern(_ character: String) -> Bool {
    return Jamo.isHcjModern(character)
}

/// Test if a single character is Hangul.
func isHangulChar(_ character: String) -> Bool {
    return Jamo.isHangulChar(character)
}

/// Get jamo class.
func getJamoClass(_ jamo: String) throws -> String {
    return try Jamo.getJamoClass(jamo)
}

/// Convert jamo to HCJ.
func jamoToHcj(_ data: [String]) -> [String] {
    return Jamo.jamoToHcj(data)
}

/// Convert jamo to HCJ (string version).
func j2hcj(_ jamo: String) -> String {
    return Jamo.j2hcj(jamo)
}

/// Convert HCJ to jamo.
func hcjToJamo(_ hcjChar: String, position: String = "vowel") -> String {
    return Jamo.hcjToJamo(hcjChar, position: position)
}

/// Convert HCJ to jamo (alias).
func hcj2j(_ hcjChar: String, position: String = "vowel") -> String {
    return Jamo.hcj2j(hcjChar, position: position)
}

/// Convert Hangul to jamo.
func hangulToJamo(_ hangulString: String) -> [String] {
    return Jamo.hangulToJamo(hangulString)
}

/// Convert Hangul to jamo (string version).
func h2j(_ hangulString: String) -> String {
    return Jamo.h2j(hangulString)
}

/// Convert jamo to Hangul.
func jamoToHangul(lead: String, vowel: String, tail: String = "") throws -> String {
    return try Jamo.jamoToHangul(lead: lead, vowel: vowel, tail: tail)
}

/// Convert jamo to Hangul (alias).
func j2h(lead: String, vowel: String, tail: String = "") throws -> String {
    return try Jamo.j2h(lead: lead, vowel: vowel, tail: tail)
}
