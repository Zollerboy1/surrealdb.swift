//
// Schema.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

public struct Schema {
    public let idType: SurrealDBType
    public let fields: [String: SurrealDBType]

    public init(idType: SurrealDBType, fields: [String: SurrealDBType]) {
        self.idType = idType
        self.fields = fields
    }
}
