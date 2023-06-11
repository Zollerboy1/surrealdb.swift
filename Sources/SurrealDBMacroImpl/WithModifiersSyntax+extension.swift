//
// VariableDeclSyntax+extension.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

import SwiftSyntax

extension WithModifiersSyntax {
    func getModifier(_ modifier: TokenKind) -> DeclModifierSyntax? {
        self.modifiers?.first(where: { $0.name.tokenKind == modifier })
    }

    func hasModifier(_ modifier: TokenKind) -> Bool {
        self.getModifier(modifier) != nil
    }
}
