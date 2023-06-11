//
// SurrealDBSchema.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

public struct SurrealDBSchema {
    public let fields: [String: SurrealDBType]

    public init(fields: [String: SurrealDBType]) {
        self.fields = fields
    }
}
