//
// Macros.swift
// SurrealDB
//
// Created by Josef Zoller on 10.06.23.

@attached(conformance)
@attached(member, names:
    named(database),
    named(id),
    named(table),
    named(Index),
    named(CodingKeys),
    named(CreateBlueprint),
    named(UpdateBlueprint),
    named(schema),
    named(create),
    named(create),
    named($updateBlueprint),
    named(resetUpdateBlueprint),
    named(init(from:))
)
@attached(memberAttribute)
public macro Model() = #externalMacro(
    module: "SurrealDBMacroImpl",
    type: "ModelMacro"
)

@attached(accessor, names: named(didSet))
public macro MutableField() = #externalMacro(
    module: "SurrealDBMacroImpl",
    type: "MutableFieldMacro"
)
