import Foundation
import XCTest
@testable import MacCoffeeCore

final class RealIOKitIntegrationTests: XCTestCase {
    func testSystemDisplayAndOffAppearInPMSetAssertions() throws {
        let manager = IOKitPowerAssertionManager()
        defer { manager.releaseAll() }

        try manager.transition(to: .system)
        var output = try powerAssertionOutput()
        XCTAssertTrue(output.contains("PreventUserIdleSystemSleep"))
        XCTAssertTrue(output.contains("Mac Coffee active wake session"))

        try manager.transition(to: .display)
        output = try powerAssertionOutput()
        XCTAssertTrue(output.contains("PreventUserIdleDisplaySleep"))
        XCTAssertTrue(output.contains("Mac Coffee active wake session"))

        try manager.transition(to: .off)
        output = try powerAssertionOutput()
        XCTAssertFalse(output.contains("Mac Coffee active wake session"))
    }

    private func powerAssertionOutput() throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "assertions"]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        XCTAssertEqual(process.terminationStatus, 0)
        return String(decoding: data, as: UTF8.self)
    }
}
