import Foundation
import NaturalLanguage

enum WikilinkGenerator {
    static func extractLinks(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var names: Set<String> = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            guard let tag = tag else { return true }
            if tag == .personalName || tag == .organizationName || tag == .placeName {
                let name = String(text[range]).trimmingCharacters(in: .whitespaces)
                if name.count >= 2 {
                    names.insert(name)
                }
            }
            return true
        }

        return Array(names).sorted()
    }

    static func applyWikilinks(to text: String, links: [String]) -> String {
        var result = text
        let sortedLinks = links.sorted { $0.count > $1.count }

        for link in sortedLinks {
            let alreadyLinked = "[[\(link)]]"
            if result.contains(alreadyLinked) { continue }
            result = result.replacingOccurrences(of: link, with: alreadyLinked)
        }

        return result
    }
}
