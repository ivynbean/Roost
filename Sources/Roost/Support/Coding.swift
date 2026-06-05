import Foundation

extension JSONEncoder {
    static var roost: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var roost: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension String {
    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }

    func firstLine(maxLength: Int) -> String {
        let line = split(whereSeparator: \.isNewline).first.map(String.init) ?? self
        guard line.count > maxLength else { return line }
        let index = line.index(line.startIndex, offsetBy: maxLength)
        return String(line[..<index]) + "..."
    }
}
