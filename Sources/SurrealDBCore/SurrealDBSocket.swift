//
// SurrealDBSocket.swift
// SurrealDB
//
// Created by Josef Zoller on 12.06.23.

import Atomics
import struct Foundation.URL
import RegexBuilder
import WebSocket

internal final class SurrealDBSocket: @unchecked Sendable {
    private struct Request {
        let id: UInt64
        let method: String
        let parameters: String?

        var json: String {
            if let parameters = self.parameters {
                """
                {
                    "id": \(self.id),
                    "method": "\(self.method)",
                    "params": \(parameters)
                }
                """
            } else {
                """
                {
                    "id": \(self.id),
                    "method": "\(self.method)"
                }
                """
            }
        }
    }

    private actor StateStore {
        enum State {
            case none
            case connecting(continuation: CheckedContinuation<Void, any Error>)

            case connected(
                requestContinuations:
                    [UInt64: CheckedContinuation<Response, any Error>]
            )

            case disconnected(errorCode: WebSocketErrorCode)
            case error
        }

        var state: State

        var isConnected: Bool {
            if case .connected = self.state {
                true
            } else {
                false
            }
        }

        init() {
            self.state = .none
        }

        func startConnecting(
            withContinuation continuation: CheckedContinuation<Void, any Error>
        ) {
            switch self.state {
            case .none, .disconnected:
                self.state = .connecting(continuation: continuation)
            case .connecting:
                self.state = .error
                continuation.resume(
                    throwing: SurrealDBError.socketIsAlreadyConnecting
                )
            case .connected:
                self.state = .error
                continuation.resume(
                    throwing: SurrealDBError.socketIsAlreadyConnected
                )
            case .error:
                break
            }
        }

        func finishConnecting() {
            switch self.state {
            case let .connecting(continuation):
                self.state = .connected(requestContinuations: [:])
                continuation.resume(returning: ())
            default:
                break
            }
        }

        func disconnect(withErrorCode errorCode: WebSocketErrorCode) {
            let error = SurrealDBError.socketDisconnected(errorCode: errorCode)

            switch self.state {
            case let .connecting(continuation):
                self.state = .disconnected(errorCode: errorCode)
                continuation.resume(throwing: error)
            case let .connected(requestContinuations):
                self.state = .disconnected(errorCode: errorCode)
                for continuation in requestContinuations.values {
                    continuation.resume(throwing: error)
                }
            default:
                self.state = .disconnected(errorCode: errorCode)
            }
        }

        func error(_ error: any Error) {
            switch self.state {
            case let .connecting(continuation):
                self.state = .error
                continuation.resume(throwing: error)
            case let .connected(requestContinuations):
                self.state = .error
                for continuation in requestContinuations.values {
                    continuation.resume(throwing: error)
                }
            default:
                break
            }
        }

        func request(
            withID requestID: UInt64,
            continuation: CheckedContinuation<Response, any Error>
        ) throws {
            switch self.state {
            case var .connected(requestContinuations):
                self.state = .none

                guard requestContinuations[requestID] == nil else {
                    fatalError("Request ID \(requestID) is already in use")
                }

                requestContinuations[requestID] = continuation

                self.state = .connected(
                    requestContinuations: requestContinuations
                )
            default:
                throw SurrealDBError.socketIsNotConnected
            }
        }

        func recieveResponse(_ response: Response) {
            switch self.state {
            case var .connected(requestContinuations):
                self.state = .none
                let continuation = requestContinuations.removeValue(
                    forKey: response.requestID
                )

                self.state = .connected(
                    requestContinuations: requestContinuations
                )

                continuation?.resume(returning: response)
            default:
                break
            }
        }
    }

    private let url: URL
    private let socket: WebSocket
    private let nextRequestID: UnsafeAtomic<UInt64>
    private let stateStore: StateStore

    internal var isConnected: Bool {
        get async {
            await self.stateStore.isConnected
        }
    }

    internal init(url: URL) {
        self.url = url
        self.socket = WebSocket()
        self.nextRequestID = .create(1)
        self.stateStore = StateStore()

        self.socket.onConnected = self.onConnected(_:)
        self.socket.onDisconnected = self.onDisconnected(withErrorCode:_:)
        self.socket.onError = self.on(error:_:)
        self.socket.onData = self.on(data:_:)
    }

    internal func connect() async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.stateStore.startConnecting(
                    withContinuation: continuation
                )
                self.socket.connect(url: url)
            }
        }
    }

    internal func disconnect() {
        if self.socket.isConnected {
            self.socket.disconnect()
        }
    }


    internal func sendRequest(
        withMethod method: String,
        parameters: String? = nil
    ) async throws -> Response {
        let requestID = self.nextRequestID.loadThenWrappingIncrement(
            ordering: .acquiringAndReleasing
        )

        let request = Request(
            id: requestID,
            method: method,
            parameters: parameters
        )

        return try await self.send(request: request)
    }


    private func send(request: Request) async throws -> Response {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                try await self.stateStore.request(
                    withID: request.id,
                    continuation: continuation
                )

                self.socket.send(request.json)
            }
        }
    }


    private func onConnected(_: WebSocket) {
        Task {
            await self.stateStore.finishConnecting()
        }
    }

    private func onDisconnected(
        withErrorCode errorCode: WebSocketErrorCode,
        _: WebSocket
    ) {
        Task {
            await self.stateStore.disconnect(withErrorCode: errorCode)
        }
    }

    private func on(error: WebSocketError, _: WebSocket) {
        Task {
            await self.stateStore.error(error)

            if self.socket.isConnected {
                self.socket.disconnect()
            }
        }
    }

    private func on(data: WebSocketData, _: WebSocket) {
        Task {
            let string = switch data {
            case let .text(string): string
            case let .binary(data): String(decoding: data, as: UTF8.self)
            }

            if let response = Response(parsedFrom: string) {
                await self.stateStore.recieveResponse(response)
            } else {
                await self.stateStore.error(
                    SurrealDBError.invalidResponse(string: string)
                )
            }
        }
    }

    deinit {
        if self.socket.isConnected {
            self.socket.disconnect()
        }

        self.nextRequestID.destroy()
    }
}
