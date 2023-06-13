//
// Null.swift
// SurrealDB
//
// Created by Josef Zoller on 13.06.23.

internal struct Null: Sendable, Equatable, Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if !container.decodeNil() {
            throw DecodingError.typeMismatch(
                Null.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected null value"
                )
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encodeNil()
    }
}
