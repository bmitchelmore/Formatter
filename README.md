## Formatter Library

This is a relatively simple library providing an api for building
functions that can take an arbitrary object and use specified
extractors with optional qualifiers to format a string
representation of the object

### Usage

```swift
struct Info {
    var title: String
    var count: Int
    var date: Date
}

extension Info: Formattable {
    static func extractor(for field: String) -> FormattingExtractor<String>? {
        switch field {
        case "title": \.title
        case "count": \.count.description
        default: nil
    }
    static func extractor(for field: String) -> FormattingExtractor<Date>? {
        switch field {
            case "date": \.date
            default: nil
        }
    }
}

let formatter: Formatter<Info> = BuildFormatter(with: "{{date}}: {{title}} ({{count}})")

```
