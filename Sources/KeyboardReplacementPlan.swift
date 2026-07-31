import Foundation

enum KeyboardReplacementStep: Equatable {
    case backspace
    case insert(String)
    case replayBoundary
}

struct KeyboardReplacementPlan {
    let steps: [KeyboardReplacementStep]

    init(correction: Correction, replayBoundary: Bool) {
        var result = Array(
            repeating: KeyboardReplacementStep.backspace,
            count: correction.original.count
        )
        result.append(.insert(correction.replacement))
        if replayBoundary {
            result.append(.replayBoundary)
        }
        steps = result
    }
}
