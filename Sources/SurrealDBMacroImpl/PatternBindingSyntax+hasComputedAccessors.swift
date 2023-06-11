//
// PatternBindingSyntax+hasComputedAccessors.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

import SwiftSyntax

extension PatternBindingSyntax {
    var hasComputedAccessors: Bool {
        switch self.accessor {
        case .none:
            return false
        case let .accessors(block):
            for accessor in block.accessors {
                switch accessor.accessorKind.tokenKind {
                case .keyword(.willSet), .keyword(.didSet):
                    continue
                default:
                    return true
                }
            }

            return false
        case .getter:
            return true
        }
    }
}
