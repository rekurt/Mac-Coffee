import SwiftUI

public struct CountdownText: View {
    private let deadline: Date?
    @State private var now = Date()

    public init(deadline: Date?) {
        self.deadline = deadline
    }

    public var body: some View {
        Group {
            if let deadline {
                Text(verbatim: remainingText(until: deadline))
            } else {
                Text("duration.indefinite.long")
            }
        }
        .monospacedDigit()
        .accessibilityIdentifier("maccoffee.session.countdown")
        .task(id: deadline) {
            guard let deadline else { return }
            while !Task.isCancelled {
                now = Date()
                let remaining = deadline.timeIntervalSince(now)
                if remaining <= 0 { return }
                let cadence = remaining <= 60 ? 1.0 : min(60.0, remaining - 60.0)
                try? await Task<Never, Never>.sleep(for: .seconds(max(1, cadence)))
            }
        }
    }

    private func remainingText(until deadline: Date) -> String {
        let total = max(0, Int(ceil(deadline.timeIntervalSince(now))))
        let formatted: String
        if total >= 3_600 {
            formatted = "\(total / 3_600)h \((total % 3_600) / 60)m"
        } else if total > 60 {
            formatted = "\(total / 60)m"
        } else {
            formatted = "\(total)s"
        }
        return String(
            format: String(localized: "status.remaining", bundle: .main),
            formatted
        )
    }
}
