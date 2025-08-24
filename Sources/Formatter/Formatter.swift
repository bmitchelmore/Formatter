//
//  Formatter.swift
//  Formatter
//
//  Created by Blair Mitchelmore on 2025-07-31.
//

import Foundation
import os

enum FormatError: Error, Equatable {
    case invalidFormat
    case unknownField(String)
}

public typealias FormattingRenderer<I> = @Sendable (I) -> String
public typealias FormattingExtractor<I, V> = @Sendable (I) -> V

public protocol Formattable: Sendable {
    static func extractor(for field: String) -> FormattingExtractor<Self, String>?
    static func extractor(for field: String) -> FormattingExtractor<Self, Int>?
    static func extractor(for field: String) -> FormattingExtractor<Self, Date>?
    static func extractor(for field: String) -> FormattingExtractor<Self, Float>?
    static func extractor(for field: String) -> FormattingExtractor<Self, Double>?
}

extension Formattable {
    static func extractor(for field: String) -> FormattingExtractor<Self, String>? {
        nil
    }
    static func extractor(for field: String) -> FormattingExtractor<Self, Int>? {
        nil
    }
    static func extractor(for field: String) -> FormattingExtractor<Self, Date>? {
        nil
    }
    static func extractor(for field: String) -> FormattingExtractor<Self, Float>? {
        nil
    }
    static func extractor(for field: String) -> FormattingExtractor<Self, Double>? {
        nil
    }
}

let dateFormatters = DateFormatterStorage()
let numberFormatters = NumberFormatterStorage()

private func anyExtractor<F: Formattable>(for field: String, with qualifier: String?, on type: F.Type) -> FormattingExtractor<F, String>? {
    if let string: FormattingExtractor<F, String> = F.extractor(for: field) {
        return string
    } else if let int: FormattingExtractor<F, Int> = F.extractor(for: field) {
        return {
            let val = int($0)
            let formatter = numberFormatters[qualifier]
            return formatter.string(from: val as NSNumber) ?? val.description
        }
    } else if let float: FormattingExtractor<F, Float> = F.extractor(for: field) {
        return {
            let val = float($0)
            let formatter = numberFormatters[qualifier]
            return formatter.string(from: val as NSNumber) ?? val.description
        }
    } else if let double: FormattingExtractor<F, Float> = F.extractor(for: field) {
        return {
            let val = double($0)
            let formatter = numberFormatters[qualifier]
            return formatter.string(from: val as NSNumber) ?? val.description
        }
    } else if let date: FormattingExtractor<F, Date> = F.extractor(for: field) {
        return { dateFormatters[qualifier].string(from: date($0)) }
    } else {
        return nil
    }
}

func extractor<F: Formattable>(for property: String) throws -> @Sendable (F) -> String {
    let parts = property.split(separator: "|", maxSplits: 1)
    let field: String
    let qualifier: String?
    if parts.count == 2, let first = parts.first, let last = parts.last {
        field = String(first)
        qualifier = String(last)
    } else if let first = parts.first {
        field = String(first)
        qualifier = nil
    } else {
        throw FormatError.invalidFormat
    }
    guard let extractor = anyExtractor(for: field, with: qualifier, on: F.self) else {
        throw FormatError.unknownField(field)
    }
    return extractor
}

fileprivate enum ParseState {
    case none
    case openBrace(Int)
    case inBrace(String)
    case closeBrace(String, Int)
}

fileprivate enum RenderStep<T: Sendable>: Sendable {
    case extract(@Sendable (T) -> String)
    case constant(String)
    
    func render(_ entry: T) -> String {
        switch self {
        case .extract(let extractor):
            return extractor(entry)
        case .constant(let string):
            return string
        }
    }
}

public func BuildFormatter<F: Formattable>(for type: F.Type, with format: String) throws -> FormattingRenderer<F> {
    var steps: [RenderStep<F>] = []
    var state: ParseState = .none
    for c in format {
        switch (c, state) {
        case ("{", .none):
            state = .openBrace(1)
        case ("{", .openBrace(1)):
            state = .openBrace(2)
        case ("{", .openBrace(2)):
            steps.append(.constant("{"))
            state = .openBrace(2)
        case ("{", .inBrace(let string)):
            steps.append(.constant("{{\(string){"))
            state = .none
        case ("{", .closeBrace(let string, let count)):
            steps.append(.constant("{{\(string)\(String(repeating: "}", count: count))"))
            state = .none
        case ("}", .none):
            steps.append(.constant("}"))
        case ("}", .openBrace(2)):
            throw FormatError.invalidFormat
        case ("}", .inBrace(let s)):
            state = .closeBrace(s, 1)
        case ("}", .closeBrace(let s, 1)):
            let extractor: @Sendable (F) -> String = try extractor(for: s)
            steps.append(.extract(extractor))
            state = .none
        case ("}", _):
            throw FormatError.invalidFormat
        case (_, .openBrace(2)):
            state = .inBrace(String(c))
        case (_, .inBrace(let s)):
            state = .inBrace(s + String(c))
        case (_, .none):
            steps.append(.constant(String(c)))
        case (_, .openBrace(1)):
            steps.append(.constant("{\(c)"))
            state = .none
        default:
            print("Invalid state: \(c) \(state)")
            throw FormatError.invalidFormat
        }
    }
    switch state {
    case .none:
        break
    case .openBrace(let count):
        steps.append(.constant(String(repeating: "{", count: count)))
    case .inBrace(let string):
        steps.append(.constant("{{\(string)"))
    case .closeBrace(let string, let count):
        steps.append(.constant("{{\(string)\(String(repeating: "}", count: count))"))
    }
    return { [steps] entry in
        var formatted = ""
        for step in steps {
            formatted.append(step.render(entry))
        }
        return formatted
    }
}
