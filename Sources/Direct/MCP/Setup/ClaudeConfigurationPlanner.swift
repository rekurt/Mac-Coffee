import Foundation

struct ClaudeConfigurationPlanner {
  static let serverKey = "mac-coffee"

  func plan(
    configurationURL: URL = defaultConfigurationURL,
    helperURL: URL,
    existingContents: String? = nil
  ) throws -> ConfigurationChangePlan {
    let (targetExisted, before) = try MCPConfigurationPlanning.readExistingContents(
      at: configurationURL,
      provided: existingContents
    )
    let instructions = Self.manualInstructions(helperURL: helperURL)
    guard !Self.hasDuplicateManagedKeys(before), var root = Self.parseRoot(before) else {
      return manualPlan(
        configurationURL: configurationURL,
        helperURL: helperURL,
        targetExisted: targetExisted,
        before: before,
        instructions: instructions
      )
    }

    var servers = root["mcpServers"] as? [String: Any] ?? [:]
    if let existingValue = servers[Self.serverKey] {
      guard let existing = existingValue as? [String: Any],
        Self.matches(server: existing, helperURL: helperURL)
      else {
        return manualPlan(
          configurationURL: configurationURL,
          helperURL: helperURL,
          targetExisted: targetExisted,
          before: before,
          instructions: instructions
        )
      }
      return ConfigurationChangePlan(
        clientKind: .claudeDesktop,
        configurationURL: configurationURL,
        helperURL: helperURL,
        targetExisted: targetExisted,
        before: before,
        after: before,
        proposedDiff: "",
        disposition: .unchanged,
        validation: .valid,
        manualInstructions: instructions
      )
    }

    servers[Self.serverKey] = [
      "command": helperURL.standardizedFileURL.path,
      "args": [String](),
    ]
    root["mcpServers"] = servers
    let data = try JSONSerialization.data(
      withJSONObject: root,
      options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    let after = String(decoding: data, as: UTF8.self) + "\n"
    let validation: ConfigurationValidation = Self.validate(contents: after, helperURL: helperURL)
      ? .valid
      : .invalid
    return ConfigurationChangePlan(
      clientKind: .claudeDesktop,
      configurationURL: configurationURL,
      helperURL: helperURL,
      targetExisted: targetExisted,
      before: before,
      after: after,
      proposedDiff: MCPConfigurationPlanning.unifiedDiff(
        before: before,
        after: after,
        path: configurationURL.path
      ),
      disposition: validation == .valid ? .installable : .manual,
      validation: validation,
      manualInstructions: instructions
    )
  }

  static func validate(contents: String, helperURL: URL) -> Bool {
    guard !hasDuplicateManagedKeys(contents),
      let root = parseRoot(contents),
      let servers = root["mcpServers"] as? [String: Any],
      let server = servers[serverKey] as? [String: Any]
    else { return false }
    return matches(server: server, helperURL: helperURL)
  }

  private static var defaultConfigurationURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/Claude", isDirectory: true)
      .appendingPathComponent("claude_desktop_config.json")
  }

  private static func parseRoot(_ contents: String) -> [String: Any]? {
    if contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [:] }
    guard let data = contents.data(using: .utf8),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    if let value = root["mcpServers"], !(value is [String: Any]) { return nil }
    return root
  }

  private static func hasDuplicateManagedKeys(_ contents: String) -> Bool {
    guard let regex = try? NSRegularExpression(
      pattern: "\\\"mac-coffee\\\"\\s*:",
      options: []
    ) else { return true }
    let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
    return regex.numberOfMatches(in: contents, range: range) > 1
  }

  private static func matches(server: [String: Any], helperURL: URL) -> Bool {
    guard server["command"] as? String == helperURL.standardizedFileURL.path else { return false }
    if let args = server["args"] as? [Any] { return args.isEmpty }
    return true
  }

  private static func manualInstructions(helperURL: URL) -> String {
    let object: [String: Any] = [
      "mcpServers": [
        serverKey: [
          "command": helperURL.standardizedFileURL.path,
          "args": [String](),
        ]
      ]
    ]
    guard let data = try? JSONSerialization.data(
      withJSONObject: object,
      options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    ) else { return helperURL.standardizedFileURL.path }
    return String(decoding: data, as: UTF8.self)
  }

  private func manualPlan(
    configurationURL: URL,
    helperURL: URL,
    targetExisted: Bool,
    before: String,
    instructions: String
  ) -> ConfigurationChangePlan {
    ConfigurationChangePlan(
      clientKind: .claudeDesktop,
      configurationURL: configurationURL,
      helperURL: helperURL,
      targetExisted: targetExisted,
      before: before,
      after: nil,
      proposedDiff: "",
      disposition: .manual,
      validation: .invalid,
      manualInstructions: instructions
    )
  }
}
