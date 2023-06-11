//
// SurrealDBTests.swift
// SurrealDB
//
// Created by Josef Zoller on 10.06.23.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SurrealDB
@testable import SurrealDBMacroImpl

final class SurrealDBTests: XCTestCase {
    private static let testMacros: [String: Macro.Type] = [
        "Model": ModelMacro.self,
        "MutableField": MutableFieldMacro.self,
    ]

    func testModelMacro() throws {
        assertMacroExpansion("""
            @Model
            final class User {
                static let table = "user"

                let name: String
                var age: Int
            }
            """,
            expandedSource: """

            final class User {
                static let table = "user"

                let name: String
                var age: Int {
                    didSet (oldValue) {
                        if oldValue != self.age && self.$updateBlueprint.age == nil {
                            self.$updateBlueprint = self.$updateBlueprint.with(age: oldValue)
                        }
                    }
                }

                public let id: ULID

                public typealias Index = ULID

                private enum CodingKeys: String, CodingKey {
                    case id
                    case name = "name"
                    case age = "age"
                }

                public struct CreateBlueprint: SurrealDBBlueprint {
                    private let name: String
                    private let age: Int

                    public init(name: String, age: Int) {
                        self.name = name
                        self.age = age
                    }

                    public func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)

                        try container.encode(name, forKey: .name)
                        try container.encode(age, forKey: .age)
                    }
                }

                public struct UpdateBlueprint: SurrealDBBlueprint {
                    fileprivate let $hasChanges: Bool
                    fileprivate let name: String?
                    fileprivate let age: Int?

                    public init() {
                        self.$hasChanges = false

                        self.name = nil
                        self.age = nil
                    }

                    public init(name: String?, age: Int?) {
                        self.$hasChanges = true

                        self.name = name
                        self.age = age
                    }

                    public func with(name: String) -> UpdateBlueprint {
                        .init(name: .some(name), age: self.age)
                    }

                    public func with(age: Int) -> UpdateBlueprint {
                        .init(name: self.name, age: .some(age))
                    }

                    public func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)

                        if let name {
                            try container.encode(name, forKey: .name)
                        }
                        if let age {
                            try container.encode(age, forKey: .age)
                        }
                    }
                }

                public static let schema = SurrealDBSchema(
                    fields: [
                        "name": .string,
                        "age": .int
                    ]
                )

                public static func create(
                    name: String, age: Int
                ) async throws -> User  {
                    let blueprint = CreateBlueprint(
                        name: name, age: age
                    )

                    return try await Self.create(fromBlueprint: blueprint)
                }

                public static func create(
                    withID id: ULID, name: String, age: Int
                ) async throws -> User  {
                    let blueprint = CreateBlueprint(
                        name: name, age: age
                    )

                    return try await Self.create(
                        withID: id,
                        fromBlueprint: blueprint
                    )
                }

                private var $updateBlueprint = UpdateBlueprint()

                public func resetUpdateBlueprint() {
                    self.$updateBlueprint = UpdateBlueprint()
                }

                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    self.id = try container.decode(ULID.self, forKey: .id)

                    self.name = try container.decode(String.self, forKey: .name)
                    self.age = try container.decode(Int.self, forKey: .age)
                }
            }
            """,
            macros: Self.testMacros
        )
    }
}
