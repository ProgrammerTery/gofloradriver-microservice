import Vapor
import Leaf
import DriversDTO
import SharedModels

struct DriversUIController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let driversUIRoute = routes.grouped("products", "gofloradriver")

        // Landing & Onboarding Routes (Public)
        //  driversUIRoute.get(use: renderWelcome)
        driversUIRoute.get("welcome") { req in
            req.redirect(to: "/products/gofloradriver/landing")
        }
        driversUIRoute.get("join", use: renderJoinDriver)
        driversUIRoute.get("signup", use: renderSignup)
        driversUIRoute.post("signup", use: handleSignup)

        driversUIRoute.get("login", use: renderLogin)
        driversUIRoute.post("login", use: handleLogin)

        // Driver Registration Routes
        driversUIRoute.get("register", use: renderDriverRegistration)
        driversUIRoute.post("register", use: handleDriverRegistration)
        driversUIRoute.post("register", "skip", use: handleSkipRegistration)
        driversUIRoute.get("vehicle-choice", use: renderVehicleChoice)
        driversUIRoute.post("vehicle-choice", use: handleVehicleChoice)

        // Success Route
        driversUIRoute.get("success", use: renderRegistrationSuccess)

        // Protected Routes (require driver session)
        let protectedRoutes = driversUIRoute.grouped(DriverAuthMiddleware())
        protectedRoutes.get("dashboard", use: renderDashboard)
        protectedRoutes.get("profile", use: renderProfile)
        protectedRoutes.get("profile", "edit", use: renderEditProfile)
        protectedRoutes.post("profile", "edit", use: handleProfileUpdate)
        protectedRoutes.get("logout", use: handleLogout)
    }

    // MARK: - Landing & Join Flow

    @Sendable func renderWelcome(_ req: Request) async throws -> View {
        // Check if driver is already logged in
        if let driverToken = req.session.data["driverToken"], !driverToken.isEmpty {
            // User is already authenticated, redirect to dashboard
            throw Abort.redirect(to: "/products/gofloradriver/dashboard")
        }

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

            // lets extract useful info returned after a successful signup

            let driverResponse = try response.content.decode(DriverDTOResponseModel.self)

            //lets store the token in session
            req.session.data["driverToken"] = driverResponse.token
            req.session.data["email"] = driverResponse.email
            req.session.data["name"] = driverResponse.name

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
            return req.redirect(to: "/products/gofloradriver/signup?error=Something went wrong. Please try again.")
        }
    }

    // MARK: - Login Flow

    @Sendable func renderLogin(_ req: Request) async throws -> View {
        // Check if driver is already logged in
        if let driverToken = req.session.data["driverToken"], !driverToken.isEmpty {
            // User is already authenticated, redirect to dashboard
            throw Abort.redirect(to: "/products/gofloradriver/dashboard")
        }

        let context = LoginPageContext(
            title: "Driver Login",
            pageType: "auth",
            errorMessage: req.query["error"],
            prefillEmail: req.query["email"]
        )
        return try await req.view.render("drivers/auth/login", context)
    }

    @Sendable func handleLogin(_ req: Request) async throws -> Response {
        let loginData = try req.content.decode(SignInRequest.self)

        let jsonData = try JSONEncoder().encode(loginData)
        let buffer = req.application.allocator.buffer(data: jsonData)

        // Call the UnsecuredDriversController API for authentication
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: (APIConfig.endpoints["gofloradriver"] ?? "urlfailed") + "/login",
                body: buffer
            )

            if response.status == .ok {
                // Extract driver info from response
                let driverResponse = try response.content.decode(DriverDTOResponseModel.self)

                // Store session data
                req.session.data["driverToken"] = driverResponse.token
                req.session.data["email"] = driverResponse.email
                req.session.data["name"] = driverResponse.name
                req.session.data["driverID"] =  "Implementing Soon" //Call API to get driver ID
                // req.session.data["driverID"] = driverResponse.driverID ?? ""

                // Set remember me if requested (extends session duration)
                if let rememberMe = try? req.content.get(String.self, at: "rememberMe"), rememberMe == "true" {
                    req.session.data["rememberMe"] = "true"
                }

                // Check if user has completed registration
                if  !driverResponse.email.isEmpty {
                    // User has completed driver registration, go to dashboard
                    return req.redirect(to: "/products/gofloradriver/dashboard")
                } else {
                    // User hasn't completed driver registration, redirect to registration
                    return req.redirect(to: "/products/gofloradriver/register")
                }
            } else {
                let errorData = try response.content.decode([String: String].self)
                let error = errorData["message"] ?? "Invalid email or password"
                return req.redirect(to: "/products/gofloradriver/login?error=\(error)&email=\(loginData.username)")
            }
        } catch {
            print("Login error: \(error)")
            return req.redirect(to: "/products/gofloradriver/login?error=Network error. Please try again.&email=\(loginData.username)")
        }
    }

    // MARK: - Driver Registration Flow

    @Sendable func renderDriverRegistration(_ req: Request) async throws -> View {
        let email = req.session.data["email"] ?? ""
        let name = req.session.data["name"] ?? ""

        let context = DriverRegistrationPageContext(
            title: "Driver Registration",
            pageType: "auth",
            errorMessage: req.query["error"],
            prefillData: DriverProfileDTO(
                driverID: "",
                driverName: name,
                driverPhone: "",
                driverEmail: email,
                driverAddress: "",
                registrationDate: Date(),
                driverLicense: "",
                vehicle_id: nil
            )
        )
        return try await req.view.render("drivers/auth/driver-registration", context)
    }

    @Sendable func handleDriverRegistration(_ req: Request) async throws -> Response {
        let registrationData = try req.content.decode(DriverProfileDTO.self)


        let jsonData = try JSONEncoder().encode(registrationData)
        let driverData = req.application.allocator.buffer(data: jsonData)
        // Call the DriverProfilesController API for registration
        let driverToken = req.session.data["driverToken"]

        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["driver-profiles"]! + "/register",
                body: driverData,
                driverToken: driverToken
            )

            if response.status == .created || response.status == .ok {
                // Store driver data in session
                req.session.data["driverID"] = registrationData.driverID
                req.session.data["name"] = registrationData.driverName
                req.session.data["email"] = registrationData.driverEmail

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
              let driverName = req.session.data["name"] else {
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
        guard let driverName = req.session.data["name"] else {
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

    // MARK: - Skip Registration

    @Sendable func handleSkipRegistration(_ req: Request) async throws -> Response {
        // Mark profile as incomplete in session
        req.session.data["profileIncomplete"] = "true"
        req.session.data["skipRegistration"] = "true"

        // Store minimal driver info if not already present
        if req.session.data["driverID"] == nil {
            req.session.data["driverID"] = UUID().uuidString
            req.session.data["name"] = "Driver \(Int.random(in: 1000...9999))"
            req.session.data["email"] = req.session.data["email"] ?? "temp@example.com"
        }

        // Redirect to dashboard with incomplete profile flag
        return req.redirect(to: "/products/gofloradriver/dashboard")
    }

    // MARK: - Protected Routes

    @Sendable func renderDashboard(_ req: Request) async throws -> View {
        let driverProfile = try await fetchDriverProfile(req)
        let stats = try await fetchDriverStats(req)
        let recentTrips = try await fetchRecentTrips(req)

        // Check if profile is incomplete (from skip registration)
        let profileIncomplete = req.session.data["profileIncomplete"] == "true"

        let context = DriversDashboardPageContext(
            title: "Driver Dashboard",
            pageType: "dashboard",
            driver: driverProfile,
            stats: stats,
            recentTrips: recentTrips,
            profileIncomplete: profileIncomplete
        )
        return try await req.view.render("drivers/dashboard/dashboard", context)
    }

    @Sendable func renderProfile(_ req: Request) async throws -> View {
        let driverProfile = try await fetchDriverProfile(req)
        let stats = try await fetchDriverStats(req)

        let context = ProfilePageContext(
            title: "Driver Profile",
            pageType: "profile",
            driver: driverProfile,
            stats: stats,
            successMessage: req.query["success"],
            errorMessage: req.query["error"],
            initial: String(driverProfile.driverName.prefix(1))
        )
        return try await req.view.render("drivers/dashboard/profile", context)
    }

    @Sendable func renderEditProfile(_ req: Request) async throws -> View {
        let driverProfile = try await fetchDriverProfile(req)

        let context = EditProfilePageContext(
            title: "Edit Profile",
            pageType: "profile",
            driver: driverProfile,
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/dashboard/edit-profile", context)
    }

    @Sendable func handleProfileUpdate(_ req: Request) async throws -> Response {
        let updateData = try req.content.decode(ProfileUpdateFormData.self)
        let driverToken = req.session.data["driverToken"]

        // Validate phone number format (basic validation)
        if !updateData.driverPhone.isEmpty && updateData.driverPhone.count < 10 {
            return req.redirect(to: "/products/gofloradriver/profile/edit?error=Invalid phone number format")
        }

        let jsonData = try JSONEncoder().encode(updateData)
        let buffer = req.application.allocator.buffer(data: jsonData)

        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .PATCH,
                endpoint: APIConfig.endpoints["gofloradriver-profiles"]! + "/update",
                body: buffer,
                driverToken: driverToken
            )

            if response.status == .ok {
                // Update session data with new values
                req.session.data["name"] = updateData.driverName
                req.session.data["email"] = updateData.driverEmail

                return req.redirect(to: "/products/gofloradriver/profile?success=Profile updated successfully")
            } else {
                let errorData = try response.content.decode([String: String].self)
                let error = errorData["message"] ?? "Failed to update profile"
                return req.redirect(to: "/products/gofloradriver/profile/edit?error=\(error)")
            }
        } catch {
            return req.redirect(to: "/products/gofloradriver/profile/edit?error=Network error. Please try again.")
        }
    }

    @Sendable func handleLogout(_ req: Request) async throws -> Response {
        req.session.destroy()
        return req.redirect(to: "/products/gofloradriver/welcome")
    }

    // MARK: - Helper Methods

    private func makeAPIRequest(req: Request, method: HTTPMethod, endpoint: String,  body: ByteBuffer? = nil, driverToken: String? = nil) async throws -> ClientResponse {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        if let token = driverToken {
            headers.add(name: .authorization, value: "Bearer \(token)")
        }

        let clientRequest = ClientRequest(
            method: method,
            url: URI(string: endpoint),
            headers: headers,
            body: body
        )

        return try await req.client.send(clientRequest)
    }

    private func fetchDriverProfile(_ req: Request) async throws -> DriverProfileDTO {
        // Mock data - in real implementation, call API with session token
        return DriverProfileDTO(driverID:  req.session.data["driverID"] ?? "unknown", driverName: req.session.data["name"] ?? "Unknown Driver", driverPhone: "+263778463020", driverEmail: "waltack@example.com", driverAddress: "Victoria Falls City", registrationDate: Date(), driverLicense: "AQW5363783", vehicle_id: UUID())
    }

    private func fetchDriverStats(_ req: Request) async throws -> DriversDriverStatsContext {
        // In a real implementation, these would come from API calls
        return DriversDriverStatsContext(
            totalEarnings: "4250.00",
            totalTrips: "125",
            averageRating: "4.9",
            thisWeekTrips: "8",
            activeBids: "3",
            assignedTrips: "2",
            earningsToday: "145.50",
            completedTrips: "123",
            successRate: "98",
            weeklyTrips: "8",
            weeklyEarnings: "580.00",
            weeklyHours: "24",
            availableTrips: "12",
            // Revenue Trajectory Properties
            monthlyEarnings: "3450.00",
            monthlyGrowth: "18",
            monthlyGoal: "3000.00",
            goalProgress: "115",
            goalExceeded: "25",
            avgTripEarnings: "32",
            daysLeft: "6"
        )
    }

    private func fetchRecentTrips(_ req: Request) async throws -> [DriversTripSummaryContext] {
        // In a real implementation, this would come from API calls
        return [
            DriversTripSummaryContext(
                id: "trip-001",
                pickup: "Downtown Mall",
                destination: "Airport Terminal 1",
                distance: "15.2 miles",
                suggestedPrice: 45.00,
                status: "completed",
                bidAmount: 42.00,
                scheduledTime: "2025-01-28 14:30",
                date: "Jan 28, 2025",
                amount: "42.00"
            ),
            DriversTripSummaryContext(
                id: "trip-002",
                pickup: "Business District",
                destination: "Hotel Plaza",
                distance: "8.5 miles",
                suggestedPrice: 25.00,
                status: "completed",
                bidAmount: 28.00,
                scheduledTime: "2025-01-28 16:00",
                date: "Jan 28, 2025",
                amount: "28.00"
            ),
            DriversTripSummaryContext(
                id: "trip-003",
                pickup: "Train Station",
                destination: "University Campus",
                distance: "12.1 miles",
                suggestedPrice: 35.00,
                status: "completed",
                bidAmount: 35.00,
                scheduledTime: "2025-01-27 09:15",
                date: "Jan 27, 2025",
                amount: "35.00"
            )
        ]
    }
}

// MARK: - Data Structures
// Simple auth middleware for session checking
struct DriverAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if request.session.data["driverToken"] != nil {
            return try await next.respond(to: request)
        } else {
            return request.redirect(to: "/products/gofloradriver/login")
        }
    }
}
