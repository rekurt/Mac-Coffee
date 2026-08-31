import Darwin
import Foundation
import MacCoffeeCore

public enum ParentProcessIdentityError: Error, Equatable {
    case invalidProcessIdentifier
    case executablePathUnavailable
}

public enum ParentProcessIdentity {
    private static let processPathBufferSize = 4_096

    public static func capture(
        processIdentifier: pid_t = getppid(),
        verifier: MCPExecutableIdentityVerifying = SecurityClientIdentityVerifier()
    ) throws -> MCPCodeIdentity {
        guard processIdentifier > 0 else {
            throw ParentProcessIdentityError.invalidProcessIdentifier
        }
        var buffer = [CChar](repeating: 0, count: processPathBufferSize)
        let length = proc_pidpath(
            processIdentifier,
            &buffer,
            UInt32(buffer.count)
        )
        guard length > 0 else {
            throw ParentProcessIdentityError.executablePathUnavailable
        }
        let path = String(cString: buffer)
        return try verifier.identity(forExecutableAt: path)
    }
}
