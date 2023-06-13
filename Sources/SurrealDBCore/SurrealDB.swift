//
// SurrealDB.swift
// SurrealDB
//
// Created by Josef Zoller on 13.06.23.

import struct Foundation.URL

public final class SurrealDB: Sendable {
    private actor DatabaseInfo {
        var identifier: DatabaseIdentifier?

        init() {
            self.identifier = nil
        }

        func getIdentifier() -> DatabaseIdentifier? {
            self.identifier
        }

        func setIdentifier(
            _ identifier: DatabaseIdentifier,
            withSocket socket: Socket
        ) async throws {
            try await socket.sendRequest(
                withMethod: .use(databaseWithIdentifier: identifier)
            )

            self.identifier = identifier
        }
    }

    private let hostName: String
    private let port: Int
    private let socket: Socket
    private let databaseInfo: DatabaseInfo

    public init(
        hostName: String,
        port: Int,
        databaseIdentifier: DatabaseIdentifier? = nil
    ) async throws {
        let url = URL(string: "ws://\(hostName):\(port)/rpc")!

        self.hostName = hostName
        self.port = port
        self.socket = Socket(url: url)
        self.databaseInfo = .init()

        try await self.socket.connect()
    }

    public func use(
        databaseWithIdentifier identifier: DatabaseIdentifier
    ) async throws {
        try await self.databaseInfo.setIdentifier(
            identifier,
            withSocket: self.socket
        )
    }
}
