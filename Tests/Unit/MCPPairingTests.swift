import Foundation
import XCTest
@testable import MacCoffeeCore

@MainActor
final class MCPPairingTests: XCTestCase {
    func testEveryConnectionGetsAFreshNonceAndTranscript() throws {
        let harness = makeHarness(nonces: [Data(repeating: 1, count: 32), Data(repeating: 2, count: 32)])
        let presentation = makePresentation()

        let first = try harness.coordinator.beginAuthentication(
            presentation,
            connectionIdentifier: "connection-1"
        )
        let second = try harness.coordinator.beginAuthentication(
            presentation,
            connectionIdentifier: "connection-2"
        )

        XCTAssertNotEqual(first.identifier, second.identifier)
        XCTAssertNotEqual(first.nonce, second.nonce)
        XCTAssertNotEqual(first.transcript, second.transcript)
        XCTAssertEqual(first.nonce.count, 32)
        XCTAssertEqual(second.nonce.count, 32)
    }

    func testRepeatedNonceIsRejectedInsteadOfReused() throws {
        let repeated = Data(repeating: 7, count: 32)
        let harness = makeHarness(nonces: [repeated, repeated])
        let presentation = makePresentation()
        _ = try harness.coordinator.beginAuthentication(
            presentation,
            connectionIdentifier: "connection-1"
        )

        XCTAssertThrowsError(
            try harness.coordinator.beginAuthentication(
                presentation,
                connectionIdentifier: "connection-2"
            )
        ) { error in
            XCTAssertEqual(error as? MCPPairingCoordinatorError, .nonceReuseDetected)
        }
    }

    func testValidProofCreatesPendingRequestAndApprovalPersistsTrust() throws {
        let harness = makeHarness()
        let presentation = makePresentation()
        let challenge = try harness.coordinator.beginAuthentication(
            presentation,
            connectionIdentifier: "connection-1"
        )
        harness.verifier.acceptedMessage = challenge.transcript
        harness.verifier.acceptedSignature = Data([9, 8, 7])

        let result = try harness.coordinator.completeAuthentication(
            MCPAuthenticationProof(
                challengeIdentifier: challenge.identifier,
                signature: Data([9, 8, 7])
            )
        )
        let request = try approvalRequest(from: result)

        XCTAssertEqual(request.reason, .firstPairing)
        XCTAssertEqual(request.presentation, presentation)
        XCTAssertFalse(request.requiresUnverifiedApprovalWarning)
        XCTAssertEqual(harness.coordinator.pendingRequests, [request])
        XCTAssertTrue(try harness.trustStore.clients().isEmpty)

        let approved = try harness.coordinator.approve(requestIdentifier: request.identifier)
        XCTAssertEqual(approved.identifier, presentation.clientIdentifier)
        XCTAssertEqual(approved.publicKey, presentation.publicKey)
        XCTAssertEqual(approved.codeIdentity, presentation.parentIdentity)
        XCTAssertEqual(approved.createdAt, harness.now)
        XCTAssertEqual(approved.lastSeenAt, harness.now)
        XCTAssertFalse(approved.isRevoked)
        XCTAssertEqual(try harness.trustStore.clients(), [approved])
        XCTAssertTrue(harness.coordinator.pendingRequests.isEmpty)
    }

    func testInvalidSignatureConsumesChallengeAndReplayIsRejected() throws {
        let harness = makeHarness()
        let challenge = try harness.coordinator.beginAuthentication(
            makePresentation(),
            connectionIdentifier: "connection-1"
        )
        let proof = MCPAuthenticationProof(
            challengeIdentifier: challenge.identifier,
            signature: Data([0])
        )

        XCTAssertThrowsError(try harness.coordinator.completeAuthentication(proof)) { error in
            XCTAssertEqual(error as? MCPPairingCoordinatorError, .invalidSignature)
        }
        XCTAssertThrowsError(try harness.coordinator.completeAuthentication(proof)) { error in
            XCTAssertEqual(error as? MCPPairingCoordinatorError, .replayedChallenge)
        }
        XCTAssertTrue(harness.coordinator.pendingRequests.isEmpty)
    }

    func testSignatureIsBoundToExactConnectionTranscript() throws {
        let harness = makeHarness(nonces: [Data(repeating: 1, count: 32), Data(repeating: 2, count: 32)])
        let presentation = makePresentation()
        let first = try harness.coordinator.beginAuthentication(
            presentation,
            connectionIdentifier: "connection-1"
        )
        let second = try harness.coordinator.beginAuthentication(
            presentation,
            connectionIdentifier: "connection-2"
        )
        harness.verifier.acceptedMessage = first.transcript
        harness.verifier.acceptedSignature = Data([5])

        XCTAssertThrowsError(
            try harness.coordinator.completeAuthentication(
                MCPAuthenticationProof(
                    challengeIdentifier: second.identifier,
                    signature: Data([5])
                )
            )
        ) { error in
            XCTAssertEqual(error as? MCPPairingCoordinatorError, .invalidSignature)
        }
    }

    func testTranscriptBindsClientKeyMetadataAndVerifiedParentIdentity() throws {
        let nonce = Data(repeating: 4, count: 32)
        let original = makePresentation()
        let baseline = try MCPAuthenticationTranscript.make(
            challengeIdentifier: "challenge",
            connectionIdentifier: "connection",
            nonce: nonce,
            presentation: original
        )
        let changedKey = MCPAuthenticationPresentation(
            clientIdentifier: original.clientIdentifier,
            displayName: original.displayName,
            publicKey: Data(repeating: 9, count: 65),
            parentIdentity: original.parentIdentity
        )
        let changedParent = MCPAuthenticationPresentation(
            clientIdentifier: original.clientIdentifier,
            displayName: original.displayName,
            publicKey: original.publicKey,
            parentIdentity: makeIdentity(
                executablePath: "/Applications/Other.app/Contents/MacOS/Other",
                teamIdentifier: "OTHERTEAM",
                signingIdentifier: "com.example.other",
                hash: "other-hash"
            )
        )

        XCTAssertNotEqual(
            baseline,
            try MCPAuthenticationTranscript.make(
                challengeIdentifier: "challenge",
                connectionIdentifier: "connection",
                nonce: nonce,
                presentation: changedKey
            )
        )
        XCTAssertNotEqual(
            baseline,
            try MCPAuthenticationTranscript.make(
                challengeIdentifier: "challenge",
                connectionIdentifier: "connection",
                nonce: nonce,
                presentation: changedParent
            )
        )
    }

    func testApprovedClientAuthenticatesAndUpdatesLastSeen() throws {
        let harness = makeHarness()
        let presentation = makePresentation()
        let trusted = MCPTrustedClient(
            identifier: presentation.clientIdentifier,
            displayName: presentation.displayName,
            publicKey: presentation.publicKey,
            codeIdentity: presentation.parentIdentity,
            createdAt: Date(timeIntervalSince1970: 1_000),
            lastSeenAt: nil,
            revokedAt: nil
        )
        try harness.trustStore.trust(trusted)
        let challenge = try harness.coordinator.beginAuthentication(
            presentation,
            connectionIdentifier: "connection-1"
        )
        harness.verifier.acceptedMessage = challenge.transcript
        harness.verifier.acceptedSignature = Data([1, 2, 3])

        let result = try harness.coordinator.completeAuthentication(
            MCPAuthenticationProof(
                challengeIdentifier: challenge.identifier,
                signature: Data([1, 2, 3])
            )
        )

        guard case let .authenticated(client) = result else {
            return XCTFail("Expected authenticated result")
        }
        XCTAssertEqual(client.lastSeenAt, harness.now)
        XCTAssertEqual(try harness.trustStore.client(identifier: client.identifier)?.lastSeenAt, harness.now)
        XCTAssertTrue(harness.coordinator.pendingRequests.isEmpty)
    }

    func testMaterialParentIdentityChangeRequiresExplicitReapproval() throws {
        let harness = makeHarness()
        let original = makePresentation()
        try harness.trustStore.trust(
            MCPTrustedClient(
                identifier: original.clientIdentifier,
                displayName: original.displayName,
                publicKey: original.publicKey,
                codeIdentity: original.parentIdentity,
                createdAt: Date(timeIntervalSince1970: 1_000),
                lastSeenAt: nil,
                revokedAt: nil
            )
        )
        let changed = MCPAuthenticationPresentation(
            clientIdentifier: original.clientIdentifier,
            displayName: original.displayName,
            publicKey: original.publicKey,
            parentIdentity: makeIdentity(
                executablePath: "/Applications/Other.app/Contents/MacOS/Other",
                teamIdentifier: "OTHERTEAM",
                signingIdentifier: "com.example.other",
                hash: "different"
            )
        )
        let challenge = try harness.coordinator.beginAuthentication(
            changed,
            connectionIdentifier: "connection-1"
        )
        harness.verifier.acceptedMessage = challenge.transcript
        harness.verifier.acceptedSignature = Data([4])

        let result = try harness.coordinator.completeAuthentication(
            MCPAuthenticationProof(challengeIdentifier: challenge.identifier, signature: Data([4]))
        )
        let request = try approvalRequest(from: result)

        XCTAssertEqual(request.reason, .identityChanged)
        XCTAssertEqual(request.previousIdentity, original.parentIdentity)
        XCTAssertEqual(
            try harness.trustStore.client(identifier: original.clientIdentifier)?.codeIdentity,
            original.parentIdentity
        )
    }

    func testSignedAppUpdateWithSameDesignatedIdentityDoesNotRequireReapproval() throws {
        let harness = makeHarness()
        let original = makePresentation()
        try harness.trustStore.trust(
            MCPTrustedClient(
                identifier: original.clientIdentifier,
                displayName: original.displayName,
                publicKey: original.publicKey,
                codeIdentity: original.parentIdentity,
                createdAt: Date(timeIntervalSince1970: 1_000),
                lastSeenAt: nil,
                revokedAt: nil
            )
        )
        let updated = MCPAuthenticationPresentation(
            clientIdentifier: original.clientIdentifier,
            displayName: original.displayName,
            publicKey: original.publicKey,
            parentIdentity: makeIdentity(hash: "new-release-cdhash")
        )
        let challenge = try harness.coordinator.beginAuthentication(
            updated,
            connectionIdentifier: "connection-1"
        )
        harness.verifier.acceptedMessage = challenge.transcript
        harness.verifier.acceptedSignature = Data([4])

        let result = try harness.coordinator.completeAuthentication(
            MCPAuthenticationProof(challengeIdentifier: challenge.identifier, signature: Data([4]))
        )

        guard case .authenticated = result else {
            return XCTFail("Same Team ID and signing identifier should remain trusted")
        }
    }

    func testUnsignedClientShowsWarningAndBindsPathAndFileHash() throws {
        let harness = makeHarness()
        let unsigned = MCPAuthenticationPresentation(
            clientIdentifier: "local-script",
            displayName: "Local client",
            publicKey: Data(repeating: 3, count: 65),
            parentIdentity: MCPCodeIdentity(
                executablePath: "/Users/test/bin/local-client",
                bundleIdentifier: nil,
                teamIdentifier: nil,
                signingIdentifier: nil,
                codeDirectoryHash: "file-sha256",
                isSigned: false
            )
        )
        let challenge = try harness.coordinator.beginAuthentication(
            unsigned,
            connectionIdentifier: "connection-1"
        )
        harness.verifier.acceptedMessage = challenge.transcript
        harness.verifier.acceptedSignature = Data([8])

        let result = try harness.coordinator.completeAuthentication(
            MCPAuthenticationProof(challengeIdentifier: challenge.identifier, signature: Data([8]))
        )
        let request = try approvalRequest(from: result)

        XCTAssertTrue(request.requiresUnverifiedApprovalWarning)
        XCTAssertEqual(request.presentation.parentIdentity.executablePath, "/Users/test/bin/local-client")
        XCTAssertEqual(request.presentation.parentIdentity.codeDirectoryHash, "file-sha256")
    }

    func testRevokedClientIsRejectedAndCannotSilentlyPairAgain() throws {
        let harness = makeHarness()
        let presentation = makePresentation()
        try harness.trustStore.trust(
            MCPTrustedClient(
                identifier: presentation.clientIdentifier,
                displayName: presentation.displayName,
                publicKey: presentation.publicKey,
                codeIdentity: presentation.parentIdentity,
                createdAt: Date(timeIntervalSince1970: 1_000),
                lastSeenAt: nil,
                revokedAt: Date(timeIntervalSince1970: 2_000)
            )
        )
        let challenge = try harness.coordinator.beginAuthentication(
            presentation,
            connectionIdentifier: "connection-1"
        )
        harness.verifier.acceptedMessage = challenge.transcript
        harness.verifier.acceptedSignature = Data([6])

        XCTAssertThrowsError(
            try harness.coordinator.completeAuthentication(
                MCPAuthenticationProof(challengeIdentifier: challenge.identifier, signature: Data([6]))
            )
        ) { error in
            XCTAssertEqual(error as? MCPPairingCoordinatorError, .clientRevoked)
        }
        XCTAssertTrue(harness.coordinator.pendingRequests.isEmpty)
    }

    func testRejectRemovesPendingRequestWithoutWritingTrust() throws {
        let harness = makeHarness()
        let challenge = try harness.coordinator.beginAuthentication(
            makePresentation(),
            connectionIdentifier: "connection-1"
        )
        harness.verifier.acceptedMessage = challenge.transcript
        harness.verifier.acceptedSignature = Data([3])
        let result = try harness.coordinator.completeAuthentication(
            MCPAuthenticationProof(challengeIdentifier: challenge.identifier, signature: Data([3]))
        )
        let request = try approvalRequest(from: result)

        XCTAssertTrue(harness.coordinator.reject(requestIdentifier: request.identifier))
        XCTAssertFalse(harness.coordinator.reject(requestIdentifier: request.identifier))
        XCTAssertTrue(harness.coordinator.pendingRequests.isEmpty)
        XCTAssertTrue(try harness.trustStore.clients().isEmpty)
    }

    private func approvalRequest(
        from result: MCPAuthenticationResult
    ) throws -> MCPPairingRequest {
        guard case let .approvalRequired(request) = result else {
            XCTFail("Expected approval-required result")
            throw MCPPairingTestError.unexpectedResult
        }
        return request
    }

    private func makeHarness(
        nonces: [Data] = [Data(repeating: 1, count: 32)]
    ) -> MCPPairingHarness {
        let credentials = FakeMCPCredentialStore()
        let trustStore = MCPTrustStore(credentials: credentials)
        let nonceGenerator = SequenceNonceGenerator(nonces: nonces)
        let verifier = RecordingSignatureVerifier()
        return MCPPairingHarness(
            trustStore: trustStore,
            nonceGenerator: nonceGenerator,
            verifier: verifier,
            now: Date(timeIntervalSince1970: 10_000)
        )
    }

    private func makePresentation() -> MCPAuthenticationPresentation {
        MCPAuthenticationPresentation(
            clientIdentifier: "codex-client",
            displayName: "Codex",
            publicKey: Data(repeating: 2, count: 65),
            parentIdentity: makeIdentity()
        )
    }

    private func makeIdentity(
        executablePath: String = "/Applications/Codex.app/Contents/MacOS/Codex",
        teamIdentifier: String = "OPENAI",
        signingIdentifier: String = "com.openai.codex",
        hash: String = "release-cdhash"
    ) -> MCPCodeIdentity {
        MCPCodeIdentity(
            executablePath: executablePath,
            bundleIdentifier: "com.openai.codex",
            teamIdentifier: teamIdentifier,
            signingIdentifier: signingIdentifier,
            codeDirectoryHash: hash,
            isSigned: true
        )
    }
}

private enum MCPPairingTestError: Error {
    case unexpectedResult
}

@MainActor
private struct MCPPairingHarness {
    let trustStore: MCPTrustStore
    let nonceGenerator: SequenceNonceGenerator
    let verifier: RecordingSignatureVerifier
    let now: Date
    let coordinator: MCPPairingCoordinator

    init(
        trustStore: MCPTrustStore,
        nonceGenerator: SequenceNonceGenerator,
        verifier: RecordingSignatureVerifier,
        now: Date
    ) {
        self.trustStore = trustStore
        self.nonceGenerator = nonceGenerator
        self.verifier = verifier
        self.now = now
        coordinator = MCPPairingCoordinator(
            trustStore: trustStore,
            nonceGenerator: nonceGenerator,
            signatureVerifier: verifier,
            now: { now }
        )
    }
}

private final class SequenceNonceGenerator: MCPNonceGenerating {
    private var nonces: [Data]

    init(nonces: [Data]) {
        self.nonces = nonces
    }

    func nextNonce(byteCount: Int) throws -> Data {
        guard !nonces.isEmpty else { throw MCPPairingTestError.unexpectedResult }
        return nonces.removeFirst()
    }
}

private final class RecordingSignatureVerifier: MCPSignatureVerifying {
    var acceptedMessage: Data?
    var acceptedSignature: Data?

    func verify(signature: Data, message: Data, publicKey: Data) -> Bool {
        signature == acceptedSignature && message == acceptedMessage
    }
}
