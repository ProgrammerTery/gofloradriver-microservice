import Vapor
import Leaf
import DriversDTO

struct LandingController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let landingRoute = routes.grouped("products", "gofloradriver")
        
        // Landing Routes
        landingRoute.get(use: renderLandingPage)
        landingRoute.get("landing", use: renderLandingPage)
        
        // API endpoints for dynamic content
        landingRoute.get("api", "stats", use: getLiveStats)
        landingRoute.get("api", "testimonials", use: getTestimonials)
    }
    
    @Sendable func renderLandingPage(_ req: Request) async throws -> View {
        // Check if driver is already logged in
        if let driverToken = req.session.data["driverToken"], !driverToken.isEmpty {
            throw Abort.redirect(to: "/products/gofloradriver/dashboard")
        }
        
        let context = ModernLandingContext(
            title: "Drive with GoFlora - Your Journey to Success Starts Here",
            heroTitle: "Turn Your Vehicle Into Your Business",
            heroSubtitle: "Join thousands of drivers earning flexible income with GoFlora's premium transportation network",
            stats: LiveStatsContext(
                totalDrivers: "12,500+",
                avgEarnings: "$2,850",
                cities: "25+",
                satisfaction: "4.9★"
            ),
            features: getFeatures(),
            testimonials: getTestimonials(),
            earnings: getEarningsData()
        )
        
        return try await req.view.render("landing/modern-landing", context)
    }
    
    @Sendable func getLiveStats(_ req: Request) async throws -> LiveStatsContext {
        return LiveStatsContext(
            totalDrivers: "12,500+",
            avgEarnings: "$2,850",
            cities: "25+",
            satisfaction: "4.9★"
        )
    }
    
    @Sendable func getTestimonials(_ req: Request) async throws -> [TestimonialContext] {
        return getTestimonials()
    }
    
    private func getFeatures() -> [FeatureContext] {
        return [
            FeatureContext(
                icon: "💰",
                title: "Flexible Earnings",
                description: "Earn up to $3000/month on your schedule. Work when you want, where you want.",
                highlight: "Average $25/hour"
            ),
            FeatureContext(
                icon: "🚗",
                title: "Any Vehicle Welcome",
                description: "Cars, SUVs, vans, trucks - we have opportunities for every vehicle type.",
                highlight: "No vehicle restrictions"
            ),
            FeatureContext(
                icon: "📱",
                title: "Smart App Technology",
                description: "Advanced route optimization, instant payments, and 24/7 support.",
                highlight: "Real-time tracking"
            ),
            FeatureContext(
                icon: "🛡️",
                title: "Full Insurance Coverage",
                description: "Comprehensive coverage for you and your passengers during all trips.",
                highlight: "Zero liability"
            ),
            FeatureContext(
                icon: "⚡",
                title: "Instant Payments",
                description: "Get paid immediately after each trip. No waiting, no delays.",
                highlight: "Same-day payouts"
            ),
            FeatureContext(
                icon: "🎯",
                title: "Premium Customers",
                description: "Serve verified business clients and premium passengers.",
                highlight: "Higher tips guaranteed"
            )
        ]
    }
    
    private func getTestimonials() -> [TestimonialContext] {
        return [
            TestimonialContext(
                name: "Marcus Johnson",
                role: "Full-time Driver",
                image: "/images/drivers/marcus.jpg",
                rating: 5,
                text: "GoFlora changed my life. I'm earning 40% more than my previous job and have complete control over my schedule.",
                earnings: "$3,200/month",
                location: "New York"
            ),
            TestimonialContext(
                name: "Sarah Chen",
                role: "Part-time Driver",
                image: "/images/drivers/sarah.jpg",
                rating: 5,
                text: "Perfect for supplementing my income. The app is intuitive and customers are always respectful.",
                earnings: "$1,800/month",
                location: "San Francisco"
            ),
            TestimonialContext(
                name: "David Rodriguez",
                role: "Weekend Driver",
                image: "/images/drivers/david.jpg",
                rating: 5,
                text: "Great way to earn extra money on weekends. The premium customers always tip well.",
                earnings: "$800/month",
                location: "Austin"
            )
        ]
    }
    
    private func getEarningsData() -> EarningsContext {
        return EarningsContext(
            hourlyRange: "$18 - $35",
            weeklyPotential: "$450 - $1,200",
            monthlyPotential: "$1,800 - $4,800",
            bonusOpportunities: [
                "Peak hour bonuses: +50%",
                "Weekend premiums: +25%",
                "New driver bonus: $500",
                "Referral rewards: $200"
            ]
        )
    }
}

// MARK: - Context Models


