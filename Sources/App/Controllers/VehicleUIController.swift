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
        protectedRoutes.get("confirm", use: renderVehicleConfirmation)
    }

    // MARK: - Service Type Selection

    @Sendable func renderServiceTypeSelection(_ req: Request) async throws -> Response {
        guard let driverID = req.session.data["driverID"],
              let driverName = req.session.data["name"] else {
            return req.redirect(to: "/products/gofloradriver/register")
        }

        let serviceTypes = try await fetchServiceTypes(req)

        let context: ServiceTypeSelectionContext = ServiceTypeSelectionContext(
            title: "Select Service Type",
            pageType: "vehicle",
            driverID: driverID,
            driverName: driverName,
            serviceTypes: serviceTypes,
            errorMessage: req.query["error"]
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

        let context = VehicleRegistrationPageContext(
            title: "Vehicle Registration",
            pageType: "vehicle",
            driverID: driverID,
            driverName: driverName,
            selectedServiceType: selectedServiceType,
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/vehicle/vehicle-registration", context).encodeResponse(for: req)
    }

    @Sendable func handleVehicleRegistration(_ req: Request) async throws -> Response {
        guard let driverID = req.session.data["driverID"] else {
            return req.redirect(to: "/products/gofloradriver/register")
        }

        let vehicleData = try req.content.decode(VehicleRegistrationFormData.self)

        // Prepare data for VehicleController API
        let vehiclePayload: [String: Any] = [
            "driverID": driverID,
            "make": vehicleData.make,
            "model": vehicleData.model,
            "year": vehicleData.year,
            "licensePlate": vehicleData.licensePlate,
            "color": vehicleData.color,
            "serviceTypeID": vehicleData.serviceTypeID
        ]

        do {
            let response = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: APIConfig.endpoints["vehicles"]!,
                body: vehiclePayload
            )

            if response.status == .created || response.status == .ok {
                // Store vehicle data in session
                req.session.data["vehicleMake"] = vehicleData.make
                req.session.data["vehicleModel"] = vehicleData.model
                req.session.data["vehicleYear"] = String(vehicleData.year)
                req.session.data["vehicleLicensePlate"] = vehicleData.licensePlate
                req.session.data["vehicleColor"] = vehicleData.color
                req.session.data["hasVehicle"] = "true"
                // Mark vehicle completion flags
                req.session.data["vehicleComplete"] = "true"
                req.session.data["vehicleIncomplete"] = nil

                return req.redirect(to: "/products/gofloradriver/vehicle/confirm")
            } else {
                let errorData = try response.content.decode([String: String].self)
                let error = errorData["message"] ?? "Vehicle registration failed"
                return req.redirect(to: "/products/gofloradriver/vehicle/register?error=\(error)")
            }
        } catch {
            return req.redirect(to: "/products/gofloradriver/vehicle/register?error=Network error. Please try again.")
        }
    }

    // MARK: - Vehicle Confirmation

    @Sendable func renderVehicleConfirmation(_ req: Request) async throws -> Response {
        guard let driverName = req.session.data["driverName"],
              let vehicleMake = req.session.data["vehicleMake"],
              let vehicleModel = req.session.data["vehicleModel"],
              let vehicleYearStr = req.session.data["vehicleYear"],
              let vehicleYear = Int(vehicleYearStr),
              let vehicleLicensePlate = req.session.data["vehicleLicensePlate"],
              let vehicleColor = req.session.data["vehicleColor"],
              let selectedServiceTypeID = req.session.data["selectedServiceTypeID"] else {
            throw Abort(.badRequest, reason: "Vehicle registration session data not found.")
        }

       guard let selectedServiceType: TransportServiceDTO = try await fetchServiceTypeById(req, id: selectedServiceTypeID) else {
           throw Abort(.badRequest, reason: "Selected service type not found.")
       }

        let vehicle = VehicleContext(
            make: vehicleMake,
            model: vehicleModel,
            year: vehicleYear,
            licensePlate: vehicleLicensePlate,
            color: vehicleColor
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

    private func makeAPIRequest(req: Request, method: HTTPMethod, endpoint: String, body: [String: Any]? = nil) async throws -> ClientResponse {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

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

// Helper struct for API response parsing

