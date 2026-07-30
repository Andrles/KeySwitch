import Foundation

enum PreferenceKey {
    static let enabled = "enabled"
    static let playSound = "playSound"
    static let launchAtLogin = "launchAtLogin"
    static let excludedApps = "excludedApps"
    static let ignoredWords = "ignoredWords"
    static let correctionCount = "correctionCount"
    static let primaryLanguage = "primaryLanguage"
    static let spellChecking = "spellChecking"
    static let spellAutoCorrect = "spellAutoCorrect"
}

final class Preferences {
    static let shared = Preferences()
    let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            PreferenceKey.enabled: true,
            PreferenceKey.playSound: true,
            PreferenceKey.excludedApps: [
                "com.apple.dt.Xcode",
                "com.microsoft.VSCode",
                "com.jetbrains.intellij",
                "com.jetbrains.AppCode",
                "com.unity3d.UnityEditor5.x"
            ],
            PreferenceKey.ignoredWords: [],
            PreferenceKey.primaryLanguage: Language.russian.rawValue,
            PreferenceKey.spellChecking: true,
            PreferenceKey.spellAutoCorrect: false
        ])
    }

    var enabled: Bool {
        get { defaults.bool(forKey: PreferenceKey.enabled) }
        set { defaults.set(newValue, forKey: PreferenceKey.enabled) }
    }

    var playSound: Bool {
        get { defaults.bool(forKey: PreferenceKey.playSound) }
        set { defaults.set(newValue, forKey: PreferenceKey.playSound) }
    }

    var excludedApps: [String] {
        get { defaults.stringArray(forKey: PreferenceKey.excludedApps) ?? [] }
        set { defaults.set(newValue, forKey: PreferenceKey.excludedApps) }
    }

    var ignoredWords: Set<String> {
        get { Set(defaults.stringArray(forKey: PreferenceKey.ignoredWords) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: PreferenceKey.ignoredWords) }
    }

    var correctionCount: Int {
        get { defaults.integer(forKey: PreferenceKey.correctionCount) }
        set { defaults.set(newValue, forKey: PreferenceKey.correctionCount) }
    }

    var primaryLanguage: Language {
        get {
            Language(rawValue: defaults.string(forKey: PreferenceKey.primaryLanguage) ?? "")
                ?? .russian
        }
        set { defaults.set(newValue.rawValue, forKey: PreferenceKey.primaryLanguage) }
    }

    var spellChecking: Bool {
        get { defaults.bool(forKey: PreferenceKey.spellChecking) }
        set { defaults.set(newValue, forKey: PreferenceKey.spellChecking) }
    }

    var spellAutoCorrect: Bool {
        get { defaults.bool(forKey: PreferenceKey.spellAutoCorrect) }
        set { defaults.set(newValue, forKey: PreferenceKey.spellAutoCorrect) }
    }
}
