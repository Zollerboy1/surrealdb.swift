//
// SurrealDBType+typeSyntax.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

import SurrealDBCore
import SwiftSyntax

extension SurrealDBType {
    var typeSyntax: TypeSyntax {
        "\(raw: self.swiftTypeName)"
    }
}
