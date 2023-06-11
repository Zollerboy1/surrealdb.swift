//
// RangeReplaceableCollection+removeFirst.swift
// SurrealDB
//
// Created by Josef Zoller on 11.06.23.

extension RangeReplaceableCollection {
    @discardableResult
    mutating func removeFirst(where predicate: (Element) throws -> Bool) rethrows -> Element? {
        guard let index = try self.firstIndex(where: predicate) else {
            return nil
        }

        return self.remove(at: index)
    }
}
