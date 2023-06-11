//
// ModelMacro.swift
// SurrealDB
//
// Created by Josef Zoller on 10.06.23.

import Algorithms
import LetterCase
import SurrealDBCore
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ModelMacro {
    private struct VariableInfo {
        let identifier: TokenSyntax
        let name: String
        let dbName: String
        let type: SurrealDBType
        let annotatedType: TypeSyntax?
        let initializer: ExprSyntax?
        let binding: PatternBindingSyntax
        let bindingKeyword: TokenSyntax
        let isVar: Bool

        init(
            identifier: TokenSyntax,
            type: SurrealDBType,
            annotatedType: TypeSyntax?,
            initializer: ExprSyntax?,
            binding: PatternBindingSyntax,
            bindingKeyword: TokenSyntax
        ) {
            self.identifier = identifier
            self.name = identifier.text
            self.dbName = self.name.convert(from: .lowerCamel, to: .snake)
            self.type = type
            self.annotatedType = annotatedType
            self.initializer = initializer
            self.binding = binding
            self.bindingKeyword = bindingKeyword
            self.isVar = bindingKeyword.tokenKind == .keyword(.var)
        }
    }

    private let classDecl: ClassDeclSyntax
    private let idVariableInfo, tableVariableInfo: VariableInfo?
    private let memberVariableInfos: [VariableInfo]
    private let memberVariables: [(name: TokenSyntax, type: TypeSyntax)]
    private let tableName: String
    private let indexType: SurrealDBType

    private init?(
        expanding node: AttributeSyntax,
        for declaration: some SyntaxProtocol,
        in context: some MacroExpansionContext,
        emitDiagnostics: Bool = true
    ) {
        let diagnose = {
            if emitDiagnostics {
                context.diagnose($0)
            }
        }

        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            if let structDecl = declaration.as(StructDeclSyntax.self) {
                diagnose(MacroDiagnostic(
                    kind: .attachedToStruct(structDecl: structDecl),
                    attributeNode: node
                ).diagnostic)
            } else {
                diagnose(MacroDiagnostic(
                    kind: .notAttachedToClass,
                    attributeNode: node
                ).diagnostic)
            }

            return nil
        }

        guard classDecl.genericParameterClause == nil else {
            diagnose(MacroDiagnostic(
                kind: .attachedToGenericClass,
                attributeNode: node
            ).diagnostic)

            return nil
        }

        guard classDecl.hasModifier(.keyword(.final)) else {
            diagnose(MacroDiagnostic(
                kind: .attachedToNonFinalClass(classDecl: classDecl),
                attributeNode: node
            ).diagnostic)

            return nil
        }

        let defaultTableName = classDecl.identifier.text
            .convert(from: .upperCamel, to: .snake)

        let classMembers = classDecl.memberBlock.members
        let (memberVariables, staticVariables) = classMembers.compactMap {
            $0.decl.as(VariableDeclSyntax.self)
        }.partitioned {
            $0.hasModifier(.keyword(.static))
        }


        var memberVariableInfos: [VariableInfo]
        switch Self.normalizeVariables(
            memberVariables,
            whileExpanding: node
        ) {
            case let .success(normalizedVariableInfos):
                memberVariableInfos = normalizedVariableInfos
            case let .failure(error):
                diagnose(error.diagnostic)
                return nil
        }

        let idVariableInfo = memberVariableInfos.removeFirst {
            $0.identifier.text == "id"
        }

        if let idVariableInfo {
            guard idVariableInfo.type.swiftType is SurrealDBIndex.Type else {
                diagnose(MacroDiagnostic(
                    kind: .idVariableTypeNotSupported(
                        identifier: idVariableInfo.identifier,
                        type: idVariableInfo.annotatedType,
                        binding: idVariableInfo.binding
                    ),
                    attributeNode: node
                ).diagnostic)

                return nil
            }

            guard !idVariableInfo.isVar else {
                diagnose(MacroDiagnostic(
                    kind: .idVariableIsMutable(
                        identifier: idVariableInfo.identifier,
                        bindingKeyword: idVariableInfo.bindingKeyword
                    ),
                    attributeNode: node
                ).diagnostic)

                return nil
            }
        }

        let tableVariable: VariableInfo?
        let tableName: String
        switch Self.findTableVariable(
            staticVariables,
            whileExpanding: node,
            suggestedTableName: defaultTableName
        ) {
            case let .success((foundTableVariable, foundTableName)?):
                tableVariable = foundTableVariable
                tableName = foundTableName
            case .success(nil):
                tableVariable = nil
                tableName = defaultTableName
            case let .failure(error):
                diagnose(error.diagnostic)
                return nil
        }

        self.classDecl = classDecl
        self.memberVariableInfos = memberVariableInfos
        self.memberVariables = memberVariableInfos.map {
            (name: $0.identifier, type: $0.type.typeSyntax)
        }
        self.idVariableInfo = idVariableInfo
        self.tableVariableInfo = tableVariable
        self.tableName = tableName
        self.indexType = idVariableInfo?.type ?? .ulid
    }


    private static func normalizeVariables(
        _ variables: [VariableDeclSyntax],
        whileExpanding node: AttributeSyntax
    ) -> Result<[VariableInfo], MacroDiagnostic> {
        var variableInfos: [VariableInfo] = []
        for variable in variables {
            if variable.bindings.count != 1 {
                return .failure(.init(
                    kind: .multipleBindingsNotSupported(
                        variableDecl: variable
                    ),
                    attributeNode: node
                ))
            }

            let bindingKeyword = variable.bindingKeyword
            let binding = variable.bindings.first!

            if binding.hasComputedAccessors {
                continue
            }

            guard
                let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
            else {
                return .failure(.init(
                    kind: .patternKindNotSupported(
                        patternSyntax: binding.pattern
                    ),
                    attributeNode: node
                ))
            }

            let annotatedType = binding.typeAnnotation?.type
            let initializer = binding.initializer?.value

            if let annotatedType {
                guard let type = (
                    annotatedType.as(SimpleTypeIdentifierSyntax.self)?.name.text
                ).flatMap(SurrealDBType.init(fromSwiftTypeName:)) else {
                    return .failure(.init(
                        kind: .typeNotSupported(type: annotatedType),
                        attributeNode: node
                    ))
                }

                variableInfos.append(.init(
                    identifier: pattern.identifier,
                    type: type,
                    annotatedType: annotatedType,
                    initializer: initializer,
                    binding: binding,
                    bindingKeyword: bindingKeyword
                ))
            } else if let initializer {
                guard let type = self.type(of: initializer) else {
                    return .failure(.init(
                        kind: .typeAnnotationMissing(
                            identifier: pattern.identifier,
                            binding: binding
                        ),
                        attributeNode: node
                    ))
                }

                variableInfos.append(.init(
                    identifier: pattern.identifier,
                    type: type,
                    annotatedType: nil,
                    initializer: initializer,
                    binding: binding,
                    bindingKeyword: bindingKeyword
                ))
            } else {
                fatalError("This should never happen")
            }
        }

        return .success(variableInfos)
    }

    private static func findTableVariable(
        _ variables: [VariableDeclSyntax],
        whileExpanding node: AttributeSyntax,
        suggestedTableName: String
    ) -> Result<(VariableInfo, String)?, MacroDiagnostic> {
        for variable in variables {
            let bindingKeyword = variable.bindingKeyword

            var unresolvedBindings: [(TokenSyntax, PatternBindingSyntax)] = []
            for binding in variable.bindings {
                guard let pattern =
                    binding.pattern.as(IdentifierPatternSyntax.self) else {
                    continue
                }

                let annotatedType = binding.typeAnnotation?.type
                let initializer = binding.initializer?.value

                if let annotatedType {
                    if let (identifier, binding) = unresolvedBindings.first(
                        where: { $0.0.text == "table"}
                    ) {
                        return .failure(.init(
                            kind: .tableVariableHasNoInitializer(
                                identifier: identifier,
                                binding: binding,
                                suggestedName: suggestedTableName
                            ),
                            attributeNode: node
                        ))
                    }

                    unresolvedBindings = []

                    if pattern.identifier.text == "table" {
                        guard
                            let type = annotatedType
                                .as(SimpleTypeIdentifierSyntax.self),
                            type.name.text == "String"
                        else {
                            return .failure(.init(
                                kind: .tableVariableTypeNotSupported(
                                    identifier: pattern.identifier,
                                    binding: binding
                                ),
                                attributeNode: node
                            ))
                        }

                        guard let initializer else {
                            return .failure(.init(
                                kind: .tableVariableHasNoInitializer(
                                    identifier: pattern.identifier,
                                    binding: binding,
                                    suggestedName: suggestedTableName
                                ),
                                attributeNode: node
                            ))
                        }

                        guard
                            let initializer = initializer
                                .as(StringLiteralExprSyntax.self),
                            initializer.segments.count == 1,
                            let tableName = initializer.segments.first?
                                .as(StringSegmentSyntax.self)?.content.text
                        else {
                            return .failure(.init(
                                kind: .tableVariableInitializerNotSupported(
                                    identifier: pattern.identifier,
                                    binding: binding,
                                    suggestedName: suggestedTableName
                                ),
                                attributeNode: node
                            ))
                        }

                        return .success((.init(
                            identifier: pattern.identifier,
                            type: .string,
                            annotatedType: annotatedType,
                            initializer: .init(initializer),
                            binding: binding,
                            bindingKeyword: bindingKeyword
                        ), tableName))
                    }
                } else if let initializer {
                    guard pattern.identifier.text == "table" else {
                        continue
                    }

                    guard
                        let type = self.type(of: initializer),
                        type == .string,
                        let initializer = initializer
                            .as(StringLiteralExprSyntax.self),
                        initializer.segments.count == 1,
                        let tableName = initializer.segments.first?
                            .as(StringSegmentSyntax.self)?.content.text
                    else {
                        return .failure(.init(
                            kind: .tableVariableInitializerNotSupported(
                                identifier: pattern.identifier,
                                binding: binding,
                                suggestedName: suggestedTableName
                            ),
                            attributeNode: node
                        ))
                    }

                    return .success((.init(
                        identifier: pattern.identifier,
                        type: type,
                        annotatedType: nil,
                        initializer: .init(initializer),
                        binding: binding,
                        bindingKeyword: bindingKeyword
                    ), tableName))
                } else {
                    unresolvedBindings.append((pattern.identifier, binding))
                }
            }
        }

        return .success(nil)
    }

    private static func type(
        of expression: ExprSyntax
    ) -> SurrealDBType? {
        switch expression.kind {
        case .booleanLiteralExpr: .bool
        case .floatLiteralExpr: .float
        case .integerLiteralExpr: .int
        case .stringLiteralExpr: .string
        default:
            nil
        }
    }
}

extension ModelMacro: ConformanceMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingConformancesOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] {
        guard let _ = Self(
            expanding: node,
            for: declaration,
            in: context,
            emitDiagnostics: false
        ) else {
            return []
        }

        return [("SurrealDBModel", nil)]
    }
}

extension ModelMacro: MemberMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try Self(
            expanding: node,
            for: declaration,
            in: context
        )?.newMembers ?? []
    }

    private var newMembers: [DeclSyntax] {
        get throws {
            var members: [DeclSyntax] = [
                "public typealias Index = \(self.indexType.typeSyntax)",
                try self.buildCodingKeysEnum(),
                try self.buildCreateBlueprintStruct(),
                try self.buildUpdateBlueprintStruct(),
                try self.buildSchemaVariable(),
                try self.buildCreateFunction(withID: false),
                try self.buildCreateFunction(withID: true),
                "private var $updateBlueprint = UpdateBlueprint()",
                """
                public func resetUpdateBlueprint() {
                    self.$updateBlueprint = UpdateBlueprint()
                }
                """,
                try self.buildDecodableInitializer(),
            ]

            if self.tableVariableInfo == nil {
                members.insert(
                    "public static let table = \(literal: self.tableName)",
                    at: 0
                )
            }

            if self.idVariableInfo == nil {
                members.insert(
                    "public let id: \(self.indexType.typeSyntax)",
                    at: 0
                )
            }

            return members.map {
                $0.with(\.leadingTrivia, .newlines(2))
            }
        }
    }

    private func buildCodingKeysEnum() throws -> DeclSyntax {
        try .init(EnumDeclSyntax("private enum CodingKeys: String, CodingKey") {
            DeclSyntax("case id")

            for variable in self.memberVariableInfos {
                let name = variable.identifier
                let dbName = variable.dbName

                DeclSyntax("case \(name) = \(literal: dbName)")
            }
        })
    }

    private func buildCreateBlueprintStruct() throws -> DeclSyntax {
        try .init(StructDeclSyntax.init(
            "public struct CreateBlueprint: SurrealDBBlueprint"
        ) {
            for (name, type) in self.memberVariables {
                DeclSyntax("private let \(name): \(type)")
            }

            let initParameters = ParameterClauseSyntax.init {
                for (name, type) in self.memberVariables {
                    FunctionParameterSyntax("\(name): \(type)")
                }
            }

            try InitializerDeclSyntax("public init\(initParameters)") {
                for (name, _) in self.memberVariables {
                    ExprSyntax("self.\(name) = \(name)")
                }
            }.with(\.leadingTrivia, .newlines(2))

            try FunctionDeclSyntax(
                "public func encode(to encoder: Encoder) throws"
            ) {
                ExprSyntax(
                    """
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    """
                ).with(\.trailingTrivia, .newlines(2))

                for (name, _) in self.memberVariables {
                    ExprSyntax(
                        "try container.encode(\(name), forKey: .\(name))"
                    )
                }
            }.with(\.leadingTrivia, .newlines(2))
        })
    }

    private func buildUpdateBlueprintStruct() throws -> DeclSyntax {
        try .init(StructDeclSyntax.init(
            "public struct UpdateBlueprint: SurrealDBBlueprint"
        ) {
            DeclSyntax("fileprivate let $hasChanges: Bool")

            for (name, type) in self.memberVariables {
                DeclSyntax("fileprivate let \(name): \(type)?")
            }

            try InitializerDeclSyntax("public init()") {
                ExprSyntax("self.$hasChanges = false")
                    .with(\.trailingTrivia, .newlines(2))

                for (name, _) in self.memberVariables {
                    ExprSyntax("self.\(name) = nil")
                }
            }.with(\.leadingTrivia, .newlines(2))

            let initParameters = ParameterClauseSyntax.init {
                for (name, type) in self.memberVariables {
                    FunctionParameterSyntax("\(name): \(type)?")
                }
            }

            try InitializerDeclSyntax("public init\(initParameters)") {
                ExprSyntax("self.$hasChanges = true")
                    .with(\.trailingTrivia, .newlines(2))

                for (name, _) in self.memberVariables {
                    ExprSyntax("self.\(name) = \(name)")
                }
            }.with(\.leadingTrivia, .newlines(2))

            for (name, type) in self.memberVariables {
                try FunctionDeclSyntax(
                    "public func with(\(name): \(type)) -> UpdateBlueprint"
                ) {
                    let callArguments = self.memberVariables.map {
                        $0.name == name
                            ? "\(name): .some(\(name))"
                            : "\($0.name): self.\($0.name)"
                    }.joined(separator: ", ")

                    ExprSyntax(".init(\(raw: callArguments))")
                }.with(\.leadingTrivia, .newlines(2))
            }

            try FunctionDeclSyntax(
                "public func encode(to encoder: Encoder) throws"
            ) {
                ExprSyntax(
                    """
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    """
                ).with(\.trailingTrivia, .newlines(2))

                for (name, _) in self.memberVariables {
                    try IfExprSyntax("if let \(name)") {
                        ExprSyntax(
                            "try container.encode(\(name), forKey: .\(name))"
                        )
                    }
                }
            }.with(\.leadingTrivia, .newlines(2))
        })
    }

    private func buildSchemaVariable() throws -> DeclSyntax {
        let fields = self.memberVariableInfos.map {
            """
            "\($0.dbName)": .\($0.type.rawValue)
            """
        }.joined(separator: ",\n        ")

        return """
            public static let schema = SurrealDBSchema(
                fields: [
                    \(raw: fields)
                ]
            )
            """
    }

    private func buildCreateFunction(withID: Bool) throws -> DeclSyntax {
        let parameters = ParameterClauseSyntax(
            leftParen: .leftParenToken(
                trailingTrivia: [.newlines(1), .spaces(4)]
            ),
            rightParen: .rightParenToken(
                leadingTrivia: .newline
            )
        ) {
            if withID {
                FunctionParameterSyntax(
                    "withID id: \(self.indexType.typeSyntax)"
                )
            }

            for variable in self.memberVariableInfos {
                let name = variable.identifier
                let type = variable.type.typeSyntax

                if let initializer = variable.initializer {
                    FunctionParameterSyntax(
                        "\(name): \(type) = \(initializer)"
                    )
                } else {
                    FunctionParameterSyntax("\(name): \(type)")
                }
            }
        }

        return try .init(FunctionDeclSyntax(
            """
            public static func create\
            \(parameters)\
            async throws -> \(self.classDecl.identifier)
            """
        ) {
            let blueprintInitArguments = self.memberVariables.map {
                "\($0.name): \($0.name)"
            }.joined(separator: ", ")

            ExprSyntax(
                """
                let blueprint = CreateBlueprint(
                    \(raw: blueprintInitArguments)
                )
                """
            ).with(\.trailingTrivia, .newline)

            if withID {
                ExprSyntax(
                    """
                    return try await Self.create(
                        withID: id,
                        fromBlueprint: blueprint
                    )
                    """
                )
            } else {
                ExprSyntax(
                    "return try await Self.create(fromBlueprint: blueprint)"
                )
            }
        })
    }

    private func buildDecodableInitializer() throws -> DeclSyntax {
        try .init(InitializerDeclSyntax(
            "public init(from decoder: Decoder) throws"
        ) {
            ExprSyntax(
                """
                let container = try decoder.container(keyedBy: CodingKeys.self)
                """
            ).with(\.trailingTrivia, .newlines(2))

            ExprSyntax(
                """
                self.id = try container.decode(\
                \(self.indexType.typeSyntax).self, forKey: .id)
                """
            ).with(\.trailingTrivia, .newlines(2))

            for (name, type) in self.memberVariables {
                ExprSyntax(
                    """
                    self.\(name) = try container.decode(\
                    \(type).self, forKey: .\(name))
                    """
                )
            }
        })
    }
}

extension ModelMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard
            let _ = Self(
                expanding: node,
                for: declaration,
                in: context,
                emitDiagnostics: false
            ),
            let variable = member.as(VariableDeclSyntax.self),
            variable.bindingKeyword.tokenKind == .keyword(.var),
            !variable.hasModifier(.keyword(.static)),
            variable.bindings.count == 1,
            let binding = variable.bindings.first,
            !binding.hasComputedAccessors,
            let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
            pattern.identifier.text != "$updateBlueprint"
        else {
            return []
        }

        return [
            "@MutableField"
        ]
    }
}
