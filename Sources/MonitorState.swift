import Foundation

enum MonitorState: Equatable {
    case needsPermission
    case paused
    case failed
    case ready

    static func resolve(enabled: Bool, trusted: Bool, running: Bool) -> MonitorState {
        guard trusted else { return .needsPermission }
        guard enabled else { return .paused }
        return running ? .ready : .failed
    }

    var title: String {
        switch self {
        case .needsPermission: return "Требуется доступ"
        case .paused: return "Исправление на паузе"
        case .failed: return "Исправление не запустилось"
        case .ready: return "Исправление включено"
        }
    }

    var detail: String {
        switch self {
        case .needsPermission:
            return "Разрешите Универсальный доступ в настройках macOS."
        case .paused:
            return "Включите исправление раскладки, когда оно понадобится."
        case .failed:
            return "Доступ есть, но исправление не работает. Повторите запуск или перезапустите KeySwitch."
        case .ready:
            return "Слова исправляются после пробела. В выбранных приложениях текст не меняется."
        }
    }
}

/// Bounds retries without invoking callbacks recursively. Five automatic attempts
/// per authorization period; the user can explicitly request a new attempt.
struct MonitorRetryPolicy {
    private(set) var failures = 0
    private(set) var nextAttempt: TimeInterval = 0

    func allowsAttempt(at time: TimeInterval) -> Bool {
        failures < 5 && time >= nextAttempt
    }

    mutating func recordFailure(at time: TimeInterval) {
        failures += 1
        nextAttempt = time + min(pow(2, Double(failures)), 30)
    }

    mutating func reset() {
        failures = 0
        nextAttempt = 0
    }
}

/// UTF-16 offsets match AXSelectedTextRange. A replacement is allowed only at
/// the original caret with an exact, unselected suffix in the same field.
struct VerifiedTextSuffix {
    let text: String
    let caret: Int

    var range: NSRange? {
        let length = text.utf16.count
        guard !text.isEmpty, caret >= length else { return nil }
        return NSRange(location: caret - length, length: length)
    }

    func matches(selection: NSRange, actual: String?) -> Bool {
        range != nil && selection.length == 0 && selection.location == caret && actual == text
    }
}
