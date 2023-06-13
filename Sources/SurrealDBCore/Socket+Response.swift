//
// Socket+Response.swift
// SurrealDB
//
// Created by Josef Zoller on 12.06.23.

import RegexBuilder

extension Socket {
    internal struct Response: Sendable {
        enum Kind {
            case error(errorCode: Int, message: Substring)
            case result(json: Substring)
        }

        let requestID: UInt64
        let kind: Kind

        fileprivate init(requestID: UInt64, kind: Kind) {
            self.requestID = requestID
            self.kind = kind
        }
    }
}

extension Socket.Response {
    private static let responseRegex = #/
        ^\s*
        \{\s*
        "id"\s*:\s*(?<requestID>[0-9]+)\s*,\s*
        (?:
            "result"\s*:\s*(?<result>.+)
            |
            "error"\s*:\s*\{\s*
            "code"\s*:\s*(?<errorCode>-?[0-9]+)\s*,\s*
            "message"\s*:\s*"(?<errorMessage>.+)"\s*,?\s*
            \}
        )
        \s*,?\s*\}\s*$
    /#

    init?(parsedFrom json: String) {
        guard
            let match = json.wholeMatch(of: Self.responseRegex),
            let requestID = UInt64(match.output.requestID)
        else {
            return nil
        }

        if let result = match.output.result {
            self.init(requestID: requestID, kind: .result(json: result))
        } else if
            let errorCode = match.output.errorCode.flatMap({ Int.init($0) }),
            let errorMessage = match.output.errorMessage
        {
            self.init(
                requestID: requestID,
                kind: .error(errorCode: errorCode, message: errorMessage)
            )
        } else {
            return nil
        }
    }
}
