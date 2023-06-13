//
// SurrealDBIndex.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

import struct Foundation.UUID
import ULID

/// A type that can be used as an index for a `ModelProtocol`.
///
/// `Int`, `String`, `UUID`, and `ULID` conform to this protocol.
/// Do not conform other types to this protocol.
public protocol SurrealDBIndex {}

extension Int: SurrealDBIndex {}
extension String: SurrealDBIndex {}
extension UUID: SurrealDBIndex {}
extension ULID: SurrealDBIndex {}
