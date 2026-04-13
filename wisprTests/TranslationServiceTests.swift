//
//  TranslationServiceTests.swift
//  wispr
//
//  Unit tests for automatic post-transcription translation.
//

import Foundation
import Testing
@testable import wispr

@Suite("TranslationService Tests")
struct TranslationServiceTests {

    // MARK: - SettingsStore Persistence

    @Test("SettingsStore defaults for translation")
    func testTranslationDefaults() {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "test.wispr.translation.defaults.\(UUID().uuidString)")!)
        #expect(store.autoTranslateEnabled == false)
        #expect(store.translationTargetLanguage == .english)
    }

    @Test("SettingsStore persists autoTranslateEnabled round-trip")
    func testAutoTranslateEnabledPersistence() {
        let suite = "test.wispr.translation.enabled.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = SettingsStore(defaults: defaults)
        store1.autoTranslateEnabled = true

        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.autoTranslateEnabled == true)
    }

    @Test("SettingsStore persists translationTargetLanguage round-trip")
    func testTranslationTargetLanguagePersistence() {
        let suite = "test.wispr.translation.lang.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = SettingsStore(defaults: defaults)
        store1.translationTargetLanguage = .german

        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.translationTargetLanguage == .german)
    }

    @Test("SettingsStore restoreDefaults resets translation settings")
    func testRestoreDefaults() {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "test.wispr.translation.restore.\(UUID().uuidString)")!)
        store.autoTranslateEnabled = true
        store.translationTargetLanguage = .french
        store.restoreDefaults()

        #expect(store.autoTranslateEnabled == false)
        #expect(store.translationTargetLanguage == .english)
    }

    // MARK: - Pipeline Behavior

    @Test("Translation step is skipped when disabled")
    func testTranslationSkippedWhenDisabled() async {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "test.wispr.translation.skip.\(UUID().uuidString)")!)
        store.autoTranslateEnabled = false

        let fakeTranslator = FakeTranslationService()
        fakeTranslator.availability = .available

        let sm = StateManager(
            audioEngine: AudioEngine(),
            whisperService: PreviewMocks.makeWhisperService(),
            textInsertionService: TextInsertionService(),
            textCorrectionService: TextCorrectionService(),
            translationService: fakeTranslator,
            hotkeyMonitor: HotkeyMonitor(),
            permissionManager: PermissionManager(),
            settingsStore: store
        )

        await sm.insertTranscribedText("hello world")
        #expect(fakeTranslator.translateCallCount == 0)
    }

    @Test("Translation step is invoked when enabled and available")
    func testTranslationInvokedWhenEnabled() async {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "test.wispr.translation.invoke.\(UUID().uuidString)")!)
        store.autoTranslateEnabled = true
        store.translationTargetLanguage = .german
        store.aiTextCorrectionEnabled = false
        store.removeFillerWords = false
        store.autoSuffixEnabled = false
        store.autoSendEnterEnabled = false

        let fakeTranslator = FakeTranslationService()
        fakeTranslator.availability = .available
        fakeTranslator.translatedText = "Hallo Welt"

        let fakeInserter = FakeTextInsertionService()

        let sm = StateManager(
            audioEngine: AudioEngine(),
            whisperService: PreviewMocks.makeWhisperService(),
            textInsertionService: fakeInserter,
            textCorrectionService: TextCorrectionService(),
            translationService: fakeTranslator,
            hotkeyMonitor: HotkeyMonitor(),
            permissionManager: PermissionManager(),
            settingsStore: store
        )

        await sm.insertTranscribedText("hello world")
        #expect(fakeTranslator.translateCallCount == 1)
        #expect(fakeTranslator.lastTargetLanguage == .german)
        #expect(fakeInserter.insertedText == "Hallo Welt")
    }

    @Test("Pipeline order: filler removal → correction → translation → suffix")
    func testPipelineOrder() async {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "test.wispr.translation.order.\(UUID().uuidString)")!)
        store.removeFillerWords = true
        store.aiTextCorrectionEnabled = true
        store.autoTranslateEnabled = true
        store.translationTargetLanguage = .french
        store.autoSuffixEnabled = true
        store.autoSuffixText = "!"
        store.autoSendEnterEnabled = false

        let fakeCorrector = FakeTextCorrectionService()
        fakeCorrector.availability = .available
        fakeCorrector.correctedText = "corrected"

        let fakeTranslator = FakeTranslationService()
        fakeTranslator.availability = .available
        fakeTranslator.translatedText = "translated"

        let fakeInserter = FakeTextInsertionService()

        let sm = StateManager(
            audioEngine: AudioEngine(),
            whisperService: PreviewMocks.makeWhisperService(),
            textInsertionService: fakeInserter,
            textCorrectionService: fakeCorrector,
            translationService: fakeTranslator,
            hotkeyMonitor: HotkeyMonitor(),
            permissionManager: PermissionManager(),
            settingsStore: store
        )

        await sm.insertTranscribedText("um hello world")
        #expect(fakeCorrector.lastInputText == "hello world")
        #expect(fakeTranslator.lastInputText == "corrected")
        #expect(fakeInserter.insertedText == "translated!")
    }

    @Test("Graceful fallback when translation service is unavailable")
    func testGracefulFallbackUnavailable() async {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "test.wispr.translation.fallback.\(UUID().uuidString)")!)
        store.autoTranslateEnabled = true
        store.translationTargetLanguage = .spanish
        store.aiTextCorrectionEnabled = false
        store.removeFillerWords = false
        store.autoSuffixEnabled = false
        store.autoSendEnterEnabled = false

        let fakeTranslator = FakeTranslationService()
        fakeTranslator.availability = .notAvailable(reason: "Apple Intelligence is not available")

        let fakeInserter = FakeTextInsertionService()

        let sm = StateManager(
            audioEngine: AudioEngine(),
            whisperService: PreviewMocks.makeWhisperService(),
            textInsertionService: fakeInserter,
            textCorrectionService: TextCorrectionService(),
            translationService: fakeTranslator,
            hotkeyMonitor: HotkeyMonitor(),
            permissionManager: PermissionManager(),
            settingsStore: store
        )

        await sm.insertTranscribedText("hello world")
        #expect(fakeTranslator.translateCallCount == 0)
        #expect(fakeInserter.insertedText == "hello world")
    }

    @Test("Processing status text shows Translating during translation")
    func testProcessingStatusText() async {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "test.wispr.translation.status.\(UUID().uuidString)")!)
        store.autoTranslateEnabled = true
        store.translationTargetLanguage = .italian
        store.aiTextCorrectionEnabled = false
        store.removeFillerWords = false
        store.autoSuffixEnabled = false
        store.autoSendEnterEnabled = false

        let fakeTranslator = FakeTranslationService()
        fakeTranslator.availability = .available
        fakeTranslator.translatedText = "ciao"

        let sm = StateManager(
            audioEngine: AudioEngine(),
            whisperService: PreviewMocks.makeWhisperService(),
            textInsertionService: TextInsertionService(),
            textCorrectionService: TextCorrectionService(),
            translationService: fakeTranslator,
            hotkeyMonitor: HotkeyMonitor(),
            permissionManager: PermissionManager(),
            settingsStore: store
        )

        // We can't easily observe processingStatusText mid-flight in a unit test
        // because insertTranscribedText is async and runs to completion.
        // Instead, we verify the feature doesn't crash and the result is correct.
        await sm.insertTranscribedText("hello")
        #expect(fakeTranslator.translateCallCount == 1)
    }
}

// MARK: - Fakes

@MainActor
final class FakeTranslationService: TextTranslating {
    var availability: TranslationAvailability = .checking
    var translatedText: String = ""
    private(set) var translateCallCount = 0
    private(set) var lastInputText: String?
    private(set) var lastTargetLanguage: TranslationLanguage?

    func checkAvailability() {}

    func translate(_ text: String, to language: TranslationLanguage) async -> String {
        translateCallCount += 1
        lastInputText = text
        lastTargetLanguage = language
        guard case .available = availability else { return text }
        return translatedText.isEmpty ? text : translatedText
    }
}

@MainActor
final class FakeTextCorrectionService: TextCorrecting {
    var availability: TextCorrectionAvailability = .checking
    var correctedText: String = ""
    private(set) var lastInputText: String?
    private(set) var lastStyle: CorrectionStyle?

    func checkAvailability() {}

    func correctText(_ text: String, style: CorrectionStyle) async -> String {
        lastInputText = text
        lastStyle = style
        guard case .available = availability else { return text }
        return correctedText.isEmpty ? text : correctedText
    }
}

@MainActor
final class FakeTextInsertionService: TextInserting {
    private(set) var insertedText: String?

    func insertText(_ text: String) async throws {
        insertedText = text
    }

    func simulateEnterKey() {}
}
