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

    guard !Self.containsNonCanonicalMacCoffeeDeclaration(before) else {
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
      && !containsNonCanonicalMacCoffeeDeclaration(contents)
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

  private static func containsNonCanonicalMacCoffeeDeclaration(_ contents: String) -> Bool {
    let managedPath = ["mcp_servers", "mac_coffee"]
    var tablePath: [String] = []
    for rawLine in contents.components(separatedBy: .newlines) {
      let line = removingComment(from: rawLine).trimmingCharacters(in: .whitespaces)
      if line.isEmpty { continue }
      if line.hasPrefix("[") && line.hasSuffix("]") {
        let isArray = line.hasPrefix("[[") && line.hasSuffix("]]")
        let startOffset = isArray ? 2 : 1
        let endOffset = isArray ? 2 : 1
        let start = line.index(line.startIndex, offsetBy: startOffset)
        let end = line.index(line.endIndex, offsetBy: -endOffset)
        guard let parsed = parseKeyPath(String(line[start..<end])) else { return true }
        tablePath = parsed
        if tablePath.starts(with: managedPath), line != tableHeader {
          return true
        }
        continue
      }
      guard let separator = assignmentSeparator(in: line) else { continue }
      guard let keyPath = parseKeyPath(String(line[..<separator])) else { return true }
      let fullPath = tablePath + keyPath
      if fullPath == ["mcp_servers"]
        || (fullPath.starts(with: managedPath) && tablePath != managedPath)
      {
        return true
      }
    }
    return false
  }

  private static func assignmentSeparator(in line: String) -> String.Index? {
    var quote: Character?
    var escaped = false
    for index in line.indices {
      let character = line[index]
      if escaped {
        escaped = false
      } else if character == "\\" && quote == "\"" {
        escaped = true
      } else if character == "\"" || character == "'" {
        if quote == character {
          quote = nil
        } else if quote == nil {
          quote = character
        }
      } else if character == "=" && quote == nil {
        return index
      }
    }
    return nil
  }

  private static func parseKeyPath(_ value: String) -> [String]? {
    var parts: [String] = []
    var current = ""
    var quote: Character?
    var escaped = false

    func appendCurrent() -> Bool {
      let key = current.trimmingCharacters(in: .whitespaces)
      guard !key.isEmpty else { return false }
      parts.append(key)
      current = ""
      return true
    }

    for character in value {
      if escaped {
        current.append(character)
        escaped = false
      } else if character == "\\" && quote == "\"" {
        escaped = true
      } else if character == "\"" || character == "'" {
        if quote == character {
          quote = nil
        } else if quote == nil {
          quote = character
        } else {
          current.append(character)
        }
      } else if character == "." && quote == nil {
        guard appendCurrent() else { return nil }
      } else {
        current.append(character)
      }
    }
    guard quote == nil, !escaped, appendCurrent() else { return nil }
    return parts
  }

  private static func isConservativelyValidTOML(_ contents: String) -> Bool {
    guard !contents.contains("\"\"\""), !contents.contains("'''") else { return false }
    var arrayDepth = 0
    var inlineTableDepth = 0
    for rawLine in contents.components(separatedBy: .newlines) {
      let line = removingComment(from: rawLine).trimmingCharacters(in: .whitespaces)
      if line.isEmpty { continue }
      if line.hasPrefix("[") && arrayDepth == 0 && inlineTableDepth == 0 {
        let isTable = (line.hasPrefix("[[") && line.hasSuffix("]]"))
          || (!line.hasPrefix("[[") && line.hasSuffix("]"))
        if !isTable { return false }
        continue
      }
      if arrayDepth == 0 && inlineTableDepth == 0 && !line.contains("=") { return false }
      var quote: Character?
      var escaped = false
      for character in line {
        if escaped {
          escaped = false
        } else if character == "\\" && quote == "\"" {
          escaped = true
        } else if character == quote {
          quote = nil
        } else if quote == nil && (character == "\"" || character == "'") {
          quote = character
        } else if quote == nil && character == "[" {
          arrayDepth += 1
        } else if quote == nil && character == "]" {
          arrayDepth -= 1
          if arrayDepth < 0 { return false }
        } else if quote == nil && character == "{" {
          inlineTableDepth += 1
        } else if quote == nil && character == "}" {
          inlineTableDepth -= 1
          if inlineTableDepth < 0 { return false }
        }
      }
      if quote != nil || escaped || inlineTableDepth != 0 { return false }
    }
    return arrayDepth == 0 && inlineTableDepth == 0
  }

  private static func removingComment(from line: String) -> String {
    var quote: Character?
    var escaped = false
    for index in line.indices {
      let character = line[index]
      if escaped {
        escaped = false
      } else if character == "\\" && quote == "\"" {
        escaped = true
      } else if character == quote {
        quote = nil
      } else if quote == nil && (character == "\"" || character == "'") {
        quote = character
      } else if character == "#" && quote == nil {
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
