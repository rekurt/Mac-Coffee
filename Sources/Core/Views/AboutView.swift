import SwiftUI

public struct AboutView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("about.title")
                .font(.title2.bold())
            Text(versionText)
                .foregroundStyle(.secondary)
            Text("about.description")
                .multilineTextAlignment(.center)
            Text("about.privacy")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("about.limitations")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 380)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
