//
// DatabaseIdentifier.swift
// SurrealDB
//
// Created by Josef Zoller on 13.06.23.

public struct DatabaseIdentifier: Sendable {
    public let namespace: String
    public let database: String

    public init(namespace: String, database: String) {
        self.namespace = namespace
        self.database = database
    }
}
