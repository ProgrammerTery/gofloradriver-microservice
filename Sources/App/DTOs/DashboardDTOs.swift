import Vapor
import DriversDTO

// MARK: - Dashboard Page Context

struct DashboardPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO
    let stats: DashboardStatsContext
    let recentTrips: [RecentTripContext]
}

struct DashboardStatsContext: Content {
    let activeBids: Int
    let assignedTrips: Int
    let earningsToday: String
    let totalEarnings: String
    let completedTrips: Int
    let averageRating: String
    let successRate: Int
    let weeklyTrips: Int
    let weeklyHours: Int
    let weeklyEarnings: String
    let availableTrips: Int
}

struct RecentTripContext: Content {
    let id: String
    let pickup: String
    let destination: String
    let distance: String
    let suggestedPrice: Double
    let amount: String?
    let date: String?
    let scheduledTime: String
}

// MARK: - Other Page Contexts

struct WelcomePageContext: Content {
    let title: String
    let pageType: String
}

struct JoinDriverPageContext: Content {
    let title: String
    let pageType: String
}

struct SignupPageContext: Content {
    let title: String
    let pageType: String
    let errorMessage: String?
}

struct DriverStatsContext: Content {
    let activeBids: Int
    let assignedTrips: Int
    let completedTrips: Int
    let earnings: String
}

struct TripSummaryContext: Content {
    let id: String
    let pickup: String
    let destination: String
    let distance: String
    let suggestedPrice: Double
    let status: String
    let bidAmount: Double?
    let scheduledTime: String
    let date: String?
    let amount: String?
}


struct AvailableTripsPageContext: Content {
     let title: String
     let pageType: String
     let trips: [TripSummaryContext]
     let driver: DriverProfileDTO

     init(title: String, pageType: String, trips: [TripSummaryContext], driver: DriverProfileDTO) {
        self.title = title
        self.pageType = pageType
        self.trips = trips
        self.driver = driver
    }
}
