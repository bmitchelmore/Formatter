import Testing
import Foundation
@testable import Formatter

struct Info {
    var title: String
    var count: Int
    var date: Date
}

extension Info: Formattable {
    static func extractor(for field: String) -> FormattingExtractor<Info, String>? {
        switch field {
        case "title": \.title
        case "count": \.count.description
        default: nil
        }
    }
    static func extractor(for field: String) -> FormattingExtractor<Info, Date>? {
        switch field {
            case "date": \.date
            default: nil
        }
    }
}

func buildFormatter(with format: String) throws -> FormattingRenderer<Info> {
    return try BuildFormatter(for: Info.self, with: format)
}

let info = Info(
    title: "hello",
    count: 5,
    date: .distantPast
)

@Test func simpleFormat() async throws {
    let formatter = try buildFormatter(with: "{{date|y}}: {{title}} ({{count}})")
    
    #expect(formatter(info) == "1: hello (5)", "Format should match")
}

@Test func extraBraceEarly() throws {
    let formatter = try buildFormatter(with: "{{{date|y}} {{title}}")
    
    #expect(formatter(info) == "{1 hello", "Format should match")
}

@Test func extraBraceLate() throws {
    let formatter = try buildFormatter(with: "{{date|y}}} {{title}}")
    
    #expect(formatter(info) == "1} hello", "Format should match")
}

@Test func singleBrace() throws {
    let formatter = try buildFormatter(with: "{date} {{title}}")
    #expect(formatter(info) == "{date} hello", "Format should match")
}

@Test func extraCurlyBraces() throws {
    let formatter = try buildFormatter(with: "{hello} {{title}} } something {")
    #expect(formatter(info) == "{hello} hello } something {", "Format should match")
}

@Test func emptyProperty() throws {
    do {
        _ = try buildFormatter(with: "{{}}")
    } catch FormatError.invalidFormat {
        
    }
}


@Test func unknownProperty() throws {
    do {
        _ = try buildFormatter(with: "{{jumbo}}")
    } catch FormatError.unknownField("jumbo") {
        
    }
}
