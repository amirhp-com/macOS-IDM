import Foundation
import SwiftData

enum RoutingRuleType: String, Codable {
    case fileExtension
    case domain
}

@Model
final class RoutingRule {
    @Attribute(.unique) var id: UUID
    var order: Int
    var ruleType: String // RoutingRuleType raw value
    var pattern: String // ".dmg,.zip" or "github.com"
    var destinationFolder: String
    var segmentOverride: Int?
    var threadsOverride: Int?

    init(
        id: UUID = UUID(),
        order: Int,
        ruleType: RoutingRuleType,
        pattern: String,
        destinationFolder: String,
        segmentOverride: Int? = nil,
        threadsOverride: Int? = nil
    ) {
        self.id = id
        self.order = order
        self.ruleType = ruleType.rawValue
        self.pattern = pattern
        self.destinationFolder = destinationFolder
        self.segmentOverride = segmentOverride
        self.threadsOverride = threadsOverride
    }

    /// Check if a filename matches this routing rule.
    func matches(fileName: String, domain: String?) -> Bool {
        switch RoutingRuleType(rawValue: ruleType) {
        case .fileExtension:
            let extensions = pattern.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            let fileExt = "." + (fileName as NSString).pathExtension.lowercased()
            return extensions.contains(fileExt)
        case .domain:
            return domain?.lowercased().contains(pattern.lowercased()) ?? false
        case nil:
            return false
        }
    }
}
