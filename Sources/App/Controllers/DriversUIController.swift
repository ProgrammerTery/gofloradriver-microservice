import Vapor
import Leaf
import DriversDTO

struct DriversUIController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let driversUIRoute = routes.grouped("products", "gofloradriver")

        // Landing & Onboarding Routes (Public)
        driversUIRoute.get(use: renderWelcome)
        driversUIRoute.get("welcome", use: renderWelcome)
        driversUIRoute.get("join", use: renderJoinDriver)
        driversUIRoute.get("signup", use: renderSignup)
        driversUIRoute.post("signup", use: handleSignup)

        // Driver Registration Routes
        driversUIRoute.get("register", use: renderDriverRegistration)
        driversUIRoute.post("register", use: handleDriverRegistration)
        driversUIRoute.get("vehicle-choice", use: renderVehicleChoice)
        driversUIRoute.post("vehicle-choice", use: handleVehicleChoice)

        // Success Route
        driversUIRoute.get("success", use: renderRegistrationSuccess)

        // Protected Routes (require driver session)
        let protectedRoutes = driversUIRoute.grouped(DriverAuthMiddleware())
        protectedRoutes.get("dashboard", use: renderDashboard)
        protectedRoutes.get("profile", use: renderProfile)
        protectedRoutes.get("logout", use: handleLogout)
    }

    // MARK: - Landing & Join Flow

    @Sendable func renderWelcome(_ req: Request) async throws -> View {
        let context = WelcomePageContext(
            title: "Welcome to GoFlora Driver",
            pageType: "landing"
        )
        return try await req.view.render("drivers/landing/welcome", context)
    }

    @Sendable func renderJoinDriver(_ req: Request) async throws -> View {
        let context = JoinDriverPageContext(
            title: "Join GoFlora as a Driver",
            pageType: "landing"
        )
        return try await req.view.render("drivers/landing/join-driver", context)
    }

    // MARK: - Signup Flow

    @Sendable func renderSignup(_ req: Request) async throws -> View {
        let context = SignupPageContext(
            title: "Driver Signup",
            pageType: "auth",
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/auth/signup", context)
    }

    @Sendable func handleSignup(_ req: Request) async throws -> Response {
        let signupData = try req.content.decode(DriverDTO.self)
        // Validate passwords match
        guard signupData.password == signupData.confirmPassword else {
            return req.redirect(to: "/products/gofloradriver/signup?error=Passwords do not match")
        }

        let jsonData = try JSONEncoder().encode(signupData)
        let buffer = req.application.allocator.buffer(data: jsonData)

        // Call the UnsecuredDriversController API for account creation
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: (APIConfig.endpoints["gofloradriver"] ?? "urlfailed") + "/signup",
                body: buffer)

            if response.status == .created || response.status == .ok {
                // Store email in session for next step
                req.session.data["signupEmail"] = signupData.email
                return req.redirect(to: "/products/gofloradriver/register")
            } else {
                let errorData = try response.content.decode([String: String].self)
                let error = errorData["message"] ?? "Signup failed"
                return req.redirect(to: "/products/gofloradriver/signup?error=\(error)")
            }
        } catch {
            return req.redirect(to: "/products/gofloradriver/signup?error=Network error. Please try again.")
        }
    }

    // MARK: - Driver Registration Flow

    @Sendable func renderDriverRegistration(_ req: Request) async throws -> View {
        let email = req.session.data["signupEmail"] ?? ""
        let context = DriverRegistrationPageContext(
            title: "Driver Registration",
            pageType: "auth",
            errorMessage: req.query["error"],
            prefillData: DriverRegistrationFormData(
                driverID: "",
                driverName: "",
                driverPhone: "",
                driverEmail: email,
                driverAddress: "",
                driverLicense: ""
            )
        )
        return try await req.view.render("drivers/auth/driver-registration", context)
    }

    @Sendable func handleDriverRegistration(_ req: Request) async throws -> Response {
        let registrationData = try req.content.decode(DriverRegistrationFormData.self)


        let jsonData = try JSONEncoder().encode(registrationData)
        let driverData = req.application.allocator.buffer(data: jsonData)

        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["unsecuredDrivers"]! + "/register",
                body: driverData
            )

            if response.status == .created || response.status == .ok {
                // Store driver data in session
                req.session.data["driverID"] = registrationData.driverID
                req.session.data["driverName"] = registrationData.driverName
                req.session.data["driverEmail"] = registrationData.driverEmail

                return req.redirect(to: "/products/gofloradriver/vehicle-choice")
            } else {
                let errorData = try response.content.decode([String: String].self)
                let error = errorData["message"] ?? "Registration failed"
                return req.redirect(to: "/products/gofloradriver/register?error=\(error)")
            }
        } catch {
            return req.redirect(to: "/products/gofloradriver/register?error=Network error. Please try again.")
        }
    }

    // MARK: - Vehicle Choice Flow

    @Sendable func renderVehicleChoice(_ req: Request) async throws -> View {
        guard let driverID = req.session.data["driverID"],
              let driverName = req.session.data["driverName"] else {
            throw Abort(.badRequest, reason: "Driver session not found. Please register first.")
        }

        let context = VehicleChoicePageContext(
            title: "Vehicle Registration",
            pageType: "auth",
            driverID: driverID,
            driverName: driverName
        )
        return try await req.view.render("drivers/auth/vehicle-choice", context)
    }

    @Sendable func handleVehicleChoice(_ req: Request) async throws -> Response {
        let choiceData = try req.content.decode(VehicleChoiceFormData.self)

        if choiceData.registerVehicleNow {
            return req.redirect(to: "/products/gofloradriver/vehicle/service-type")
        } else {
            return req.redirect(to: "/products/gofloradriver/success")
        }
    }

    // MARK: - Success Page

    @Sendable func renderRegistrationSuccess(_ req: Request) async throws -> View {
        guard let driverName = req.session.data["driverName"] else {
            throw Abort(.badRequest, reason: "Driver session not found. Please register first.")
        }

        let hasVehicle = req.session.data["hasVehicle"] == "true"
        let nextStepURL = hasVehicle ? "/products/gofloradriver/dashboard" : "/products/gofloradriver/vehicle/service-type"

        let context = RegistrationSuccessContext(
            title: "Registration Successful",
            pageType: "success",
            driverName: driverName,
            hasVehicle: hasVehicle,
            nextStepURL: nextStepURL
        )
        return try await req.view.render("drivers/auth/registration-success", context)
    }

    // MARK: - Protected Routes

    @Sendable func renderDashboard(_ req: Request) async throws -> View {
        let driverProfile = try await fetchDriverProfile(req)
        let stats = try await fetchDriverStats(req)
        let recentTrips = try await fetchRecentTrips(req)

        let context = DashboardPageContext(
            title: "Driver Dashboard",
            pageType: "dashboard",
            driver: driverProfile,
            stats: stats,
            recentTrips: recentTrips
        )
        return try await req.view.render("drivers/dashboard/dashboard", context)
    }

    @Sendable func renderProfile(_ req: Request) async throws -> View {
        let driverProfile = try await fetchDriverProfile(req)

        let context = ProfilePageContext(
            title: "Driver Profile",
            pageType: "profile",
            driver: driverProfile
        )
        return try await req.view.render("drivers/dashboard/profile", context)
    }

    @Sendable func handleLogout(_ req: Request) async throws -> Response {
        req.session.destroy()
        return req.redirect(to: "/products/gofloradriver/welcome")
    }

    // MARK: - Helper Methods

    private func makeAPIRequest(req: Request, method: HTTPMethod, endpoint: String,  body: ByteBuffer? = nil) async throws -> ClientResponse {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        let clientRequest = ClientRequest(
            method: method,
            url: URI(string: endpoint),
            headers: headers,
            body: body
        )

        return try await req.client.send(clientRequest)
    }

    private func fetchDriverProfile(_ req: Request) async throws -> DriverProfileContext {
        // Mock data - in real implementation, call API with session token
        return DriverProfileContext(
            id: req.session.data["driverID"] ?? "unknown",
            name: req.session.data["driverName"] ?? "Unknown Driver",
            email: req.session.data["driverEmail"] ?? "",
            phone: "+1234567890",
            license: "DL123456",
            address: "123 Driver St"
        )
    }

    private func fetchDriverStats(_ req: Request) async throws -> DriverStatsContext {
        return DriverStatsContext(
            activeBids: 3,
            assignedTrips: 1,
            completedTrips: 15,
            earnings: "$1,250.00"
        )
    }

    private func fetchRecentTrips(_ req: Request) async throws -> [TripSummaryContext] {
        return [
            TripSummaryContext(
                id: "trip-1",
                pickup: "Downtown Mall",
                destination: "Airport",
                distance: "15 miles",
                suggestedPrice: 45.00,
                status: "pending",
                bidAmount: nil,
                scheduledTime: "2025-01-28 14:30"
            )
        ]
    }
}

// Simple auth middleware for session checking
struct DriverAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if request.session.data["driverID"] != nil {
            return try await next.respond(to: request)
        } else {
            return request.redirect(to: "/products/gofloradriver/signup")
        }
    }
}
