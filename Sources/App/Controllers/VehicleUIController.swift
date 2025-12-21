import Vapor
import Leaf
import DriversDTO
import SharedModels

struct VehicleUIController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let vehicleRoute = routes.grouped("products", "gofloradriver", "vehicle")

        // All vehicle routes require driver session
        let protectedRoutes = vehicleRoute.grouped(DriverAuthMiddleware())

        protectedRoutes.get("service-type", use: renderServiceTypeSelection)
        protectedRoutes.post("service-type", use: handleServiceTypeSelection)
        protectedRoutes.get("register", use: renderVehicleRegistration)
        protectedRoutes.post("register", use: handleVehicleRegistration)
     //   protectedRoutes.get("confirm", use: renderVehicleConfirmation)
        // New: List and Delete vehicles
        protectedRoutes.get("list", use: renderVehicleList)
        protectedRoutes.get(":vehicleID", "delete", use: renderDeleteConfirmation)
        protectedRoutes.post(":vehicleID", "delete", use: handleDeleteVehicle)
    }

    // MARK: - Service Type Selection

    @Sendable func renderServiceTypeSelection(_ req: Request) async throws -> Response {
        guard let driverID = req.session.data["driverID"],
              let driverName = req.session.data["name"],
              let driverToken = req.session.data["driverToken"] else {
            return req.redirect(to: "/products/gofloradriver/register")
        }
             // fetch profile for the logged in driver else throw error and redirect to profile registration
        let profileResponse = try await makeAPIRequest(
            req: req,
            method: .GET,
            endpoint: (APIConfig.endpoints["gofloradriver-profiles"] ?? "urlfailed") + "/me",
            driverToken: driverToken
        )   

        guard profileResponse.status == .ok,
              let profile = try? profileResponse.content.decode(DriverProfileDTO.self),
              !profile.driverName.isEmpty else {
            return req.redirect(to: "/products/gofloradriver/register")
        }

        let serviceTypes = try await fetchServiceTypes(req)

        let context: ServiceTypeSelectionContext = ServiceTypeSelectionContext(
            title: "Select Service Type",
            pageType: "vehicle",
            driverID: driverID,
            driverName: driverName,
            serviceTypes: serviceTypes,
            errorMessage: ""
        )
        return try await req.view.render("drivers/vehicle/service-type-selection", context).encodeResponse(for: req)
    }

    @Sendable func handleServiceTypeSelection(_ req: Request) async throws -> Response {
        let selectionData = try req.content.decode(ServiceTypeSelectionFormData.self)

        // Store selected service type in session
        req.session.data["selectedServiceTypeID"] = selectionData.serviceTypeID

        return req.redirect(to: "/products/gofloradriver/vehicle/register")
    }

    // MARK: - Vehicle Registration

    @Sendable func renderVehicleRegistration(_ req: Request) async throws -> Response {
        guard let driverID = req.session.data["driverID"],   
              let driverName = req.session.data["name"],
              let selectedServiceTypeID = req.session.data["selectedServiceTypeID"] else {
            return req.redirect(to: "/products/gofloradriver/vehicle/service-type")
        }

        let selectedServiceType = try await fetchServiceTypeById(req, id: selectedServiceTypeID)

        let context: VehicleRegistrationPageContext = VehicleRegistrationPageContext(
            title: "Vehicle Registration",
            pageType: "vehicle",
            driverID: driverID,
            driverName: driverName,
            selectedServiceType: selectedServiceType,
            errorMessage: ""
        )
        return try await req.view.render("drivers/vehicle/vehicle-registration", context).encodeResponse(for: req)
    }

    @Sendable func handleVehicleRegistration(_ req: Request) async throws -> Response {
        guard let driverToken = req.session.data["driverToken"],
              let driverID = req.session.data["driverID"] else {
            return req.redirect(to: "/products/gofloradriver/register")
        }

        let vehicleData = try req.content.decode(VehicleRegistrationFormData.self)

        let vehicleDetails = VehicleDTO(
            id: nil,
            registrationNumber: "remove this field" + UUID().uuidString,
            licensePlateNumber: vehicleData.licensePlate,
            make: vehicleData.make,
            model: vehicleData.model,
            yearOfManufacture: "\(vehicleData.year)",
            bodyType: "remove this field",
            color: vehicleData.color,
            engineSize: "remove this field",
            fuelType: "remove this field",
            transmissionType: "remove this field",
            seatingCapacity: "remove this field",
            ownerName: "remove this field",
            ownerAddress: "remove this field",
            contactInformation: "remove this field",
            insuranceDetails: "remove this field",
            vehicleHistory: "remove this field",
            emissionsStandards: "remove this field",
            servicetypeId: UUID(uuidString: vehicleData.serviceTypeID)!
        )

        let jsonData = try JSONEncoder().encode(vehicleDetails)
        let buffer = req.application.allocator.buffer(data: jsonData)

        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["vehicles"]!,
                body: buffer,
                driverToken: driverToken
            )

            // Check status code instead of decoded ID
            guard response.status == .ok || response.status == .created else {
                let errorData = (try? response.content.decode([String: String].self)) ?? [:]
                let error = errorData["message"] ?? "Vehicle registration failed"
                return req.redirect(to: "/products/gofloradriver/vehicle/register?error=\(error)")
            }

            // Update session flags
            req.session.data["hasVehicle"] = "true"
            req.session.data["vehicleComplete"] = "true"
            req.session.data["vehicleIncomplete"] = nil

            // Redirect to vehicle list with success message
            return req.redirect(to: "/products/gofloradriver/vehicle/list?success=Vehicle registered successfully")

        } catch {
            return req.redirect(to: "/products/gofloradriver/vehicle/register?error=Network error. Please try again.")
        }
    }

    // MARK: - Vehicle Confirmation

    @Sendable func renderVehicleConfirmation(_ req: Request) async throws -> Response {
        guard let driverName = req.session.data["driverName"],
              let driverID = req.session.data["driverID"],
              let selectedServiceTypeID = req.session.data["selectedServiceTypeID"],
              let driverToken = req.session.data["driverToken"] else {
            return req.redirect(to: "/products/gofloradriver/vehicle/register")
        }

        guard let selectedServiceType: TransportServiceDTO = try await fetchServiceTypeById(req, id: selectedServiceTypeID) else {
            throw Abort(.badRequest, reason: "Selected service type not found.")
        }

        // Query API for vehicle details rather than relying on session
        guard let apiVehicle = try await fetchVehicleForDriver(req, driverID: driverID, driverToken: driverToken) else {
            return req.redirect(to: "/products/gofloradriver/vehicle/register?error=Vehicle not found, please re-enter details")
        }

        let vehicle = VehicleContext(
            make: apiVehicle.make,
            model: apiVehicle.model,
            year: Int(apiVehicle.yearOfManufacture) ?? 0,
            licensePlate: apiVehicle.licensePlateNumber,
            color: apiVehicle.color
        )

        let context = VehicleConfirmationContext(
            title: "Vehicle Registration Complete",
            pageType: "success",
            driverName: driverName,
            vehicle: vehicle,
            serviceType: selectedServiceType
        )
        return try await req.view.render("drivers/vehicle/vehicle-confirmation", context).encodeResponse(for: req)
    }

    // MARK: - Vehicle Listing & Deletion

    @Sendable func renderVehicleList(_ req: Request) async throws -> Response {
        guard let driverName = req.session.data["name"],
              let driverID = req.session.data["driverID"],
              let driverToken = req.session.data["driverToken"] else {
            return req.redirect(to: "/products/gofloradriver/login")
        }

        let endpoint = (APIConfig.endpoints["vehicles"] ?? "urlfailed")
        do {
            let resp = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
            var vehicles: [VehicleDTO] = []
            if resp.status == .ok {
                vehicles = (try? resp.content.decode([VehicleDTO].self)) ?? []
            }

            let context: VehiclesListContext = VehiclesListContext(
                title: "My Vehicles",
                pageType: "vehicle",
                driverName: driverName,
                vehicles: vehicles,
                successMessage: "",
                errorMessage: ""
            )
            return try await req.view.render("drivers/vehicle/my-vehicles", context).encodeResponse(for: req)
        } catch {
            return req.redirect(to: "/products/gofloradriver/dashboard?error=Failed to load vehicles + \(error.localizedDescription)")
        }
    }

    @Sendable func renderDeleteConfirmation(_ req: Request) async throws -> Response {
        guard let driverName = req.session.data["name"],
              let driverID = req.session.data["driverID"],
              let driverToken = req.session.data["driverToken"],
              let vehicleID = req.parameters.get("vehicleID") else {
            return req.redirect(to: "/products/gofloradriver/vehicle/list?error=Invalid request")
        }

        let endpoint = (APIConfig.endpoints["vehicles"] ?? "urlfailed") + "/by-driver/\(driverID)"
        do {
            let resp = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
            guard resp.status == .ok, let vehicles = try? resp.content.decode([VehicleDTO].self) else {
                return req.redirect(to: "/products/gofloradriver/vehicle/list?error=Could not load vehicles")
            }
            guard let vehicle = vehicles.first(where: { $0.id?.uuidString == vehicleID }) else {
                return req.redirect(to: "/products/gofloradriver/vehicle/list?error=Vehicle not found")
            }

            let context = VehicleDeleteConfirmationContext(
                title: "Confirm Delete",
                pageType: "vehicle",
                driverName: driverName,
                vehicle: vehicle,
                errorMessage: ""
            )
            return try await req.view.render("drivers/vehicle/delete-confirmation", context).encodeResponse(for: req)
        } catch {
            return req.redirect(to: "/products/gofloradriver/vehicle/list?error=Failed to load confirmation")
        }
    }

    @Sendable func handleDeleteVehicle(_ req: Request) async throws -> Response {
        guard let driverToken = req.session.data["driverToken"],
              let vehicleID = req.parameters.get("vehicleID") else {
            return req.redirect(to: "/products/gofloradriver/vehicle/list?error=Invalid request")
        }

        let endpoint = (APIConfig.endpoints["vehicles"] ?? "urlfailed") + "/\(vehicleID)"
        do {
            let resp = try await makeAPIRequest(req: req, method: .DELETE, endpoint: endpoint, driverToken: driverToken)
            if resp.status == .ok || resp.status == .noContent {
                // Update session flags
                req.session.data["hasVehicle"] = nil
                req.session.data["vehicleComplete"] = nil
                req.session.data["vehicleIncomplete"] = "true"
                return req.redirect(to: "/products/gofloradriver/vehicle/list?success=Vehicle deleted")
            } else {
                let errMsg =     "failed to delete vehicle"
                return req.redirect(to: "/products/gofloradriver/vehicle/list?error=\(errMsg)")
            }
        } catch {
            return req.redirect(to: "/products/gofloradriver/vehicle/list?error=Network error during delete")
        }
    }
    // MARK: - Helper Methods

    private func fetchServiceTypes(_ req: Request) async throws -> [TransportServiceDTO] {
        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: APIConfig.endpoints["transportServiceTypes"]!
            )

            if response.status == .ok {
                let serviceTypes: [TransportServiceDTO] = try response.content.decode([TransportServiceDTO].self)
                return serviceTypes.map { serviceType in
                    TransportServiceDTO(
                        transportServiceType: serviceType.transportServiceType,
                         id: serviceType.id,
                         baseFare: serviceType.baseFare,
                          description: serviceType.description, 
                          isTransfer: serviceType.isTransfer
                    )
                }
            } else {
                throw Abort(.badRequest, reason: "Failed to fetch service types from API.")
            }
        } catch {
            // Return default service types if network error
            throw error
        }
    }

    private func fetchServiceTypeById(_ req: Request, id: String) async throws -> TransportServiceDTO? {
        let allServiceTypes = try await fetchServiceTypes(req)
        return allServiceTypes.first { $0.id?.uuidString == id }
    }

    private func makeAPIRequest(req: Request, method: HTTPMethod, endpoint: String, body: ByteBuffer? = nil, driverToken: String? = nil ) async throws -> ClientResponse {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        if let driverToken = driverToken {
        headers.add(name: "Authorization", value: "Bearer \(driverToken)")

        }

        let clientRequest = ClientRequest(
            method: method,
            url: URI(string: endpoint),
            headers: headers,
            body: body
        )

        return try await req.client.send(clientRequest)
    }

    // Fetch a driver's vehicle from API using token
    private func fetchVehicleForDriver(_ req: Request, driverID: String, driverToken: String) async throws -> VehicleDTO? {
        let endpoint = (APIConfig.endpoints["vehicles"] ?? "urlfailed") + "/by-driver/\(driverID)"
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        guard response.status == .ok else { return nil }
        return try response.content.decode(VehicleDTO.self)
    }
}

// Helper struct for API response parsing

