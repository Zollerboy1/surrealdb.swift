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
    case invalidResponse(string: String)

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
        case let .invalidResponse(string):
            "Socket recieved invalid response: \(string)"
        }
    }
}
