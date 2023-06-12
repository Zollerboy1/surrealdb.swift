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
        let socket = SurrealDBSocket(
            url: URL(string: "ws://localhost:8081/rpc")!
        )

        try await socket.connect()

        let isConnected = await socket.isConnected
        XCTAssertTrue(isConnected)

        let response = try await socket.sendRequest(withMethod: "version")

        guard case let .result(result) = response.kind else {
            XCTFail("Expected result response")
            return
        }

        XCTAssertEqual(
            result.trimmingPrefix("\"surrealdb-").dropLast(),
            Self.surrealVersion
        )

        socket.disconnect()
    }

    func testPing() async throws {
        let socket = SurrealDBSocket(
            url: URL(string: "ws://localhost:8081/rpc")!
        )

        try await socket.connect()

        let isConnected = await socket.isConnected
        XCTAssertTrue(isConnected)

        let response = try await socket.sendRequest(withMethod: "ping")

        guard case let .result(result) = response.kind else {
            XCTFail("Expected result response")
            return
        }

        XCTAssertEqual(result, "null")

        socket.disconnect()
    }

    func testRequestInterleaving() async throws {
        struct NoResultResponse: Error {}

        let socket = SurrealDBSocket(
            url: URL(string: "ws://localhost:8081/rpc")!
        )

        try await socket.connect()

        let isConnected = await socket.isConnected
        XCTAssertTrue(isConnected)

        try await withThrowingTaskGroup(
            of: (isVersion: Bool, result: Substring).self
        ) { group in
            for i in 0..<100 {
                group.addTask {
                    let response = try await socket.sendRequest(
                        withMethod: i % 2 == 0 ? "version" : "ping"
                    )

                    guard case let .result(result) = response.kind else {
                        throw NoResultResponse()
                    }

                    return (i % 2 == 0, result)
                }
            }

            do {
                for try await (isVersion, result) in group {
                    if isVersion {
                        XCTAssertEqual(
                            result.trimmingPrefix("\"surrealdb-").dropLast(),
                            Self.surrealVersion
                        )
                    } else {
                        XCTAssertEqual(result, "null")
                    }
                }
            } catch is NoResultResponse {
                group.cancelAll()
                XCTFail("Expected result response")
            } catch {
                group.cancelAll()
                throw error
            }
        }

        socket.disconnect()
    }
}
