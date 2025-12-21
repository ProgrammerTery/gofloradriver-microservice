import Vapor
import PaymentDTO
import TripDTO
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
            canBid: trip.status == "pending",
            existingBid: existingBid
        )
        return try await req.view.render("drivers/trips/trip-details", context)
    }

    @Sendable func handleSubmitBid(_ req: Request) async throws -> Response {
        guard let tripId = req.parameters.get("tripId") else {
            return req.redirect(to: "/products/gofloradriver/trips")
        }

        let bidData = try req.content.decode(BidFormData.self)
        guard let tripUUID = UUID(uuidString: tripId) else {
            return req.redirect(to: "/products/gofloradriver/trips")
        }

        let bidContentData = SubmitDriverBidRequest(tripId: tripUUID, bidAmount: bidData.bidAmount)

        let jsonData = try JSONEncoder().encode(bidContentData)

        let buffer = req.application.allocator.buffer(data: jsonData)

        do {

            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["drivers"]! + "/trip/\(tripId)/bid",
                body: buffer,
                requiresAuth: true
            )

            if response.status == .created || response.status == .ok {
                return req.redirect(to: "/products/gofloradriver/bids?success=Bid submitted successfully")
            } else {
                let errorData = try? response.content.decode([String: String].self)
                let error = errorData?["message"] ?? "Failed to submit bid"
                return req.redirect(to: "/products/gofloradriver/trips/\(tripId)?error=\(error)")
            }
        } catch {
            req.logger.error("Failed to submit bid: \(error)")
            return req.redirect(to: "/products/gofloradriver/trips/\(tripId)?error=Network error. Please try again.")
        }
    }

    // MARK: - My Bids

    @Sendable func renderMyBids(_ req: Request) async throws -> View {
        let driver = try await fetchDriverProfile(req)
        let bids = try await fetchMyBids(req)
        let pendingBidsCount = bids.filter { $0.status == "pending" }.count
        let approvedBidsCount = bids.filter { $0.status == "approved" }.count

        let context = MyBidsPageContext(
            title: "My Bids",
            pageType: "trips",
            bids: bids,
            driver: driver,
            pendingBidsCount: pendingBidsCount,
            acceptedBidsCount: approvedBidsCount
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

        let driverId = req.session.data["driverID"] ?? ""

        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["drivers"]! + "/trips/\(tripId)/start",
                body: nil,
                requiresAuth: true
            )

            if response.status == .ok {
                return req.redirect(to: "/products/gofloradriver/assigned?success=Trip started successfully")
            } else {
                let errorData = try? response.content.decode([String: String].self)
                let error = errorData?["message"] ?? "Failed to start trip"
                return req.redirect(to: "/products/gofloradriver/assigned?error=\(error)")
            }
        } catch {
            req.logger.error("Failed to start trip \(tripId): \(error)")
            return req.redirect(to: "/products/gofloradriver/assigned?error=Network error. Please try again.")
        }
    }

    @Sendable func handleCompleteTrip(_ req: Request) async throws -> Response {
        guard let tripId = req.parameters.get("tripId") else {
            return req.redirect(to: "/products/gofloradriver/assigned")
        }

        let driverId = req.session.data["driverID"] ?? ""

        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["drivers"]! + "/trips/\(tripId)/complete",
                body: nil,
                requiresAuth: true
            )

            if response.status == .ok {
                return req.redirect(to: "/products/gofloradriver/assigned?success=Trip completed successfully")
            } else {
                let errorData = try? response.content.decode([String: String].self)
                let error = errorData?["message"] ?? "Failed to complete trip"
                return req.redirect(to: "/products/gofloradriver/assigned?error=\(error)")
            }
        } catch {
            req.logger.error("Failed to complete trip \(tripId): \(error)")
            return req.redirect(to: "/products/gofloradriver/assigned?error=Network error. Please try again.")
        }
    }

    // MARK: - Trip History

    @Sendable func renderTripHistory(_ req: Request) async throws -> View {
        let driver = try await fetchDriverProfile(req)
        let historyTrips = try await fetchTripHistory(req)

        let context = AvailableTripsPageContext(
            title: "Trip History",
            pageType: "trips",
            trips: historyTrips,
            driver: driver
        )
        return try await req.view.render("drivers/trips/trip-history", context)
    }

    // MARK: - Helper Methods

    private func fetchDriverProfile(_ req: Request) async throws -> DriverProfileDTO {
        // Try to fetch existing bid from API
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: APIConfig.endpoints["gofloradriver-profiles"]! + "/me",
                requiresAuth: true
            )

            if response.status == .ok {
                if let driverProfile = try? response.content.decode(DriverProfileDTO.self) {
                return driverProfile
                }
            }
        } catch {
            throw Abort(.internalServerError, reason: "Failed to fetch driver profile from API.")
        }
        throw Abort(.internalServerError, reason: "Failed to fetch driver profile from API.")

    }

    private func fetchAvailableTrips(_ req: Request) async throws -> [TripSummaryContext] {
        // Try to fetch available trips from API
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: APIConfig.endpoints["drivers"]! + "/availabletrips",
                requiresAuth: true
            )

            //create a call to get calculated bid amount
            let suggestedPriceEndpoint = APIConfig.endpoints["drivers"]! + "/suggestedprice"

            if response.status == .ok {
                // Try to decode the actual API response
                if let tripsData = try? response.content.decode([TripRequestDTO].self) {
                    return tripsData.map { tripRequest in
                        TripSummaryContext(
                            id: tripRequest.id?.uuidString ?? UUID().uuidString,
                            pickup: tripRequest.pickupLocation,
                            destination: tripRequest.dropoffLocation,
                            distance: "\(tripRequest.estimatedDistance ?? 0) km",
                            suggestedPrice: 10.0, // Placeholder, ideally fetched from suggestedPriceEndpoint
                            status: tripRequest.status ?? "pending",
                            bidAmount: nil, // No bid amount for available trips
                            scheduledTime: tripRequest.pickupTime.ISO8601Format(),
                            date: tripRequest.pickupTime.formatted(date: .abbreviated, time: .omitted),
                            amount: nil
                        )
                    }
                }
            }
        } catch {
            req.logger.warning("Failed to fetch available trips from API: \(error)")
        }

        return []
    }

    private func fetchTripDetails(_ req: Request, tripId: String) async throws -> DetailedTripContext {
        // Try to fetch specific trip details from API
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: APIConfig.endpoints["drivers"]! + "/trip/\(tripId)",
                requiresAuth: true
            )

            if response.status == .ok {
                if let tripData = try? response.content.decode(TripRequestDTO.self) {
                    return DetailedTripContext(
                        id: tripData.id?.uuidString ?? tripId,
                        pickup: tripData.pickupLocation,
                        destination: tripData.dropoffLocation,
                        distance: "\(tripData.estimatedDistance ?? 0) km",
                        suggestedPrice: 10.0, // Placeholder for suggested price
                        status: tripData.status ?? "pending",
                        clientName: "Client \(tripData.clientName)",
                        scheduledTime: tripData.pickupTime.ISO8601Format(),
                        numberOfPassengers: tripData.numberOfPassengers,
                        specialInstructions: tripData.specialInstructions
                    )
                }
            }
        } catch {
            req.logger.warning("Failed to fetch trip details from API for trip \(tripId): \(error)")
        }
        return DetailedTripContext(id: tripId, pickup: "", destination: "", distance: "0 km", suggestedPrice: 0.0, status: "", clientName: "No Client", scheduledTime: "--:--", numberOfPassengers: 0, specialInstructions: nil)
    }

    private func fetchExistingBid(_ req: Request, tripId: String, driverId: String) async throws -> BidContext? {
        // Try to fetch existing bid from API
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: APIConfig.endpoints["drivers"]! + "/trips/\(tripId)/bids/\(driverId)",
                requiresAuth: true
            )

            if response.status == .ok {
                if let bidData = try? response.content.decode(BidFormData.self) {
                    return BidContext(
                        amount: bidData.bidAmount,
                        isApproved: true, // Placeholder, ideally fetched from API
                        submittedAt: Date().formatted(date: .abbreviated, time: .shortened) // fetch from server
                    )
                }
            } else if response.status == .notFound {
                // No existing bid found, return nil
                return nil
            }
        } catch {
            req.logger.warning("Failed to fetch existing bid for trip \(tripId) and driver \(driverId): \(error)")
        }

        // Fallback: return nil (no existing bid) if API call fails
        return nil
    }

    private func fetchMyBids(_ req: Request) async throws -> [BidSummaryContext] {
        // Try to fetch driver's bids from API
        do {
            let driverId = req.session.data["driverID"] ?? ""
            let response = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: APIConfig.endpoints["drivers"]! + "/\(driverId)/bids",
                requiresAuth: true
            )

            if response.status == .ok {
                if let bidsData = try? response.content.decode([BidSummaryContext].self) {
                    return bidsData.compactMap { bidData in

                        return BidSummaryContext(
                            tripID: bidData.tripID,
                            pickup: bidData.pickup,
                            destination: bidData.destination,
                            bidAmount: bidData.bidAmount,
                            status: bidData.status,
                            submittedAt: bidData.submittedAt,
                            isApproved: bidData.isApproved
                        )
                    }
                }
            }
        } catch {
            req.logger.warning("Failed to fetch driver bids from API: \(error)")
        }

        // Fallback to mock data if API call fails or returns nil
        return []
    }

    private func fetchAssignedTrips(_ req: Request) async throws -> [AssignedTripContext] {
        // Try to fetch assigned trips from API
        do {
            let driverId = req.session.data["driverID"] ?? ""
            let response = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: APIConfig.endpoints["drivers"]! + "/drivers/\(driverId)/approvedtriprequests",
                requiresAuth: true
            )

            if response.status == .ok {
                if let tripsData = try? response.content.decode([TripRequestDTO].self) {
                    return tripsData.map { tripData in
                        AssignedTripContext(
                            id: tripData.id?.uuidString ?? UUID().uuidString,
                            pickup: tripData.pickupLocation,
                            destination: tripData.dropoffLocation,
                            status: tripData.status ?? "unknown",
                            scheduledTime: tripData.pickupTime.ISO8601Format(),
                            clientName: "Client \(tripData.clientName)",
                            clientPhone: "phone number not available, use+263771234567", // This might need to come from client data
                            canStart: tripData.status == "paymentComplete" ? true : false, // tripData.status.rawValue == "paymentComplete",
                            canComplete: tripData.status == "inProgress" ? true : false //tripData.status.rawValue == "inProgress"
                        )
                    }
                }
            }
        } catch {
            req.logger.warning("Failed to fetch assigned trips from API: \(error)")
        }


        return []
    }

    private func fetchTripHistory(_ req: Request) async throws -> [TripSummaryContext] {
        // Try to fetch trip history from API
        do {
            let driverId = req.session.data["driverID"] ?? ""
            let response = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: APIConfig.endpoints["drivers"]! + "/drivers/\(driverId)/history",
                requiresAuth: true
            )

            if response.status == .ok {
                if let tripsData = try? response.content.decode([TripSummaryContext].self) {
                    return tripsData.map { tripData in
                        TripSummaryContext(
                            id: tripData.id,
                            pickup: tripData.pickup,
                            destination: tripData.destination,
                            distance: "\(tripData.distance ?? "10") km",
                            suggestedPrice: tripData.suggestedPrice,
                            status: tripData.status,
                            bidAmount: tripData.bidAmount, // Historical trips don't need bid amounts
                            scheduledTime: tripData.scheduledTime,
                            date: tripData.date,
                            amount: tripData.suggestedPrice // Use suggested price as final amount for history
                        )
                    }
                }
            }
        } catch {
            req.logger.warning("Failed to fetch trip history from API: \(error)")
        }


        return []
    }

    private func makeAPIRequest(req: Request, method: HTTPMethod, endpoint: String, body: ByteBuffer? = nil, requiresAuth: Bool = false) async throws -> ClientResponse {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        if requiresAuth {
            // Add authentication token from session
            if let driverToken = req.session.data["driverToken"] {
                headers.add(name: .authorization, value: "Bearer \(driverToken)")
            } else {
                req.logger.warning("No driver token found in session for authenticated request")
            }
        }

        let clientRequest = ClientRequest(
            method: method,
            url: URI(string: endpoint),
            headers: headers,
            body: body
        )

        req.logger.info("Making API request: \(method) \(endpoint)")

        do {
            let response = try await req.client.send(clientRequest)
            req.logger.info("API response: \(response.status)")
            return response
        } catch {
            req.logger.error("API request failed: \(error)")
            throw error
        }
    }
}
