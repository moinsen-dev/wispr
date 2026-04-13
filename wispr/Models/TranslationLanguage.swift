//
//  TranslationLanguage.swift
//  wispr
//
//  Target languages for automatic post-transcription translation.
//

import Foundation

/// Languages supported for automatic translation after transcription.
/// Mirrors the Whisper-supported language list for UI consistency.
enum TranslationLanguage: String, Codable, Sendable, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .dutch: return "Dutch"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .chinese: return "Chinese"
        case .russian: return "Russian"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        }
    }
}
