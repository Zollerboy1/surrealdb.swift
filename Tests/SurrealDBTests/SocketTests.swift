//
// SocketTests.swift
// SurrealDB
//
// Created by Josef Zoller on 12.06.23.

import SwiftCommand
import XCTest

@testable import SurrealDBCore

final class SocketTests: XCTestCase {
    private static let surrealCommand = Command.findInPath(withName: "surreal")!
    private static let surrealVersion = {
        try! surrealCommand
            .addArgument("version")
            .waitForOutput()
            .stdout
            .prefix { $0 != " " }
    }()

    private static var surrealProcess: ChildProcess<
        NullInputSource,
        NullOutputDestination,
        NullOutputDestination
    >!

    override class func setUp() {
        super.setUp()

        Self.surrealProcess = try! Self.surrealCommand.addArguments(
                "start",
                "--bind", "0.0.0.0:8081",
                "--user", "root",
                "--pass", "root",
                "memory"
            )
            .setStdin(.null)
            .setStdout(.null)
            .setStderr(.null)
            .spawn()

        sleep(1)
    }

    override class func tearDown() {
        sleep(1)

        Self.surrealProcess.terminate()
        Self.surrealProcess = nil

        super.tearDown()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        guard Self.surrealProcess.isRunning else {
            throw XCTSkip("SurrealDB process is not running")
        }
    }

    func testVersion() async throws {
        let socket = Socket(
            url: URL(string: "ws://localhost:8081/rpc")!
        )

        try await socket.connect()

        let isConnected = await socket.isConnected
        XCTAssertTrue(isConnected)

        let versionString = try await socket.sendRequest(withMethod: .version)

        XCTAssertEqual(
            versionString.trimmingPrefix("surrealdb-"),
            Self.surrealVersion
        )

        socket.disconnect()
    }

    func testPing() async throws {
        let socket = Socket(
            url: URL(string: "ws://localhost:8081/rpc")!
        )

        try await socket.connect()

        let isConnected = await socket.isConnected
        XCTAssertTrue(isConnected)

        try await socket.sendRequest(withMethod: .ping)

        socket.disconnect()
    }

    func testRequestInterleaving() async throws {
        let socket = Socket(
            url: URL(string: "ws://localhost:8081/rpc")!
        )

        try await socket.connect()

        let isConnected = await socket.isConnected
        XCTAssertTrue(isConnected)

        try await withThrowingTaskGroup(
            of: String?.self
        ) { group in
            for i in 0..<100 {
                group.addTask {
                    if i % 2 == 0 {
                        return try await socket.sendRequest(
                            withMethod: .version
                        )
                    } else {
                        try await socket.sendRequest(withMethod: .ping)
                        return nil
                    }
                }
            }

            for try await versionString in group {
                if let versionString {
                    XCTAssertEqual(
                        versionString.trimmingPrefix("surrealdb-"),
                        Self.surrealVersion
                    )
                }
            }
        }

        socket.disconnect()
    }
}
