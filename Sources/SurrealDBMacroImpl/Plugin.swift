//
// Plugin.swift
// SurrealDB
//
// Created by Josef Zoller on 10.06.23.

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct Plugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ModelMacro.self,
        MutableFieldMacro.self,
    ]
}
