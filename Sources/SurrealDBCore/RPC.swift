//
// RPC.swift
// SurrealDB
//
// Created by Josef Zoller on 13.06.23.

import class Foundation.JSONEncoder

internal protocol RPCMethod {
    associatedtype Result: Decodable

    static var name: String { get }

    var encodedParameters: String? { get throws }
}

extension RPCMethod {
    var encodedParameters: String? { nil }
}

internal protocol RPCMethod1: RPCMethod {
    associatedtype Parameter1: Encodable

    var param1: Parameter1 { get }
}

extension RPCMethod1 {
    var encodedParameters: String? {
        get throws {
            let data = try JSONEncoder().encode([self.param1])

            return String(data: data, encoding: .utf8)
        }
    }
}

internal protocol RPCMethod2: RPCMethod1 {
    associatedtype Parameter2: Encodable

    var param2: Parameter2 { get }
}

extension RPCMethod2 where Parameter1 == Parameter2 {
    var encodedParameters: String? {
        get throws {
            let data = try JSONEncoder().encode([self.param1, self.param2])

            return String(data: data, encoding: .utf8)
        }
    }
}

extension RPCMethod2 {
    var encodedParameters: String? {
        get throws {
            let encoder = JSONEncoder()
            let data1 = try encoder.encode(self.param1)
            let data2 = try encoder.encode(self.param2)

            return "[" + String(data: data1, encoding: .utf8)!
                + ", " + String(data: data2, encoding: .utf8)! + "]"
        }
    }
}

internal enum RPC {
    struct Ping: RPCMethod {
        typealias Result = Null

        static let name = "ping"
    }

    struct Use: RPCMethod2 {
        typealias Result = Null

        static let name = "use"

        let identifier: DatabaseIdentifier

        init(databaseWithIdentifier identifier: DatabaseIdentifier) {
            self.identifier = identifier
        }

        var param1: String { self.identifier.namespace }
        var param2: String { self.identifier.database }
    }

    struct Signin: RPCMethod1 {
        typealias Result = Null

        static let name = "signin"

        let username: String
        let password: String

        var param1: [String: String] {
            ["user": self.username, "pass": self.password]
        }
    }

    struct Version: RPCMethod {
        typealias Result = String

        static let name = "version"
    }
}

extension RPCMethod where Self == RPC.Ping {
    static var ping: Self { .init() }
}

extension RPCMethod where Self == RPC.Use {
    static func use(
        databaseWithIdentifier identifier: DatabaseIdentifier
    ) -> Self {
        .init(databaseWithIdentifier: identifier)
    }
}

extension RPCMethod where Self == RPC.Signin {
    static func signin(username: String, password: String) -> Self {
        .init(username: username, password: password)
    }
}

extension RPCMethod where Self == RPC.Version {
    static var version: Self { .init() }
}
