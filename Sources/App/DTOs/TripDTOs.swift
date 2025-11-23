import Vapor

// MARK: - Dashboard & Profile DTOs

struct DashboardPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileContext
    let stats: DriverStatsContext
    let recentTrips: [TripSummaryContext]
}

struct ProfilePageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileContext
}

struct DriverProfileContext: Content {
    let id: String
    let name: String
    let email: String
    let phone: String
    let license: String
    let address: String
}

struct DriverStatsContext: Content {
    let activeBids: Int
    let assignedTrips: Int
    let completedTrips: Int
    let earnings: String
}

// MARK: - Trip Management DTOs

struct AvailableTripsPageContext: Content {
    let title: String
    let pageType: String
    let trips: [TripSummaryContext]
    let driver: DriverProfileContext
}

struct TripSummaryContext: Content {
    let id: String
    let pickup: String
    let destination: String
    let distance: String?
    let suggestedPrice: Double?
    let status: String
    let bidAmount: Double?
    let scheduledTime: String?
}

struct TripDetailsPageContext: Content {
    let title: String
    let pageType: String
    let trip: DetailedTripContext
    let driver: DriverProfileContext
    let canBid: Bool
    let existingBid: BidContext?
}

struct DetailedTripContext: Content {
    let id: String
    let pickup: String
    let destination: String
    let distance: String?
    let suggestedPrice: Double?
    let status: String
    let clientName: String?
    let scheduledTime: String?
    let numberOfPassengers: Int
    let specialInstructions: String?
}

struct BidContext: Content {
    let amount: Double
    let isApproved: Bool
    let submittedAt: String
}

struct BidFormData: Content {
    let bidAmount: Double
}

struct MyBidsPageContext: Content {
    let title: String
    let pageType: String
    let bids: [BidSummaryContext]
    let driver: DriverProfileContext
}

struct BidSummaryContext: Content {
    let tripID: String
    let pickup: String
    let destination: String
    let bidAmount: Double
    let status: String
    let submittedAt: String
    let isApproved: Bool
}

struct AssignedTripsPageContext: Content {
    let title: String
    let pageType: String
    let trips: [AssignedTripContext]
    let driver: DriverProfileContext
}

struct AssignedTripContext: Content {
    let id: String
    let pickup: String
    let destination: String
    let status: String
    let scheduledTime: String
    let clientName: String
    let clientPhone: String?
    let canStart: Bool
    let canComplete: Bool
}
