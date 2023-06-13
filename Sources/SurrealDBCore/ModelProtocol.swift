//
// ModelProtocol.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

public protocol ModelProtocol: AnyObject, Decodable {
    associatedtype Index: SurrealDBIndex
    associatedtype CreateBlueprint: Blueprint
    associatedtype UpdateBlueprint: Blueprint

    static var table: String { get }
    static var schema: Schema { get }

    static func create(
        fromBlueprint blueprint: CreateBlueprint,
        on database: SurrealDB
    ) async throws -> Self
    static func create(
        withID id: Index,
        fromBlueprint blueprint: CreateBlueprint,
        on database: SurrealDB
    ) async throws -> Self


    var database: SurrealDB { get }

    var id: Index { get }

    func update(
        withBlueprint blueprint: UpdateBlueprint
    ) async throws -> Self

    func resetUpdateBlueprint()
}

extension ModelProtocol {
    public static var databaseUserInfoKey: CodingUserInfoKey {
        .init(rawValue: "sceneSetup")!
    }


    public static func create(
        fromBlueprint blueprint: CreateBlueprint,
        on database: SurrealDB
    ) async throws -> Self {
        fatalError("Not implemented")
    }

    public static func create(
        withID id: Index,
        fromBlueprint blueprint: CreateBlueprint,
        on database: SurrealDB
    ) async throws -> Self {
        fatalError("Not implemented")
    }

    public func update(
        withBlueprint blueprint: UpdateBlueprint
    ) async throws -> Self {
        fatalError("Not implemented")
    }
}


