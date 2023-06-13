//
// SurrealDBError.swift
// SurrealDB
//
// Created by Josef Zoller on 12.06.23.

import WebSocket

public enum SurrealDBError: Error, CustomStringConvertible {
    case socketIsAlreadyConnecting
    case socketIsAlreadyConnected
    case socketDisconnected(errorCode: WebSocketErrorCode)
    case socketIsNotConnected
    case socketInvalidResponse(string: String)
    case socketInvalidResult(string: Substring)
    case rpcError(code: Int, message: Substring)
    case modelDatabaseNotProvided

    public var description: String {
        switch self {
        case .socketIsAlreadyConnecting:
            "Tried to connect socket while it was already connecting"
        case .socketIsAlreadyConnected:
            "Tried to connect socket while it was already connected"
        case let .socketDisconnected(errorCode):
            "Socket disconnected with error code \(errorCode)"
        case .socketIsNotConnected:
            "Tried to send request while socket was not connected"
        case let .socketInvalidResponse(string):
            "Socket recieved invalid response: \(string)"
        case let .socketInvalidResult(string):
            "Socket response contained invalid result: \(string)"
        case let .rpcError(code, message):
            "RPC error with code \(code) and message: \(message)"
        case .modelDatabaseNotProvided:
            "Must provide database in user data for decoding model"
        }
    }
}
