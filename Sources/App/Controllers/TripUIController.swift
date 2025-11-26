import Vapor
import Leaf
import DriversDTO

struct TripUIController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let tripRoute = routes.grouped("products", "gofloradriver")
        
        // All trip routes require driver authentication
        let protectedRoutes = tripRoute.grouped(DriverAuthMiddleware())
        
        protectedRoutes.get("trips", use: renderAvailableTrips)
        protectedRoutes.get("trips", "available", use: renderAvailableTrips)
        protectedRoutes.get("trips", ":tripId", use: renderTripDetails)
        protectedRoutes.post("trips", ":tripId", "bid", use: handleSubmitBid)
        protectedRoutes.get("bids", use: renderMyBids)
        protectedRoutes.get("assigned", use: renderAssignedTrips)
        protectedRoutes.post("trips", ":tripId", "start", use: handleStartTrip)
        protectedRoutes.post("trips", ":tripId", "complete", use: handleCompleteTrip)
        protectedRoutes.get("history", use: renderTripHistory)
    }
    
    // MARK: - Available Trips
    
    @Sendable func renderAvailableTrips(_ req: Request) async throws -> View {
        let driver = try await fetchDriverProfile(req)
        let trips = try await fetchAvailableTrips(req)
        
        let context = AvailableTripsPageContext(
            title: "Available Trips",
            pageType: "trips",
            trips: trips,
            driver: driver
        )
        return try await req.view.render("drivers/trips/available-trips", context)
    }
    
    @Sendable func renderTripDetails(_ req: Request) async throws -> View {
        guard let tripId = req.parameters.get("tripId") else {
            throw Abort(.badRequest, reason: "Trip ID is required")
        }
        
        let driver = try await fetchDriverProfile(req)
        let trip = try await fetchTripDetails(req, tripId: tripId)
        let existingBid = try await fetchExistingBid(req, tripId: tripId, driverId: driver.driverID)
        
        let context = TripDetailsPageContext(
            title: "Trip Details",
            pageType: "trips",
            trip: trip,
            driver: driver,
            canBid: trip.status == "driversAccepting",
            existingBid: existingBid
        )
        return try await req.view.render("drivers/trips/trip-details", context)
    }
    
    @Sendable func handleSubmitBid(_ req: Request) async throws -> Response {
        guard let tripId = req.parameters.get("tripId") else {
            return req.redirect(to: "/products/gofloradriver/trips")
        }
        
        let bidData = try req.content.decode(BidFormData.self)
        
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["drivers"]! + "/trip/\(tripId)/bid",
                body: ["bidAmount": bidData.bidAmount],
                requiresAuth: true
            )
            
            if response.status == .created || response.status == .ok {
                return req.redirect(to: "/products/gofloradriver/trips/\(tripId)?success=Bid submitted successfully")
            } else {
                let errorData = try response.content.decode([String: String].self)
                let error = errorData["message"] ?? "Failed to submit bid"
                return req.redirect(to: "/products/gofloradriver/trips/\(tripId)?error=\(error)")
            }
        } catch {
            return req.redirect(to: "/products/gofloradriver/trips/\(tripId)?error=Network error. Please try again.")
        }
    }
    
    // MARK: - My Bids
    
    @Sendable func renderMyBids(_ req: Request) async throws -> View {
        let driver = try await fetchDriverProfile(req)
        let bids = try await fetchMyBids(req)
        
        let context = MyBidsPageContext(
            title: "My Bids",
            pageType: "trips",
            bids: bids,
            driver: driver
        )
        return try await req.view.render("drivers/trips/my-bids", context)
    }
    
    // MARK: - Assigned Trips
    
    @Sendable func renderAssignedTrips(_ req: Request) async throws -> View {
        let driver = try await fetchDriverProfile(req)
        let assignedTrips = try await fetchAssignedTrips(req)
        
        let context = AssignedTripsPageContext(
            title: "Assigned Trips",
            pageType: "trips",
            trips: assignedTrips,
            driver: driver
        )
        return try await req.view.render("drivers/trips/assigned-trips", context)
    }
    
    @Sendable func handleStartTrip(_ req: Request) async throws -> Response {
        guard let tripId = req.parameters.get("tripId") else {
            return req.redirect(to: "/products/gofloradriver/assigned")
        }
        
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["drivers"]! + "/trip/\(tripId)/start",
                body: nil,
                requiresAuth: true
            )
            
            if response.status == .ok {
                return req.redirect(to: "/products/gofloradriver/assigned?success=Trip started successfully")
            } else {
                let errorData = try response.content.decode([String: String].self)
                let error = errorData["message"] ?? "Failed to start trip"
                return req.redirect(to: "/products/gofloradriver/assigned?error=\(error)")
            }
        } catch {
            return req.redirect(to: "/products/gofloradriver/assigned?error=Network error. Please try again.")
        }
    }
    
    @Sendable func handleCompleteTrip(_ req: Request) async throws -> Response {
        guard let tripId = req.parameters.get("tripId") else {
            return req.redirect(to: "/products/gofloradriver/assigned")
        }
        
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["drivers"]! + "/trip/\(tripId)/complete",
                body: nil,
                requiresAuth: true
            )
            
            if response.status == .ok {
                return req.redirect(to: "/products/gofloradriver/assigned?success=Trip completed successfully")
            } else {
                let errorData = try response.content.decode([String: String].self)
                let error = errorData["message"] ?? "Failed to complete trip"
                return req.redirect(to: "/products/gofloradriver/assigned?error=\(error)")
            }
        } catch {
            return req.redirect(to: "/products/gofloradriver/assigned?error=Network error. Please try again.")
        }
    }
    
    // MARK: - Trip History
    
    @Sendable func renderTripHistory(_ req: Request) async throws -> View {
        let driver = try await fetchDriverProfile(req)
        let historyTrips = try await fetchTripHistory(req)
        
        let context = App.AvailableTripsPageContext(
            title: "Trip History",
            pageType: "trips",
            trips: historyTrips,
            driver: driver
        )
        return try await req.view.render("drivers/trips/trip-history", context)
    }
    
    // MARK: - Helper Methods
    
    private func fetchDriverProfile(_ req: Request) async throws -> DriverProfileDTO {
        // Mock data - in real implementation, call API with session token


        return DriverProfileDTO(driverID:  req.session.data["driverID"] ?? "unknown", driverName: req.session.data["name"] ?? "Unknown Driver", driverPhone: "+263778463020", driverEmail: "waltack@example.com", driverAddress: "Victoria Falls City", registrationDate: Date(), driverLicense: "AQW5363783", vehicle_id: UUID())
    }
    
    private func fetchAvailableTrips(_ req: Request) async throws -> [App.TripSummaryContext] {
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: APIConfig.endpoints["drivers"]! + "/availabletrips",
                requiresAuth: true
            )
            
            if response.status == .ok {
                // Parse actual trips from API response
                // This is a simplified version - you'd parse actual TripRequest objects
                return [
                    TripSummaryContext(
                        id: "trip-1",
                        pickup: "Downtown Mall",
                        destination: "Airport",
                        distance: "15 miles",
                        suggestedPrice: 45.00,
                        status: "pending",
                        bidAmount: nil,
                        scheduledTime: "2025-01-28 14:30",
                        date: Date().timeIntervalSince1970.description,
                        amount: Int.random(in: 40...50).description
                    ),
                    TripSummaryContext(
                        id: "trip-2",
                        pickup: "Hotel Plaza",
                        destination: "Train Station",
                        distance: "8 miles",
                        suggestedPrice: 25.00,
                        status: "driversAccepting",
                        bidAmount: nil,
                        scheduledTime: "2025-01-28 16:00",
                        date: Date().timeIntervalSince1970.description,
                        amount: Int.random(in: 40...50).description
                    )
                ]
            }
        } catch {
            // Return empty array if API fails
        }
        return []
    }
    
    private func fetchTripDetails(_ req: Request, tripId: String) async throws -> DetailedTripContext {
        // Mock data - in real implementation, call specific trip API
        return DetailedTripContext(
            id: tripId,
            pickup: "Downtown Mall",
            destination: "Airport",
            distance: "15 miles",
            suggestedPrice: 45.00,
            status: "driversAccepting",
            clientName: "John Client",
            scheduledTime: "2025-01-28 14:30",
            numberOfPassengers: 2,
            specialInstructions: "Please call upon arrival"
        )
    }
    
    private func fetchExistingBid(_ req: Request, tripId: String, driverId: String) async throws -> BidContext? {
        // Mock data - in real implementation, check for existing bid
        return nil
    }
    
    private func fetchMyBids(_ req: Request) async throws -> [BidSummaryContext] {
        // Mock data - in real implementation, call API for driver's bids
        return [
            BidSummaryContext(
                tripID: "trip-1",
                pickup: "Downtown Mall",
                destination: "Airport",
                bidAmount: 42.00,
                status: "pending",
                submittedAt: "2025-01-28 12:00",
                isApproved: false
            )
        ]
    }
    
    private func fetchAssignedTrips(_ req: Request) async throws -> [AssignedTripContext] {
        // Mock data - in real implementation, call API for assigned trips
        return [
            AssignedTripContext(
                id: "trip-3",
                pickup: "Business Center",
                destination: "Airport",
                status: "paymentComplete",
                scheduledTime: "2025-01-28 18:00",
                clientName: "Jane Client",
                clientPhone: "+1987654321",
                canStart: true,
                canComplete: false
            )
        ]
    }
    
    private func fetchTripHistory(_ req: Request) async throws -> [App.TripSummaryContext] {
        // Mock data - in real implementation, call API for completed trips
        return [
            TripSummaryContext(
                id: "trip-old-1",
                pickup: "City Center",
                destination: "Suburbs",
                distance: "12 miles",
                suggestedPrice: 30.00,
                status: "completed",
                bidAmount: 28.00,
                scheduledTime: "2025-01-27 10:00",
                date: "Jan 27, 2025",
                amount: "28.00"
            )
        ]
    }
    
    private func makeAPIRequest(req: Request, method: HTTPMethod, endpoint: String, body: [String: Any]? = nil, requiresAuth: Bool = false) async throws -> ClientResponse {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        
        if requiresAuth {
            // In real implementation, you'd store and retrieve actual auth token
            if let driverToken = req.session.data["driverToken"] {
                headers.add(name: .authorization, value: "Bearer \(driverToken)")
            }
        }
        
        var clientBody: ByteBuffer?
        if let body = body {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            clientBody = req.application.allocator.buffer(data: jsonData)
        }
        
        let clientRequest = ClientRequest(
            method: method,
            url: URI(string: endpoint),
            headers: headers,
            body: clientBody
        )
        
        return try await req.client.send(clientRequest)
    }
}
