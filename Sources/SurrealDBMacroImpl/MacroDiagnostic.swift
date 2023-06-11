//
// MacroDiagnostic.swift
// SurrealDB
//
// Created by Josef Zoller on 10.06.23.

import SurrealDBCore
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder

struct MacroDiagnostic: Error {
    private struct SimpleDiagnostic: DiagnosticMessage {
        let message: String
        let diagnosticID: MessageID
        let severity: DiagnosticSeverity
    }

    private struct SimpleNoteMessage: NoteMessage {
        let message: String
        let fixItID: MessageID
    }

    private struct SimpleFixItMessage: FixItMessage {
        let message: String
        let fixItID: MessageID
    }

    enum Kind {
        case notAttachedToClass
        case attachedToStruct(
            structDecl: StructDeclSyntax
        )
        case attachedToGenericClass
        case attachedToNonFinalClass(classDecl: ClassDeclSyntax)
        case multipleBindingsNotSupported(variableDecl: VariableDeclSyntax)
        case patternKindNotSupported(patternSyntax: PatternSyntax)
        case typeNotSupported(type: TypeSyntax)
        case typeAnnotationMissing(
            identifier: TokenSyntax,
            binding: PatternBindingSyntax
        )
        case idVariableTypeNotSupported(
            identifier: TokenSyntax,
            type: TypeSyntax?,
            binding: PatternBindingSyntax
        )
        case idVariableIsMutable(
            identifier: TokenSyntax,
            bindingKeyword: TokenSyntax
        )
        case tableVariableHasNoInitializer(
            identifier: TokenSyntax,
            binding: PatternBindingSyntax,
            suggestedName: String
        )
        case tableVariableTypeNotSupported(
            identifier: TokenSyntax,
            binding: PatternBindingSyntax
        )
        case tableVariableInitializerNotSupported(
            identifier: TokenSyntax,
            binding: PatternBindingSyntax,
            suggestedName: String
        )
        case notAttachedToSingleVariable(declaration: DeclSyntax)
    }

    let kind: Kind
    let attributeNode: AttributeSyntax

    var diagnostic: Diagnostic {
        let node = self.kind.node ?? .init(self.attributeNode)
        let message = self.kind.message
        let diagnosticID = self.kind.diagnosticID
        let severity = self.kind.severity
        let noteMessage = self.kind.noteMessage

        var notes: [Note] = []
        if let noteMessage {
            notes.append(
                .init(
                    node: .init(self.attributeNode),
                    message: SimpleNoteMessage(
                        message: noteMessage,
                        fixItID: diagnosticID
                    )
                )
            )
        }

        var highlights: [Syntax] = [.init(self.attributeNode)]
        var fixIts: [FixIt] = []
        switch self.kind {
        case let .attachedToStruct(structDecl):
        let structKeyword = structDecl.structKeyword
            let finalModifier = DeclModifierSyntax(
                leadingTrivia: structKeyword.leadingTrivia,
                name: "final"
            )

            let classDecl = structDecl
                .with(
                    \.structKeyword,
                    structKeyword
                        .with(\.tokenKind, .keyword(.class))
                        .with(\.leadingTrivia, .space)
                )
                .with(
                    \.modifiers,
                    structDecl.modifiers?.appending(finalModifier)
                        ?? ModifierListSyntax { finalModifier }
                )

            highlights.append(.init(structKeyword))
            fixIts.append(
                .init(
                    message: SimpleFixItMessage(
                        message: "change 'struct' to 'final class'",
                        fixItID: diagnosticID
                    ),
                    changes: [
                        .replace(
                            oldNode: .init(structDecl),
                            newNode: .init(classDecl)
                        )
                    ]
                )
            )
        case let .attachedToNonFinalClass(classDecl):
            let finalModifier = DeclModifierSyntax(
                leadingTrivia: classDecl.classKeyword.leadingTrivia,
                name: "final"
            )

            let fixedDecl = classDecl
                .with(
                    \.classKeyword,
                    classDecl.classKeyword.with(\.leadingTrivia, .space)
                )
                .with(
                    \.modifiers,
                    classDecl.modifiers?.appending(finalModifier)
                        ?? ModifierListSyntax { finalModifier }
                )

            highlights.append(.init(classDecl.classKeyword))
            fixIts.append(
                .init(
                    message: SimpleFixItMessage(
                        message: "add 'final' modifier",
                        fixItID: diagnosticID
                    ),
                    changes: [
                        .replace(
                            oldNode: .init(classDecl),
                            newNode: .init(fixedDecl)
                        )
                    ]
                )
            )
        case let .patternKindNotSupported(pattern):
            highlights.append(.init(pattern))
        case let .typeAnnotationMissing(identifier, binding):
            highlights.append(.init(identifier))
            fixIts.append(
                Self.makeTypeAnnotationFixIt(
                    for: binding,
                    type: .init(MissingTypeSyntax()),
                    message: "add type annotation",
                    diagnosticID: diagnosticID
                )
            )
        case let .tableVariableHasNoInitializer(identifier, binding, suggestedName):
            highlights.append(.init(identifier))
            fixIts.append(
                Self.makeInitializerFixIt(
                    for: binding,
                    suggestedName: suggestedName,
                    message: "add initializer",
                    diagnosticID: diagnosticID
                )
            )
        case let .tableVariableTypeNotSupported(identifier, binding):
            highlights.append(.init(identifier))
            fixIts.append(
                Self.makeTypeAnnotationFixIt(
                    for: binding,
                    type: "String",
                    message: "change type annotation to 'String'",
                    diagnosticID: diagnosticID
                )
            )
        case let .tableVariableInitializerNotSupported(identifier, binding, suggestedName):
            highlights.append(.init(identifier))
            fixIts.append(
                Self.makeInitializerFixIt(
                    for: binding,
                    suggestedName: suggestedName,
                    message: "change initializer to String literal",
                    diagnosticID: diagnosticID
                )
            )
        default:
            break
        }

        return Diagnostic(
            node: node,
            message: SimpleDiagnostic(
                message: message,
                diagnosticID: diagnosticID,
                severity: severity
            ),
            highlights: highlights,
            notes: notes,
            fixIts: fixIts
        )
    }


    private static func makeTypeAnnotationFixIt(
        for binding: PatternBindingSyntax,
        type: TypeSyntax,
        message: String,
        diagnosticID: MessageID
    ) -> FixIt {
        .init(
            message: SimpleFixItMessage(
                message: message,
                fixItID: diagnosticID
            ),
            changes: [
                .replace(
                    oldNode: .init(binding),
                    newNode: .init(
                        binding.with(
                            \.typeAnnotation,
                            TypeAnnotationSyntax.init(
                                colon: .colonToken(
                                    trailingTrivia: .space
                                ),
                                type: type
                            )
                        ).with(
                            \.pattern.trailingTrivia, []
                        ).with(
                            \.initializer,
                            binding.initializer.map {
                                $0.with(
                                    \.leadingTrivia, .space
                                )
                            }
                        )
                    )
                )
            ]
        )
    }

    private static func makeInitializerFixIt(
        for binding: PatternBindingSyntax,
        suggestedName: String,
        message: String,
        diagnosticID: MessageID
    ) -> FixIt {
        .init(
            message: SimpleFixItMessage(
                message: message,
                fixItID: diagnosticID
            ),
            changes: [
                .replace(
                    oldNode: .init(binding),
                    newNode: .init(
                        binding.with(
                            \.initializer,
                            InitializerClauseSyntax(
                                equal: .equalToken(
                                    leadingTrivia: .space,
                                    trailingTrivia: .space
                                ),
                                value: StringLiteralExprSyntax(
                                    content: suggestedName
                                )
                            )
                        ).with(
                            \.pattern.trailingTrivia, []
                        ).with(
                            \.typeAnnotation,
                            binding.typeAnnotation.map {
                                $0.with(
                                    \.trailingTrivia, []
                                )
                            }
                        )
                    )
                )
            ]
        )
    }
}

extension MacroDiagnostic.Kind {
    fileprivate var node: Syntax? {
        switch self {
        case .notAttachedToClass,
            .attachedToGenericClass:
            nil
        case let .attachedToStruct(structDecl):
            .init(structDecl.structKeyword)
        case let .attachedToNonFinalClass(classDecl):
            .init(classDecl)
        case let .multipleBindingsNotSupported(variableDecl):
            .init(variableDecl)
        case let .patternKindNotSupported(pattern):
            .init(pattern)
        case let .typeNotSupported(type):
            .init(type)
        case let .typeAnnotationMissing(identifier, _):
            .init(identifier)
        case let .idVariableTypeNotSupported(identifier, _, _):
            .init(identifier)
        case let .idVariableIsMutable(identifier, _):
            .init(identifier)
        case let .tableVariableHasNoInitializer(identifier, _, _):
            .init(identifier)
        case let .tableVariableTypeNotSupported(identifier, _):
            .init(identifier)
        case let .tableVariableInitializerNotSupported(identifier, _, _):
            .init(identifier)
        case let .notAttachedToSingleVariable(declaration):
            .init(declaration)
        }
    }

    fileprivate var message: String {
        switch self {
        case .notAttachedToClass,
            .attachedToStruct:
            "@Model can only be attached to classes"
        case .attachedToGenericClass:
            "@Model cannot be attached to generic classes"
        case .attachedToNonFinalClass:
            "@Model can only be attached to final classes"
        case .multipleBindingsNotSupported:
            "@Model doesn't support multiple variable bindings on a single line"
        case let .patternKindNotSupported(pattern):
            "\(pattern.kind) is not supported"
        case let .typeNotSupported(type):
            "type '\(type)' is not supported by @Model"
        case .typeAnnotationMissing:
            "type annotation missing in pattern"
        case let .idVariableTypeNotSupported(_, type?, _):
            "type '\(type)' is not supported for a @Model id"
        case .idVariableTypeNotSupported:
            "@Model id has unsupported type"
        case .idVariableIsMutable:
            "@Model id must be immutable"
        case .tableVariableHasNoInitializer:
            "table variable must have an initializer"
        case .tableVariableTypeNotSupported:
            "table variable must be of type String"
        case .tableVariableInitializerNotSupported:
            "table variable initializer must be a static String literal"
        case .notAttachedToSingleVariable:
            "@MutableField can only be attached to a single stored variable"
        }
    }

    fileprivate var diagnosticID: MessageID {
        .init(domain: "SurrealDB", id: "ModelMacroDiagnostic." + self.caseName)
    }

    fileprivate var severity: DiagnosticSeverity {
        switch self {
        default:
            return .error
        }
    }

    fileprivate var noteMessage: String? {
        switch self {
        case .patternKindNotSupported:
            "@Model only supports simple identifier patterns"
        case .typeNotSupported:
            "@Model only supports the following types: "
            + SurrealDBType.allCases.map {
                "'\($0.swiftTypeName)'"
            }.joined(separator: ", ")
        case .typeAnnotationMissing:
            "@Model requires type annotations or simple initializers for all variables"
        case .idVariableTypeNotSupported:
            "@Model supports the following types for ids: "
            + SurrealDBType.allCases.filter {
                $0.swiftType is SurrealDBIndex.Type
            }.map {
                "'\($0.swiftTypeName)'"
            }.joined(separator: ", ")
        case .idVariableIsMutable:
            "@Model requires that the id is a constant"
        case .tableVariableHasNoInitializer,
                .tableVariableTypeNotSupported,
                .tableVariableInitializerNotSupported:
            "@Model requires that the table name is a static String"
        default:
            nil
        }
    }

    private var caseName: String {
        switch self {
        case .notAttachedToClass:
            "notAttachedToClass"
        case .attachedToStruct:
            "attachedToStruct"
        case .attachedToGenericClass:
            "attachedToGenericClass"
        case .attachedToNonFinalClass:
            "attachedToNonFinalClass"
        case .multipleBindingsNotSupported:
            "multipleBindingsNotSupported"
        case .patternKindNotSupported:
            "patternKindNotSupported"
        case .typeNotSupported:
            "typeNotSupported"
        case .typeAnnotationMissing:
            "typeAnnotationMissing"
        case .idVariableTypeNotSupported:
            "idVariableTypeNotSupported"
        case .idVariableIsMutable:
            "idVariableIsMutable"
        case .tableVariableHasNoInitializer:
            "tableVariableHasNoInitializer"
        case .tableVariableTypeNotSupported:
            "tableVariableTypeNotSupported"
        case .tableVariableInitializerNotSupported:
            "tableVariableInitializerNotSupported"
        case .notAttachedToSingleVariable:
            "notAttachedToSingleVariable"
        }
    }
}
