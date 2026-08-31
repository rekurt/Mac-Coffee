import Combine
import Foundation

@MainActor
public final class MCPPairingCoordinator: ObservableObject {
    @Published public private(set) var pendingRequests: [MCPPairingRequest] = []

    private struct ChallengeContext {
        let challenge: MCPAuthenticationChallenge
        let presentation: MCPAuthenticationPresentation
    }

    private static let nonceByteCount = 32
    private static let replayCacheCapacity = 1_024

    private let trustStore: MCPTrustStore
    private let nonceGenerator: MCPNonceGenerating
    private let signatureVerifier: MCPSignatureVerifying
    private let now: () -> Date
    private var challenges: [String: ChallengeContext] = [:]
    private var usedNonces: Set<Data> = []
    private var consumedChallengeIdentifiers: Set<String> = []
    private var consumedChallengeOrder: [String] = []

    public init(
        trustStore: MCPTrustStore,
        nonceGenerator: MCPNonceGenerating,
        signatureVerifier: MCPSignatureVerifying,
        now: @escaping () -> Date = Date.init
    ) {
        self.trustStore = trustStore
        self.nonceGenerator = nonceGenerator
        self.signatureVerifier = signatureVerifier
        self.now = now
    }

    public func beginAuthentication(
        _ presentation: MCPAuthenticationPresentation,
        connectionIdentifier: String
    ) throws -> MCPAuthenticationChallenge {
        guard isValid(presentation), isValidIdentifier(connectionIdentifier) else {
            throw MCPPairingCoordinatorError.invalidPresentation
        }

        let nonce = try nonceGenerator.nextNonce(byteCount: Self.nonceByteCount)
        guard nonce.count == Self.nonceByteCount else {
            throw MCPPairingCoordinatorError.invalidNonce
        }
        guard usedNonces.insert(nonce).inserted else {
            throw MCPPairingCoordinatorError.nonceReuseDetected
        }

        let challengeIdentifier = UUID().uuidString.lowercased()
        let transcript = try MCPAuthenticationTranscript.make(
            challengeIdentifier: challengeIdentifier,
            connectionIdentifier: connectionIdentifier,
            nonce: nonce,
            presentation: presentation
        )
        let challenge = MCPAuthenticationChallenge(
            identifier: challengeIdentifier,
            connectionIdentifier: connectionIdentifier,
            nonce: nonce,
            transcript: transcript
        )
        challenges[challengeIdentifier] = ChallengeContext(
            challenge: challenge,
            presentation: presentation
        )
        return challenge
    }

    public func completeAuthentication(
        _ proof: MCPAuthenticationProof
    ) throws -> MCPAuthenticationResult {
        if consumedChallengeIdentifiers.contains(proof.challengeIdentifier) {
            throw MCPPairingCoordinatorError.replayedChallenge
        }
        guard let context = challenges.removeValue(forKey: proof.challengeIdentifier) else {
            throw MCPPairingCoordinatorError.unknownChallenge
        }
        recordConsumedChallenge(proof.challengeIdentifier)

        guard signatureVerifier.verify(
            signature: proof.signature,
            message: context.challenge.transcript,
            publicKey: context.presentation.publicKey
        ) else {
            throw MCPPairingCoordinatorError.invalidSignature
        }

        if let trusted = try trustStore.client(
            identifier: context.presentation.clientIdentifier
        ) {
            guard !trusted.isRevoked else {
                throw MCPPairingCoordinatorError.clientRevoked
            }
            guard
                trusted.publicKey == context.presentation.publicKey,
                trusted.codeIdentity.isMateriallyEquivalent(
                    to: context.presentation.parentIdentity
                )
            else {
                return .approvalRequired(
                    createPendingRequest(
                        presentation: context.presentation,
                        reason: .identityChanged,
                        previousIdentity: trusted.codeIdentity
                    )
                )
            }

            _ = try trustStore.markSeen(
                identifier: trusted.identifier,
                at: now()
            )
            guard let refreshed = try trustStore.client(identifier: trusted.identifier) else {
                throw MCPPairingCoordinatorError.invalidPresentation
            }
            return .authenticated(refreshed)
        }

        return .approvalRequired(
            createPendingRequest(
                presentation: context.presentation,
                reason: .firstPairing,
                previousIdentity: nil
            )
        )
    }

    public func approve(requestIdentifier: String) throws -> MCPTrustedClient {
        guard let request = pendingRequests.first(where: {
            $0.identifier == requestIdentifier
        }) else {
            throw MCPPairingCoordinatorError.pendingRequestNotFound
        }
        let existing = try trustStore.client(
            identifier: request.presentation.clientIdentifier
        )
        if existing?.isRevoked == true {
            throw MCPPairingCoordinatorError.clientRevoked
        }
        let approvalDate = now()
        let client = MCPTrustedClient(
            identifier: request.presentation.clientIdentifier,
            displayName: request.presentation.displayName,
            publicKey: request.presentation.publicKey,
            codeIdentity: request.presentation.parentIdentity,
            createdAt: existing?.createdAt ?? approvalDate,
            lastSeenAt: approvalDate,
            revokedAt: nil
        )
        try trustStore.trust(client)
        pendingRequests.removeAll { $0.identifier == requestIdentifier }
        return client
    }

    @discardableResult
    public func reject(requestIdentifier: String) -> Bool {
        let originalCount = pendingRequests.count
        pendingRequests.removeAll { $0.identifier == requestIdentifier }
        return pendingRequests.count != originalCount
    }

    private func createPendingRequest(
        presentation: MCPAuthenticationPresentation,
        reason: MCPPairingReason,
        previousIdentity: MCPCodeIdentity?
    ) -> MCPPairingRequest {
        pendingRequests.removeAll {
            $0.presentation.clientIdentifier == presentation.clientIdentifier
        }
        let request = MCPPairingRequest(
            identifier: UUID().uuidString.lowercased(),
            presentation: presentation,
            reason: reason,
            previousIdentity: previousIdentity,
            requestedAt: now()
        )
        pendingRequests.append(request)
        return request
    }

    private func recordConsumedChallenge(_ identifier: String) {
        consumedChallengeIdentifiers.insert(identifier)
        consumedChallengeOrder.append(identifier)
        if consumedChallengeOrder.count > Self.replayCacheCapacity {
            let evicted = consumedChallengeOrder.removeFirst()
            consumedChallengeIdentifiers.remove(evicted)
        }
    }

    private func isValid(_ presentation: MCPAuthenticationPresentation) -> Bool {
        guard
            isValidIdentifier(presentation.clientIdentifier),
            !presentation.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            presentation.displayName.count <= 128,
            !presentation.publicKey.isEmpty,
            presentation.publicKey.count <= 512,
            presentation.parentIdentity.executablePath.hasPrefix("/")
        else {
            return false
        }
        if presentation.parentIdentity.isSigned {
            return presentation.parentIdentity.teamIdentifier?.isEmpty == false
                && presentation.parentIdentity.signingIdentifier?.isEmpty == false
        }
        return presentation.parentIdentity.codeDirectoryHash?.isEmpty == false
    }

    private func isValidIdentifier(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 256
    }
}
