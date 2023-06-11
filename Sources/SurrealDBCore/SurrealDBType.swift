//
// SurrealDBType.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

import BigDecimal
import struct Foundation.Date
import struct Foundation.TimeInterval
import struct Foundation.UUID
import ULID

public enum SurrealDBType: String, Equatable, Hashable, CaseIterable {
    case bool
    case datetime
    case decimal
    case duration
    case float
    case double
    case int8
    case int16
    case int32
    case int64
    case int
    case uint8
    case uint16
    case uint32
    case uint64
    case uint
    case string
    case ulid
    case uuid

    public init?(fromSwiftTypeName swiftType: String) {
        switch swiftType {
        case "Bool":
            self = .bool
        case "Date", "Foundation.Date":
            self = .datetime
        case "BigDecimal":
            self = .decimal
        case "TimeInterval", "Foundation.TimeInterval":
            self = .duration
        case "Float":
            self = .float
        case "Double":
            self = .double
        case "Int8":
            self = .int8
        case "Int16":
            self = .int16
        case "Int32":
            self = .int32
        case "Int64":
            self = .int64
        case "Int":
            self = .int
        case "UInt8":
            self = .uint8
        case "UInt16":
            self = .uint16
        case "UInt32":
            self = .uint32
        case "UInt64":
            self = .uint64
        case "UInt":
            self = .uint
        case "String":
            self = .string
        case "ULID":
            self = .ulid
        case "UUID", "Foundation.UUID":
            self = .uuid
        default:
            return nil
        }
    }

    public var swiftType: Any.Type {
        switch self {
        case .bool: Bool.self
        case .datetime: Date.self
        case .decimal: BigDecimal.self
        case .duration: TimeInterval.self
        case .float: Float.self
        case .double: Double.self
        case .int8: Int8.self
        case .int16: Int16.self
        case .int32: Int32.self
        case .int64: Int64.self
        case .int: Int.self
        case .uint8: UInt8.self
        case .uint16: UInt16.self
        case .uint32: UInt32.self
        case .uint64: UInt64.self
        case .uint: UInt.self
        case .string: String.self
        case .ulid: ULID.self
        case .uuid: UUID.self
        }
    }

    public var swiftTypeName: String {
        switch self {
        case .bool: "Bool"
        case .datetime: "Foundation.Date"
        case .decimal: "BigDecimal"
        case .duration: "Foundation.TimeInterval"
        case .float: "Float"
        case .double: "Double"
        case .int8: "Int8"
        case .int16: "Int16"
        case .int32: "Int32"
        case .int64: "Int64"
        case .int: "Int"
        case .uint8: "UInt8"
        case .uint16: "UInt16"
        case .uint32: "UInt32"
        case .uint64: "UInt64"
        case .uint: "UInt"
        case .string: "String"
        case .ulid: "ULID"
        case .uuid: "Foundation.UUID"
        }
    }

    public var sqlType: String {
        switch self {
        case .bool: "bool"
        case .datetime: "datetime"
        case .decimal: "decimal"
        case .duration: "duration"
        case .float: "float"
        case .double: "float"
        case .int8: "int"
        case .int16: "int"
        case .int32: "int"
        case .int64: "int"
        case .int: "int"
        case .uint8: "int"
        case .uint16: "int"
        case .uint32: "int"
        case .uint64: "number"
        case .uint: "number"
        case .string: "string"
        case .ulid: "string"
        case .uuid: "string"
        }
    }
}
