import Foundation
import OSLog

final class TagStore: ObservableObject {
    @Published var tags: [Tag] = [] {
        didSet { scheduleSave() }
    }

    private let logger = Logger(subsystem: "com.ivynbean.Roost", category: "tags")
    private let tagsURL: URL
    private var saveTask: Task<Void, Never>?

    init(directory: URL? = nil) {
        let support: URL
        if let directory {
            support = directory
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            support = applicationSupport.appendingPathComponent("Roost", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        tagsURL = support.appendingPathComponent("tags.json")
        load()
    }

    func tag(for id: UUID) -> Tag? {
        tags.first { $0.id == id }
    }

    @discardableResult
    func findOrCreate(named name: String) -> Tag? {
        let normalized = Self.normalizedName(name)
        guard !normalized.isEmpty else { return nil }

        if let existing = tags.first(where: { $0.name.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            return existing
        }

        let tag = Tag(name: normalized, colorIndex: tags.count)
        tags.append(tag)
        logger.info("Created tag id=\(tag.id.uuidString, privacy: .public)")
        return tag
    }

    func rename(_ id: Tag.ID, to name: String) {
        let normalized = Self.normalizedName(name)
        guard !normalized.isEmpty,
              let index = tags.firstIndex(where: { $0.id == id }) else { return }
        tags[index].name = normalized
    }

    func delete(_ id: Tag.ID) {
        tags.removeAll { $0.id == id }
    }

    func projectTag(named projectName: String) -> Tag? {
        findOrCreate(named: projectName)
    }

    func tagIDs(in text: String) -> [UUID] {
        Self.tagNames(in: text).compactMap { findOrCreate(named: $0)?.id }
    }

    static func normalizedName(_ name: String) -> String {
        let trimmed = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .lowercased()

        guard let regex = try? NSRegularExpression(pattern: #"[^a-z0-9_-]+"#) else {
            return trimmed.replacingOccurrences(of: " ", with: "-")
        }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let slug = regex.stringByReplacingMatches(in: trimmed, range: range, withTemplate: "-")
            .replacingOccurrences(of: #"-+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))

        return slug
    }

    static func tagNames(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\w)#([\p{L}\p{N}_-]+)"#) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var names: [String] = []
        for match in regex.matches(in: text, range: range) {
            guard match.numberOfRanges > 1,
                  let tagRange = Range(match.range(at: 1), in: text) else { continue }
            let name = normalizedName(String(text[tagRange]))
            if !name.isEmpty,
               !names.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }
        return names
    }

    private func load() {
        guard let data = try? Data(contentsOf: tagsURL) else { return }
        do {
            tags = try JSONDecoder.roost.decode([Tag].self, from: data)
        } catch {
            logger.error("Failed to load tags: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let tags = tags
        let tagsURL = tagsURL
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                try JSONEncoder.roost.encode(tags).write(to: tagsURL, options: .atomic)
            } catch {
                Logger(subsystem: "com.ivynbean.Roost", category: "persistence")
                    .error("Failed to save tags: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
