import Vapor
import Foundation

public struct PayNowPaymentMethodResponseDTO: Content, Sendable {
    public let id: UUID?
    public let name: String
    public let description: String?
    public let priority: Int
    public let isActive: Bool
    public let usMethods: [String]
    public let zwMethods: [String]
    public let serviceFeesSharing: Bool
    public let createdAt: Date?
    public let updatedAt: Date?
    
    public init(id: UUID?, name: String, description: String?, priority: Int, isActive: Bool, usMethods: [String], zwMethods: [String], serviceFeesSharing: Bool, createdAt: Date?, updatedAt: Date?) {
        self.id = id
        self.name = name
        self.description = description
        self.priority = priority
        self.isActive = isActive
        self.usMethods = usMethods
        self.zwMethods = zwMethods
        self.serviceFeesSharing = serviceFeesSharing
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
