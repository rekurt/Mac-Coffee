import Foundation

struct CodexConfigurationPlanner {
  static let tableHeader = "[mcp_servers.mac_coffee]"

  func plan(
    configurationURL: URL = defaultConfigurationURL,
    helperURL: URL,
    existingContents: String? = nil
  ) throws -> ConfigurationChangePlan {
    let (targetExisted, before) = try MCPConfigurationPlanning.readExistingContents(
      at: configurationURL,
      provided: existingContents
    )
    let manualInstructions = Self.managedBlock(helperURL: helperURL)

    guard Self.isConservativelyValidTOML(before) else {
      return manualPlan(
        configurationURL: configurationURL,
        helperURL: helperURL,
        targetExisted: targetExisted,
        before: before,
        instructions: manualInstructions
      )
    }

    let matchingHeaders = before.components(separatedBy: .newlines)
      .filter { $0.trimmingCharacters(in: .whitespaces) == Self.tableHeader }
    if !matchingHeaders.isEmpty {
      guard matchingHeaders.count == 1,
        Self.containsMatchingManagedEntry(contents: before, helperURL: helperURL)
      else {
        return manualPlan(
          configurationURL: configurationURL,
          helperURL: helperURL,
          targetExisted: targetExisted,
          before: before,
          instructions: manualInstructions
        )
      }
      return ConfigurationChangePlan(
        clientKind: .codex,
        configurationURL: configurationURL,
        helperURL: helperURL,
        targetExisted: targetExisted,
        before: before,
        after: before,
        proposedDiff: "",
        disposition: .unchanged,
        validation: .valid,
        manualInstructions: manualInstructions
      )
    }

    var after = before
    if !after.isEmpty {
      if !after.hasSuffix("\n") { after.append("\n") }
      after.append("\n")
    }
    after.append(manualInstructions)
    let validation: ConfigurationValidation = Self.validate(contents: after, helperURL: helperURL)
      ? .valid
      : .invalid
    return ConfigurationChangePlan(
      clientKind: .codex,
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
      manualInstructions: manualInstructions
    )
  }

  static func validate(contents: String, helperURL: URL) -> Bool {
    isConservativelyValidTOML(contents)
      && containsMatchingManagedEntry(contents: contents, helperURL: helperURL)
  }

  private static var defaultConfigurationURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex", isDirectory: true)
      .appendingPathComponent("config.toml")
  }

  private static func managedBlock(helperURL: URL) -> String {
    """
    \(tableHeader)
    command = "\(tomlEscaped(helperURL.standardizedFileURL.path))"
    """ + "\n"
  }

  private static func tomlEscaped(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }

  private static func containsMatchingManagedEntry(contents: String, helperURL: URL) -> Bool {
    let lines = contents.components(separatedBy: .newlines)
    guard let start = lines.firstIndex(where: {
      $0.trimmingCharacters(in: .whitespaces) == tableHeader
    }) else { return false }
    let end = lines[(start + 1)...].firstIndex(where: {
      $0.trimmingCharacters(in: .whitespaces).hasPrefix("[")
    }) ?? lines.endIndex
    let expected = "\"\(tomlEscaped(helperURL.standardizedFileURL.path))\""
    return lines[(start + 1)..<end].contains { line in
      let content = removingComment(from: line).trimmingCharacters(in: .whitespaces)
      guard let separator = content.firstIndex(of: "=") else { return false }
      let key = content[..<separator].trimmingCharacters(in: .whitespaces)
      let value = content[content.index(after: separator)...].trimmingCharacters(in: .whitespaces)
      return key == "command" && value == expected
    }
  }

  private static func isConservativelyValidTOML(_ contents: String) -> Bool {
    guard !contents.contains("\"\"\""), !contents.contains("'''") else { return false }
    var arrayDepth = 0
    for rawLine in contents.components(separatedBy: .newlines) {
      let line = removingComment(from: rawLine).trimmingCharacters(in: .whitespaces)
      if line.isEmpty { continue }
      if line.hasPrefix("[") && arrayDepth == 0 {
        let isTable = (line.hasPrefix("[[") && line.hasSuffix("]]"))
          || (!line.hasPrefix("[[") && line.hasSuffix("]"))
        if !isTable { return false }
        continue
      }
      if arrayDepth == 0 && !line.contains("=") { return false }
      var inString = false
      var escaped = false
      for character in line {
        if escaped {
          escaped = false
        } else if character == "\\" && inString {
          escaped = true
        } else if character == "\"" {
          inString.toggle()
        } else if !inString && character == "[" {
          arrayDepth += 1
        } else if !inString && character == "]" {
          arrayDepth -= 1
          if arrayDepth < 0 { return false }
        }
      }
      if inString { return false }
    }
    return arrayDepth == 0
  }

  private static func removingComment(from line: String) -> String {
    var inString = false
    var escaped = false
    for index in line.indices {
      let character = line[index]
      if escaped {
        escaped = false
      } else if character == "\\" && inString {
        escaped = true
      } else if character == "\"" {
        inString.toggle()
      } else if character == "#" && !inString {
        return String(line[..<index])
      }
    }
    return line
  }

  private func manualPlan(
    configurationURL: URL,
    helperURL: URL,
    targetExisted: Bool,
    before: String,
    instructions: String
  ) -> ConfigurationChangePlan {
    ConfigurationChangePlan(
      clientKind: .codex,
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
