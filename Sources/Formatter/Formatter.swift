//
//  Formatter.swift
//  Formatter
//
//  Created by Blair Mitchelmore on 2025-07-31.
//

import Foundation
import os

public enum FormatError: Error, Equatable {
    case invalidFormat
    case unknownField(String)
}

extension Character {
    fileprivate var isFormatTag: Bool {
        switch self {
        case "A"..."Z", "a"..."z", "_", ".":
            true
        default:
            false
        }
    }
}

public typealias FormattingRenderer<I> = (I) -> String
public typealias FormattingExtractor<I, V> = (I) -> V

public protocol Formattable {
    static func extractor(for field: String) -> FormattingExtractor<Self, String>?
    static func extractor(for field: String) -> FormattingExtractor<Self, Int>?
    static func extractor(for field: String) -> FormattingExtractor<Self, Date>?
    static func extractor(for field: String) -> FormattingExtractor<Self, Float>?
    static func extractor(for field: String) -> FormattingExtractor<Self, Double>?
}

extension Formattable {
    public static func extractor(for field: String) -> FormattingExtractor<Self, String>? {
        nil
    }
    public static func extractor(for field: String) -> FormattingExtractor<Self, Int>? {
        nil
    }
    public static func extractor(for field: String) -> FormattingExtractor<Self, Date>? {
        nil
    }
    public static func extractor(for field: String) -> FormattingExtractor<Self, Float>? {
        nil
    }
    public static func extractor(for field: String) -> FormattingExtractor<Self, Double>? {
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

func extractor<F: Formattable>(for field: String, qualifier: String? = nil) throws(FormatError) -> (F) -> String {
    guard let extractor = anyExtractor(for: field, with: qualifier, on: F.self) else {
        throw FormatError.unknownField(field)
    }
    return extractor
}

fileprivate indirect enum ParseState {
    case none
    case escaping(ParseState)
    case readingConstant(String)
    case readingTag(String)
    case readingQualifier(String, String)
}

fileprivate enum RenderStep<T> {
    case extract((T) -> String)
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

public func BuildFormatter<F: Formattable>(for type: F.Type, with format: String) throws(FormatError) -> FormattingRenderer<F> {
    var steps: [RenderStep<F>] = []
    var state: ParseState = .none
    let escape: Character = "\\"
    let prefix: Character = "$"
    let qualifierStart: Character = "["
    let qualifierEnd: Character = "]"
    for c in format {
        switch (c, state) {
        case (_, .escaping(let previousState)):
            switch previousState {
            case .escaping, .none:
                state = .readingConstant(String(c))
            case .readingConstant(let content):
                state = .readingConstant(content.appending(String(c)))
            case .readingTag:
                throw .invalidFormat
            case .readingQualifier(let field, let qualifier):
                state = .readingQualifier(field, qualifier.appending(String(c)))
            }
        case (escape, .none):
            state = .escaping(.none)
        case (escape, .readingConstant(let content)):
            state = .escaping(.readingConstant(content))
        case (escape, .readingQualifier(let field, let qualifier)):
            state = .escaping(.readingQualifier(field, qualifier))
        case (escape, .readingTag(let field)):
            try steps.append(.extract(extractor(for: field)))
            state = .escaping(.none)
        case (prefix, .none):
            state = .readingTag("")
        case (prefix, .readingTag("")):
            steps.append(.constant(String(prefix)))
            state = .readingTag("")
        case (prefix, .readingTag(let field)):
            try steps.append(.extract(extractor(for: field)))
            state = .readingTag("")
        case (prefix, .readingConstant(let value)):
            steps.append(.constant(value))
            state = .readingTag("")
        case (prefix, .readingQualifier(let field, let qualifier)):
            state = .readingQualifier(field, qualifier.appending(String(prefix)))
        case (qualifierStart, .none):
            state = .readingConstant(String(qualifierStart))
        case (qualifierStart, .readingConstant(let content)):
            state = .readingConstant(content.appending(String(qualifierStart)))
        case (qualifierStart, .readingQualifier):
            throw .invalidFormat
        case (qualifierStart, .readingTag("")):
            state = .readingConstant(String(prefix).appending(String(qualifierStart)))
        case (qualifierStart, .readingTag(let field)):
            state = .readingQualifier(field, "")
        case (qualifierEnd, .none):
            state = .readingConstant(String(qualifierStart))
        case (qualifierEnd, .readingConstant(let content)):
            state = .readingConstant(content.appending(String(qualifierEnd)))
        case (qualifierEnd, .readingTag("")):
            state = .readingConstant(String(prefix).appending(String(qualifierEnd)))
        case (qualifierEnd, .readingTag(let field)):
            try steps.append(.extract(extractor(for: field)))
            state = .readingConstant(String(qualifierEnd))
        case (qualifierEnd, .readingQualifier(let field, let qualifier)):
            try steps.append(.extract(extractor(for: field, qualifier: qualifier)))
            state = .readingConstant("")
        case (_, .readingTag("")) where !c.isFormatTag:
            steps.append(.constant(String(prefix)))
            state = .readingConstant(String(c))
        case (_, .readingTag(let field)) where !c.isFormatTag:
            try steps.append(.extract(extractor(for: field)))
            state = .readingConstant(String(c))
        case (_, .none):
            state = .readingConstant(String(c))
        case (_, .readingTag(let field)):
            state = .readingTag(field.appending(String(c)))
        case (_, .readingConstant(let value)):
            state = .readingConstant(value.appending(String(c)))
        case (_, .readingQualifier(let field, let qualifier)):
            state = .readingQualifier(field, qualifier.appending(String(c)))
        }
    }
    switch state {
    case .none:
        break
    case .escaping(let previousState):
        switch previousState {
        case .none:
            break
        case .escaping:
            break
        case .readingConstant(let content):
            steps.append(.constant(content))
        case .readingTag(let field):
            try steps.append(.extract(extractor(for: field)))
        case .readingQualifier(let field, let qualifier):
            try steps.append(.extract(extractor(for: field)))
            steps.append(.constant(String(qualifierStart) + qualifier))
        }
    case .readingConstant(let content):
        steps.append(.constant(content))
    case .readingTag(""):
        steps.append(.constant(String(prefix)))
    case .readingTag(let field):
        try steps.append(.extract(extractor(for: field)))
    case .readingQualifier(let field, let qualifier):
        try steps.append(.extract(extractor(for: field)))
        steps.append(.constant(String(qualifierStart) + qualifier))
    }
    return { [steps] entry in
        var formatted = ""
        for step in steps {
            formatted.append(step.render(entry))
        }
        return formatted
    }
}
