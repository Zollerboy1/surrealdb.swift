//
// SurrealDBModel.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

public protocol SurrealDBModel: AnyObject, Decodable {
    associatedtype Index: SurrealDBIndex
    associatedtype CreateBlueprint: SurrealDBBlueprint
    associatedtype UpdateBlueprint: SurrealDBBlueprint

    static var table: String { get }
    static var schema: SurrealDBSchema { get }

    static func create(
        fromBlueprint blueprint: CreateBlueprint
    ) async throws -> Self
    static func create(
        withID id: Index,
        fromBlueprint blueprint: CreateBlueprint
    ) async throws -> Self


    var id: Index { get }

    func update(
        withBlueprint blueprint: UpdateBlueprint
    ) async throws -> Self

    func resetUpdateBlueprint()
}

extension SurrealDBModel {
    public static func create(
        fromBlueprint blueprint: CreateBlueprint
    ) async throws -> Self {
        fatalError("Not implemented")
    }

    public static func create(
        withID id: Index,
        fromBlueprint blueprint: CreateBlueprint
    ) async throws -> Self {
        fatalError("Not implemented")
    }

    public func update(
        withBlueprint blueprint: UpdateBlueprint
    ) async throws -> Self {
        fatalError("Not implemented")
    }
}
