//
// MutableFieldMacro.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum MutableFieldMacro: AccessorMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard
            let variable = declaration.as(VariableDeclSyntax.self),
            variable.bindingKeyword.tokenKind == .keyword(.var),
            variable.bindings.count == 1,
            let binding = variable.bindings.first,
            !binding.hasComputedAccessors,
            let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            context.diagnose(MacroDiagnostic(
                kind: .notAttachedToSingleVariable(
                    declaration: .init(declaration)
                ),
                attributeNode: node
            ).diagnostic)

            return []
        }

        let ifExpression = { (parameterName: TokenSyntax) in
            try IfExprSyntax(
                """
                if \(parameterName) != self.\(pattern.identifier) \
                && self.$updateBlueprint.\(pattern.identifier) == nil
                """
            ) {
                ExprSyntax(
                    """
                    self.$updateBlueprint = self.$updateBlueprint.with(\
                    \(pattern.identifier): \(parameterName))
                    """
                )
            }
        }

        if case let .accessors(block) = binding.accessor,
            let didSetAccessor = block.accessors.first(where: {
                $0.accessorKind.tokenKind == .keyword(.didSet)
            }),
            let didSetAccessorBody = didSetAccessor.body {
            let didSetParameter = didSetAccessor.parameter?.name ?? "oldValue"
            return [
                """
                didSet(\(didSetParameter)) {
                    \(try ifExpression(didSetParameter))

                    do \(didSetAccessorBody)
                }
                """
            ]
        }

        return [
            """
            didSet(oldValue) {
                \(try ifExpression("oldValue"))
            }
            """
        ]
    }
}
