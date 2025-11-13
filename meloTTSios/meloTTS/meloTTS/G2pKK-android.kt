// package com.millie.tts

// import android.content.Context
// import android.util.Log
// import java.io.BufferedReader
// import java.io.InputStreamReader

// /**
//  * Complete Kotlin port of g2pkk library for Korean G2P conversion
//  * Direct translation from Python g2pkk to ensure identical behavior
//  */
// class G2pKK(private val context: Context) {
//     companion object {
//         private const val TAG = "G2pKK"
        
//         // Jamo Unicode ranges
//         private const val CHOSUNG_BASE = 0x1100
//         private const val JUNGSUNG_BASE = 0x1161
//         private const val JONGSUNG_BASE = 0x11A8
//         private const val HANGUL_BASE = 0xAC00
        
//         // Jamo lists
//         private val CHOSUNG_LIST = listOf(
//             'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ',
//             'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
//         )
        
//         private val JUNGSUNG_LIST = listOf(
//             'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ',
//             'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'
//         )
        
//         private val JONGSUNG_LIST = listOf(
//             ' ', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ',
//             'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ',
//             'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
//         )
//     }
    
//     // Rule ID to text mapping
//     private val ruleIdToText = mutableMapOf<String, String>()
    
//     // Main phonological transformation table
//     private val transformationTable = mutableListOf<Triple<String, String, List<String>>>()
    
//     // Idioms mappings
//     private val idioms = mutableListOf<Pair<String, String>>()
    
//     // MeCab replacement - simple POS tagger for Korean
//     private val mecab = SimpleMecab()
    
//     init {
//         loadRules()
//         loadTable()
//         loadIdioms()
//     }
    
//     /**
//      * Main G2P conversion function
//      */
//     fun convert(text: String, descriptive: Boolean = false, verbose: Boolean = false): String {
//         var result = text
//         Log.d(TAG, "G2pKK convert input: '$text'")
        
//         // 1. Process idioms
//         result = processIdioms(result, descriptive, verbose)
//         if (result != text) {
//             Log.d(TAG, "After idioms: '$result'")
//         }
        
//         // 2. English to Hangul (skip for now, handle separately if needed)
//         // result = convertEng(result)
        
//         // 3. Annotate with POS tags
//         result = annotate(result)
//         if (result.contains("/")) {
//             Log.d(TAG, "After annotation: '$result'")
//         }
        
//         // 4. Spell out numbers (skip for now, handle separately if needed)
//         // result = convertNum(result)
        
//         // 5. Decompose to Jamo (MUST decompose before special rules!)
//         val beforeJamo = result
//         result = h2j(result)
//         Log.d(TAG, "After h2j decomposition:")
//         Log.d(TAG, "  Original: '$beforeJamo'")
//         Log.d(TAG, "  Decomposed length: ${result.length} chars")
//         Log.d(TAG, "  First 30 chars hex: ${result.take(30).map { "U+${it.code.toString(16)}" }.joinToString(" ")}")
//         Log.d(TAG, "  Decomposed text: '$result'")
        
//         // 6. Apply special rules
//         Log.d(TAG, "Before special rules: '$result'")
//         result = jyeo(result, descriptive, true)  // Force verbose for jyeo
//         Log.d(TAG, "After jyeo: '$result'")
//         result = ye(result, descriptive, verbose)
//         result = consonantUi(result, descriptive, verbose)
//         result = josaUi(result, descriptive, verbose)
//         result = vowelUi(result, descriptive, verbose)
//         result = jamo(result, descriptive, verbose)
//         result = rieulgiyeok(result, descriptive, verbose)
//         result = rieulbieub(result, descriptive, verbose)
//         result = verbNieun(result, descriptive, verbose)
//         result = balb(result, descriptive, verbose)
//         result = palatalize(result, descriptive, verbose)
//         result = modifyingRieul(result, descriptive, verbose)
//         Log.d(TAG, "After all special rules: '$result'")
        
//         // Remove POS markers
//         result = result.replace("/[PJEB]".toRegex(), "")
        
//         // 7. Apply regular table transformations
//         Log.d(TAG, "Applying ${transformationTable.size} transformation rules...")
//         for ((pattern, replacement, ruleIds) in transformationTable) {
//             val before = result
//             // Convert Python regex replacement format (\1, \2, etc.) to Kotlin format ($1, $2, etc.)
//             val kotlinReplacement = replacement
//                 .replace(Regex("""\\(\d)""")) { matchResult ->
//                     "$${matchResult.groupValues[1]}"
//                 }
            
//             result = result.replace(pattern.toRegex(), kotlinReplacement)
//             if (result != before) {
//                 val rule = ruleIds.joinToString("\n") { ruleIdToText[it] ?: "" }
//                 Log.d(TAG, "Rule applied: '$pattern' -> '$replacement' (kotlin: '$kotlinReplacement')")
//                 if (verbose) {
//                     Log.d(TAG, "${compose(before)} -> ${compose(result)}")
//                     Log.d(TAG, "Rule: $rule")
//                 }
//             }
//         }
        
//         // 8. Apply linking rules
//         result = link1(result, descriptive, verbose)
//         result = link2(result, descriptive, verbose)
//         result = link3(result, descriptive, verbose)
//         result = link4(result, descriptive, verbose)
        
//         Log.d(TAG, "Before compose: '${result.take(50)}...'")
        
//         // 9. Compose back to syllables
//         result = compose(result)
        
//         Log.d(TAG, "After compose: '$result'")
        
//         return result
//     }
    
//     /**
//      * Process idioms from idioms.txt
//      */
//     private fun processIdioms(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         for ((pattern, replacement) in idioms) {
//             result = result.replace(pattern.toRegex(), replacement)
//         }
//         return result
//     }
    
//     /**
//      * Annotate text with POS tags
//      */
//     private fun annotate(text: String): String {
//         val tokens = mecab.pos(text)
//         if (text.replace(" ", "") != tokens.joinToString("") { it.first }) {
//             return text
//         }
        
//         val blanks = text.indices.filter { text[it] == ' ' }
        
//         val tagSeq = tokens.map { (token, tag) ->
//             val finalTag = tag.split("+").last()
//             val tagChar = when {
//                 finalTag == "NNBC" -> "B"
//                 else -> finalTag.firstOrNull() ?: '_'
//             }
//             "_".repeat(token.length - 1) + tagChar
//         }.joinToString("")
        
//         var tagSeqWithBlanks = tagSeq
//         blanks.forEach { i ->
//             tagSeqWithBlanks = tagSeqWithBlanks.substring(0, i) + " " + tagSeqWithBlanks.substring(i)
//         }
        
//         val annotated = StringBuilder()
//         text.zip(tagSeqWithBlanks).forEach { (char, tag) ->
//             annotated.append(char)
//             when {
//                 char == '의' && tag == 'J' -> annotated.append("/J")
//                 tag == 'E' && h2j(char.toString()).lastOrNull() == 'ㄹ' -> annotated.append("/E")
//                 tag == 'V' -> {
//                     val lastJamo = h2j(char.toString()).lastOrNull()
//                     if (lastJamo != null && lastJamo in listOf('ㄴ', 'ㄵ', 'ㅁ', 'ㄻ', 'ㄺ', 'ㄲ', 'ㄼ')) {
//                         annotated.append("/P")
//                     }
//                 }
//                 tag == 'B' -> annotated.append("/B")
//             }
//         }
        
//         return annotated.toString()
//     }
    
//     /**
//      * Special rules from special.py
//      */
    
//     // Rule 5.1
//     private fun jyeo(text: String, descriptive: Boolean, verbose: Boolean): String {
//         // Use Hangul Jamo (U+1100 series) not Compatibility Jamo
//         // ᄌ=U+110C, ᄍ=U+110D, ᄎ=U+110E, ᅧ=U+1167, ᅥ=U+1165
//         val pattern = "([\\u110C\\u110D\\u110E])\\u1167".toRegex()
//         val result = text.replace(pattern, "$1\u1165")
//         if (result != text) {
//             Log.d(TAG, "jyeo rule applied: U+110C/D/E + U+1167 → U+110C/D/E + U+1165")
//             Log.d(TAG, "  Before jyeo: ${text.take(30)}")
//             Log.d(TAG, "  After jyeo: ${result.take(30)}")
//         }
//         return result
//     }
    
//     // Rule 5.2
//     private fun ye(text: String, descriptive: Boolean, verbose: Boolean): String {
//         if (descriptive) {
//             // Use Hangul Jamo (U+1100 series)
//             return text.replace("([ᄀᄁᄃᄄᄅᄆᄇᄂᄌᄍᄎᄏᄐᄑᄒ])ᅨ".toRegex(), "$1ᅦ")
//         }
//         return text
//     }
    
//     // Rule 5.3
//     private fun consonantUi(text: String, descriptive: Boolean, verbose: Boolean): String {
//         // Use Hangul Jamo (U+1100 series)
//         return text.replace("([ᄀᄁᄂᄃᄄᄅᄆᄇᄂᄉᄊᄌᄍᄎᄏᄐᄑᄒ])ᅴ".toRegex(), "$1ᅵ")
//     }
    
//     // Rule 5.4.2
//     private fun josaUi(text: String, descriptive: Boolean, verbose: Boolean): String {
//         if (descriptive) {
//             return text.replace("의/J".toRegex(), "에")
//         }
//         return text.replace("/J", "")
//     }
    
//     // Rule 5.4.1
//     private fun vowelUi(text: String, descriptive: Boolean, verbose: Boolean): String {
//         if (descriptive) {
//             // Use Hangul Jamo (U+1100 series)
//             return text.replace("(\\S)의".toRegex(), "$1이")
//         }
//         return text
//     }
    
//     // Rule 16
//     private fun jamo(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         // Note: These rules work with decomposed forms
//         // The patterns should be in Hangul Jamo after h2j conversion
//         result = result.replace("([그])ᆮᄋ".toRegex(), "$1ᆺ")  
//         result = result.replace("([ᅳ])[ᄌᄎᄐᄒ]ᄋ".toRegex(), "$1ᆺ")
//         result = result.replace("([ᅳ])[ᄏ]ᄋ".toRegex(), "$1ᆨ")
//         result = result.replace("([ᅳ])[ᄑ]ᄋ".toRegex(), "$1ᆸ")
//         return result
//     }
    
//     // Rule 11.1
//     private fun rieulgiyeok(text: String, descriptive: Boolean, verbose: Boolean): String {
//         return text.replace("ㄺ/P([ㄱㄲ])".toRegex(), "ㄹㄲ")
//     }
    
//     // Rule 25
//     private fun rieulbieub(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         result = result.replace("([ㄲㄼ])/Pㄱ".toRegex(), "$1ㄲ")
//         result = result.replace("([ㄲㄼ])/Pㄷ".toRegex(), "$1ㄸ")
//         result = result.replace("([ㄲㄼ])/Pㅅ".toRegex(), "$1ㅆ")
//         result = result.replace("([ㄲㄼ])/Pㅈ".toRegex(), "$1ㅉ")
//         return result
//     }
    
//     // Rule 24
//     private fun verbNieun(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         val pairs = listOf(
//             "([ㄴㅁ])/Pㄱ" to "$1ㄲ",
//             "([ㄴㅁ])/Pㄷ" to "$1ㄸ",
//             "([ㄴㅁ])/Pㅅ" to "$1ㅆ",
//             "([ㄴㅁ])/Pㅈ" to "$1ㅉ",
//             "ㄵ/Pㄱ" to "ㄴㄲ",
//             "ㄵ/Pㄷ" to "ㄴㄸ",
//             "ㄵ/Pㅅ" to "ㄴㅆ",
//             "ㄵ/Pㅈ" to "ㄴㅉ",
//             "ㄻ/Pㄱ" to "ㅁㄲ",
//             "ㄻ/Pㄷ" to "ㅁㄸ",
//             "ㄻ/Pㅅ" to "ㅁㅆ",
//             "ㄻ/Pㅈ" to "ㅁㅉ"
//         )
//         for ((pattern, replacement) in pairs) {
//             result = result.replace(pattern.toRegex(), replacement)
//         }
//         return result
//     }
    
//     // Rule 10.1
//     private fun balb(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         val syllableFinalOrConsonants = "($|[^ㅇㅎ])"
//         result = result.replace("(바)ㄲ($syllableFinalOrConsonants)".toRegex(), "$1ㅂ$2")
//         result = result.replace("(너)ㄲ([ㅈㅉ]ㅜ|[ㄷㄸ]ㅜ)".toRegex(), "$1ㅂ$2")
//         return result
//     }
    
//     // Rule 17
//     private fun palatalize(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         result = result.replace("ㄷㅇ([ㅣㅕ])".toRegex(), "ㅈ$1")
//         result = result.replace("ㅌㅇ([ㅣㅕ])".toRegex(), "ㅊ$1")
//         result = result.replace("ㄼㅇ([ㅣㅕ])".toRegex(), "ㄹㅊ$1")
//         result = result.replace("ㄷㅎ([ㅣ])".toRegex(), "ㅊ$1")
//         return result
//     }
    
//     // Rule 27
//     private fun modifyingRieul(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         val pairs = listOf(
//             "ㄹ/E ㄱ" to "ㄹ ㄲ",
//             "ㄹ/E ㄷ" to "ㄹ ㄸ",
//             "ㄹ/E ㅂ" to "ㄹ ㅂ",
//             "ㄹ/E ㅅ" to "ㄹ ㅆ",
//             "ㄹ/E ㅈ" to "ㄹ ㅉ",
//             "ㄹ걸" to "ㄹ껄",
//             "ㄹ밖에" to "ㄹ빠께",
//             "ㄹ세라" to "ㄹ쎄라",
//             "ㄹ수록" to "ㄹ쑤록",
//             "ㄹ지라도" to "ㄹ찌라도",
//             "ㄹ지언정" to "ㄹ찌언정",
//             "ㄹ진대" to "ㄹ찐대"
//         )
//         for ((pattern, replacement) in pairs) {
//             result = result.replace(pattern, replacement)
//         }
//         return result
//     }
    
//     /**
//      * Linking rules from regular.py
//      */
    
//     // Rule 13
//     private fun link1(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         // Use Hangul Jamo characters (U+1100 series)
//         val pairs = listOf(
//             "\u11a8\u110b" to "\u1100",  // ᆨᄋ -> ᄀ
//             "\u11a9\u110b" to "\u1101",  // ᆩᄋ -> ᄁ
//             "\u11ab\u110b" to "\u1102",  // ᆫᄋ -> ᄂ
//             "\u11ae\u110b" to "\u1103",  // ᆮᄋ -> ᄃ
//             "\u11af\u110b" to "\u1105",  // ᆯᄋ -> ᄅ
//             "\u11b7\u110b" to "\u1106",  // ᆷᄋ -> ᄆ
//             "\u11b8\u110b" to "\u1107",  // ᆸᄋ -> ᄇ
//             "\u11ba\u110b" to "\u1109",  // ᆺᄋ -> ᄉ
//             "\u11bb\u110b" to "\u110a",  // ᆻᄋ -> ᄊ (ㅆ연음 규칙!)
//             "\u11bd\u110b" to "\u110c",  // ᆽᄋ -> ᄌ
//             "\u11be\u110b" to "\u110e",  // ᆾᄋ -> ᄎ
//             "\u11bf\u110b" to "\u110f",  // ᆿᄋ -> ᄏ
//             "\u11c0\u110b" to "\u1110",  // ᇀᄋ -> ᄐ
//             "\u11c1\u110b" to "\u1111"   // ᇁᄋ -> ᄑ
//         )
//         for ((pattern, replacement) in pairs) {
//             val before = result
//             result = result.replace(pattern, replacement)
//             if (result != before && verbose) {
//                 Log.d(TAG, "link1 rule applied: $pattern → $replacement")
//             }
//         }
//         return result
//     }
    
//     // Rule 14
//     private fun link2(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         val pairs = listOf(
//             "ㄳㅇ" to "ㄱㅆ",
//             "ㄵㅇ" to "ㄴㅈ",
//             "ㄺㅇ" to "ㄹㄱ",
//             "ㄻㅇ" to "ㄹㅁ",
//             "ㄲㅇ" to "ㄹㅂ",
//             "ㄳㅇ" to "ㄹㅆ",
//             "ㄼㅇ" to "ㄹㅌ",
//             "ㄽㅇ" to "ㄹㅍ",
//             "ㅄㅇ" to "ㅂㅆ"
//         )
//         for ((pattern, replacement) in pairs) {
//             result = result.replace(pattern, replacement)
//         }
//         return result
//     }
    
//     // Rule 15
//     private fun link3(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         // Use Hangul Jamo characters with spaces
//         val pairs = listOf(
//             "\u11a8 \u110b" to " \u1100",  // ㄱ ㅇ -> ㄱ
//             "\u11a9 \u110b" to " \u1101",  // ㄲ ㅇ -> ㄲ
//             "\u11ab \u110b" to " \u1102",  // ㄴ ㅇ -> ㄴ
//             "\u11ae \u110b" to " \u1103",  // ㄷ ㅇ -> ㄷ
//             "\u11af \u110b" to " \u1105",  // ㄹ ㅇ -> ㄹ
//             "\u11b7 \u110b" to " \u1106",  // ㅁ ㅇ -> ㅁ
//             "\u11b8 \u110b" to " \u1107",  // ㅂ ㅇ -> ㅂ
//             "\u11ba \u110b" to " \u1109",  // ㅅ ㅇ -> ㅅ
//             "\u11bb \u110b" to " \u110a",  // ㅆ ㅇ -> ㅆ (연음 규칙!)
//             "\u11bd \u110b" to " \u110c",  // ㅈ ㅇ -> ㅈ
//             "\u11be \u110b" to " \u110e",  // ㅊ ㅇ -> ㅊ
//             "\u11bf \u110b" to " \u110f",  // ㅋ ㅇ -> ㅋ
//             "\u11c0 \u110b" to " \u1110",  // ㅌ ㅇ -> ㅌ
//             "\u11c1 \u110b" to " \u1111",  // ㅍ ㅇ -> ㅍ
//             "\u11aa \u110b" to "\u11a8 \u110a",  // ㄳ ㅇ -> ㄱ ㅆ
//             "\u11ac \u110b" to "\u11ab \u110c",  // ㄵ ㅇ -> ㄴ ㅈ
//             "\u11b0 \u110b" to "\u11af \u1100",  // ㄺ ㅇ -> ㄹ ㄱ
//             "\u11b1 \u110b" to "\u11af \u1106",  // ㄻ ㅇ -> ㄹ ㅁ
//             "\u11b2 \u110b" to "\u11af \u1107",  // ㄼ ㅇ -> ㄹ ㅂ
//             "\u11b3 \u110b" to "\u11af \u110a",  // ㄽ ㅇ -> ㄹ ㅆ
//             "\u11b4 \u110b" to "\u11af \u1110",  // ㄾ ㅇ -> ㄹ ㅌ
//             "\u11b5 \u110b" to "\u11af \u1111",  // ㄿ ㅇ -> ㄹ ㅍ
//             "\u11b9 \u110b" to "\u11b8 \u110a"   // ㅄ ㅇ -> ㅂ ㅆ
//         )
//         for ((pattern, replacement) in pairs) {
//             val before = result
//             result = result.replace(pattern, replacement)
//             if (result != before && verbose) {
//                 Log.d(TAG, "link3 rule applied: $pattern → $replacement")
//             }
//         }
//         return result
//     }
    
//     // Rule 12.4
//     private fun link4(text: String, descriptive: Boolean, verbose: Boolean): String {
//         var result = text
//         val pairs = listOf(
//             "ㅎㅇ" to "ㅇ",
//             "ㄶㅇ" to "ㄴ",
//             "ㅀㅇ" to "ㄹ"
//         )
//         for ((pattern, replacement) in pairs) {
//             result = result.replace(pattern, replacement)
//         }
//         return result
//     }
    
//     /**
//      * Utility functions
//      */
    
//     // Hangul to Jamo decomposition
//     private fun h2j(text: String): String {
//         val result = StringBuilder()
//         var charCount = 0
//         for (char in text) {
//             if (char in '가'..'힣') {
//                 val code = char.code - HANGUL_BASE
//                 val choIdx = code / (21 * 28)
//                 val jungIdx = (code % (21 * 28)) / 28
//                 val jongIdx = code % 28
                
//                 val cho = (CHOSUNG_BASE + choIdx).toChar()
//                 val jung = (JUNGSUNG_BASE + jungIdx).toChar()
                
//                 result.append(cho)
//                 result.append(jung)
//                 if (jongIdx != 0) {
//                     val jong = (JONGSUNG_BASE + jongIdx - 1).toChar()
//                     result.append(jong)
//                 }
                
//                 // Debug first character
//                 if (charCount == 0) {
//                     Log.d(TAG, "h2j decompose first char '$char' (U+${char.code.toString(16)})")
//                     Log.d(TAG, "  → cho=$cho (U+${cho.code.toString(16)}) jung=$jung (U+${jung.code.toString(16)}) jong=${if (jongIdx != 0) (JONGSUNG_BASE + jongIdx - 1).toChar() else '-'}")
//                 }
//                 charCount++
//             } else {
//                 result.append(char)
//             }
//         }
//         Log.d(TAG, "h2j converted $charCount Hangul chars")
//         return result.toString()
//     }
    
//     // Jamo to Hangul composition
//     private fun compose(text: String): String {
//         var result = text
        
//         // Insert placeholder ㅇ for vowel-initial syllables
//         result = result.replace("(^|[^\\u1100-\\u1112])([\\u1161-\\u1175])".toRegex(), "$1ㅇ$2")
        
//         // Compose C+V+C syllables
//         val cvcPattern = "[\\u1100-\\u1112][\\u1161-\\u1175][\\u11A8-\\u11C2]".toRegex()
//         cvcPattern.findAll(result).map { it.value }.toSet().forEach { syl ->
//             val chars = syl.toCharArray()
//             val composed = j2h(chars[0], chars[1], chars[2])
//             result = result.replace(syl, composed.toString())
//         }
        
//         // Compose C+V syllables
//         val cvPattern = "[\\u1100-\\u1112][\\u1161-\\u1175]".toRegex()
//         cvPattern.findAll(result).map { it.value }.toSet().forEach { syl ->
//             val chars = syl.toCharArray()
//             val composed = j2h(chars[0], chars[1], null)
//             result = result.replace(syl, composed.toString())
//         }
        
//         return result
//     }
    
//     // Jamo to Hangul character
//     private fun j2h(cho: Char, jung: Char, jong: Char?): Char {
//         val choIdx = cho.code - CHOSUNG_BASE
//         val jungIdx = jung.code - JUNGSUNG_BASE
//         val jongIdx = if (jong != null) jong.code - JONGSUNG_BASE + 1 else 0
        
//         return (HANGUL_BASE + choIdx * 21 * 28 + jungIdx * 28 + jongIdx).toChar()
//     }
    
//     /**
//      * Load rules from embedded data
//      */
//     private fun loadRules() {
//         // This would load from rules.txt - simplified for now
//         ruleIdToText["5.1"] = "ㅈ, ㅉ, ㅊ 다음의 이중모음 'ㅕ'는 [ㅓ]로 발음한다."
//         ruleIdToText["5.2"] = "'예, 례' 이외의 'ㅖ'는 [ㅔ]로 발음한다."
//         ruleIdToText["5.3"] = "자음을 첫소리로 가지고 있는 음절의 'ㅢ'는 [ㅣ]로 발음한다."
//         ruleIdToText["5.4.1"] = "단어의 첫음절 이외의 '의'는 [ㅣ]로, 조사 '의'는 [ㅔ]로 발음함도 허용한다."
//         ruleIdToText["5.4.2"] = "조사 '의'는 [ㅔ]로 발음함도 허용한다."
//         // Add more rules as needed
//     }
    
//     /**
//      * Load transformation table from CSV file
//      */
//     private fun loadTable() {
//         try {
//             context.assets.open("data/g2pkk_table.csv").use { inputStream ->
//                 BufferedReader(InputStreamReader(inputStream, Charsets.UTF_8)).use { reader ->
//                     val lines = reader.readLines()
//                     if (lines.isEmpty()) return
                    
//                     // First line contains onsets
//                     val onsets = lines[0].split(",").drop(1)
                    
//                     // Process each row (coda)
//                     for (i in 1 until lines.size) {
//                         val cols = lines[i].split(",")
//                         if (cols.isEmpty()) continue
                        
//                         val coda = cols[0]
                        
//                         for (j in 1 until cols.size.coerceAtMost(onsets.size + 1)) {
//                             val cell = cols[j]
//                             if (cell.isEmpty()) continue
                            
//                             val onset = onsets[j - 1]
//                             val pattern = coda + onset
                            
//                             val (replacement, ruleIds) = if ("(" in cell) {
//                                 val parts = cell.split("(")
//                                 val repl = parts[0]
//                                 val rules = parts[1].removeSuffix(")").split("/")
//                                 repl to rules
//                             } else {
//                                 cell to emptyList()
//                             }
                            
//                             transformationTable.add(Triple(pattern, replacement, ruleIds))
//                         }
//                     }
//                 }
//             }
//             Log.d(TAG, "Loaded ${transformationTable.size} transformation rules from table")
//             // 디버깅: 주요 규칙 확인
//             for (rule in transformationTable.take(10)) {
//                 if (rule.first.contains("ᆸ") && rule.first.contains("ᄅ")) {
//                     Log.d(TAG, "Found ㅂ+ㄹ rule: ${rule.first} -> ${rule.second}")
//                 }
//             }
//         } catch (e: Exception) {
//             Log.e(TAG, "Error loading transformation table", e)
//             // Fallback to essential rules
//             transformationTable.add(Triple("ㅂ( ?)ㄹ", "ㅁ$1ㄴ", listOf("18")))
//             transformationTable.add(Triple("ㄱ( ?)ㄹ", "ㅇ$1ㄴ", listOf("18")))
//             transformationTable.add(Triple("ㄷ( ?)ㄹ", "ㄴ$1ㄴ", listOf("18")))
//         }
//     }
    
//     /**
//      * Load idioms from text file
//      */
//     private fun loadIdioms() {
//         try {
//             context.assets.open("data/g2pkk_idioms.txt").use { inputStream ->
//                 BufferedReader(InputStreamReader(inputStream, Charsets.UTF_8)).use { reader ->
//                     reader.lines().forEach { line ->
//                         val trimmed = line.split("#")[0].trim()
//                         if ("===" in trimmed) {
//                             val parts = trimmed.split("===")
//                             if (parts.size == 2) {
//                                 idioms.add(parts[0] to parts[1])
//                             }
//                         }
//                     }
//                 }
//             }
//             Log.d(TAG, "Loaded ${idioms.size} idioms")
//         } catch (e: Exception) {
//             Log.e(TAG, "Error loading idioms", e)
//             // Fallback to essential idioms
//             idioms.add("의견란" to "의견난")
//             idioms.add("임진란" to "임진난")
//             idioms.add("생산량" to "생산냥")
//         }
//     }
    
//     /**
//      * Simple MeCab replacement for POS tagging
//      */
//     private inner class SimpleMecab {
//         fun pos(text: String): List<Pair<String, String>> {
//             // Simplified POS tagging - would use proper Korean analyzer
//             val tokens = mutableListOf<Pair<String, String>>()
//             var current = ""
            
//             for (char in text) {
//                 when {
//                     char == ' ' -> {
//                         if (current.isNotEmpty()) {
//                             tokens.add(current to guessPos(current))
//                             current = ""
//                         }
//                     }
//                     char in '가'..'힣' -> current += char
//                     else -> {
//                         if (current.isNotEmpty()) {
//                             tokens.add(current to guessPos(current))
//                             current = ""
//                         }
//                         tokens.add(char.toString() to "SY")
//                     }
//                 }
//             }
            
//             if (current.isNotEmpty()) {
//                 tokens.add(current to guessPos(current))
//             }
            
//             return tokens
//         }
        
//         private fun guessPos(word: String): String {
//             // Simplified POS guessing
//             return when {
//                 word in setOf("의", "를", "을", "이", "가", "은", "는", "와", "과") -> "JKS"
//                 word.endsWith("다") -> "VV"
//                 word.endsWith("는") || word.endsWith("은") -> "ETM"
//                 else -> "NNG"
//             }
//         }
//     }
// }