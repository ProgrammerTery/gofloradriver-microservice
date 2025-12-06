import Vapor
import Leaf
import DriversDTO

// Import the custom payment method DTO
import Foundation

struct ServiceFeesUIController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let feesRoute = routes.grouped("products", "gofloradriver", "service-fees").grouped(DriverAuthMiddleware())
        feesRoute.get("my-fees", use: renderMyFees)
        feesRoute.get("create", use: renderCreateFee)
        feesRoute.post("create", use: handleCreateFee)
        feesRoute.get(":serviceFeeID", use: renderFeeDetails)
        feesRoute.get(":serviceFeeID", "edit", use: renderEditFee)
        feesRoute.put(":serviceFeeID", use: handleEditFee)
        feesRoute.post(":serviceFeeID", "toggle-active", use: handleToggleActive)
        feesRoute.get("stats", use: renderStats)
    }

    // GET /my-fees
    @Sendable func renderMyFees(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let page = Int(req.query["page"] ?? "1") ?? 1
        let perPage = Int(req.query["perPage"] ?? "25") ?? 25
        let driverProfile = try await fetchDriverProfile(req)
        let paymentMethods = try await fetchPaymentMethods(req, driverToken: driverToken)
        let feesResponse = try await fetchServiceFees(req, driverToken: driverToken, page: page, perPage: perPage)
        let stats = try await fetchServiceFeeStats(req, driverToken: driverToken)
        let totalPages = Int(ceil(Double(feesResponse.total) / Double(perPage)))
        let context = ServiceFeesListPageContext(
            title: "My Service Fees",
            pageType: "service-fees-list",
            driver: driverProfile,
            serviceFees: feesResponse.serviceFees,
            stats: stats,
            total: feesResponse.total,
            page: page,
            perPage: perPage,
            paymentMethods: paymentMethods,
            successMessage: req.query["success"],
            errorMessage: req.query["error"],
            totalPages: totalPages,
            hasNextPage: page < totalPages,
            hasPrevPage: page > 1
        )
        return try await req.view.render("drivers/service-fees/my-fees", context)
    }

    // GET /create
    @Sendable func renderCreateFee(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let driverProfile = try await fetchDriverProfile(req)
        let paymentMethods = try await fetchPaymentMethods(req, driverToken: driverToken)
        let currencies = ["USD", "ZWL", "ZAR", "EUR", "GBP"]
        let context = ServiceFeeFormPageContext(
            title: "Create Service Fee",
            pageType: "service-fee-form",
            driver: driverProfile,
            fee: nil,
            paymentMethods: paymentMethods,
            currencies: currencies,
            isEdit: false,
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/service-fees/fee-form", context)
    }

    // POST /create
    @Sendable func handleCreateFee(_ req: Request) async throws -> Response {
        let driverToken = req.session.data["driverToken"] ?? ""
        let form = try req.content.decode(CreateDriverCustomServiceFeesRequest.self)
        let jsonData = try JSONEncoder().encode(form)
        let buffer = req.application.allocator.buffer(data: jsonData)
        let endpoint = APIConfig.endpoints["service-fees"] ?? "urlfailed"
        let response = try await makeAPIRequest(req: req, method: .POST, endpoint: endpoint, body: buffer, driverToken: driverToken)
        if response.status == .created || response.status == .ok {
            return req.redirect(to: "/products/gofloradriver/service-fees/my-fees?success=Service fee created successfully")
        } else {
            let errorData = try? response.content.decode([String: String].self)
            let error = errorData?["message"] ?? "Failed to create service fee"
            return req.redirect(to: "/products/gofloradriver/service-fees/create?error=\(error)")
        }
    }

    // GET /:serviceFeeID
    @Sendable func renderFeeDetails(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let driverProfile = try await fetchDriverProfile(req)
        let feeID = req.parameters.get("serviceFeeID") ?? ""
        let fee = try await fetchServiceFeeByID(req, driverToken: driverToken, feeID: feeID)
        let paymentMethod = try await fetchPaymentMethodByID(req, driverToken: driverToken, paymentMethodID: fee.paymentMethodId.uuidString)
        let context = ServiceFeeDetailsPageContext(
            title: "Service Fee Details",
            pageType: "service-fee-details",
            driver: driverProfile,
            fee: fee,
            paymentMethod: paymentMethod,
            successMessage: req.query["success"],
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/service-fees/fee-details", context)
    }

    // GET /:serviceFeeID/edit
    @Sendable func renderEditFee(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let driverProfile = try await fetchDriverProfile(req)
        let feeID = req.parameters.get("serviceFeeID") ?? ""
        let fee = try await fetchServiceFeeByID(req, driverToken: driverToken, feeID: feeID)
        let paymentMethods = try await fetchPaymentMethods(req, driverToken: driverToken)
        let currencies = ["USD", "ZWL", "ZAR", "EUR", "GBP"]
        let context = ServiceFeeFormPageContext(
            title: "Edit Service Fee",
            pageType: "service-fee-form",
            driver: driverProfile,
            fee: fee,
            paymentMethods: paymentMethods,
            currencies: currencies,
            isEdit: true,
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/service-fees/fee-form", context)
    }

    // PUT /:serviceFeeID
    @Sendable func handleEditFee(_ req: Request) async throws -> Response {
        let driverToken = req.session.data["driverToken"] ?? ""
        let feeID = req.parameters.get("serviceFeeID") ?? ""
        let form = try req.content.decode(UpdateDriverCustomServiceFeesRequest.self)
        let jsonData = try JSONEncoder().encode(form)
        let buffer = req.application.allocator.buffer(data: jsonData)
        let endpoint = (APIConfig.endpoints["service-fees"] ?? "urlfailed") + "/\(feeID)"
        let response = try await makeAPIRequest(req: req, method: .PUT, endpoint: endpoint, body: buffer, driverToken: driverToken)
        if response.status == .ok {
            return req.redirect(to: "/products/gofloradriver/service-fees/\(feeID)?success=Service fee updated successfully")
        } else {
            let errorData = try? response.content.decode([String: String].self)
            let error = errorData?["message"] ?? "Failed to update service fee"
            return req.redirect(to: "/products/gofloradriver/service-fees/\(feeID)/edit?error=\(error)")
        }
    }

    // POST /:serviceFeeID/toggle-active
    @Sendable func handleToggleActive(_ req: Request) async throws -> Response {
        let driverToken = req.session.data["driverToken"] ?? ""
        let feeID = req.parameters.get("serviceFeeID") ?? ""
        let endpoint = (APIConfig.endpoints["service-fees"] ?? "urlfailed") + "/\(feeID)/toggle-active"
        let response = try await makeAPIRequest(req: req, method: .POST, endpoint: endpoint, driverToken: driverToken)
        if response.status == .ok {
            return Response(status: .ok, body: .init(string: "{\"success\":true}"))
        } else {
            return Response(status: .badRequest, body: .init(string: "{\"success\":false}"))
        }
    }

    // GET /stats
    @Sendable func renderStats(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let driverProfile = try await fetchDriverProfile(req)
        let stats = try await fetchServiceFeeStats(req, driverToken: driverToken)
        let currencyStats: [(currency: String, stats: CurrencyStatsDTO)] = stats.currencyBreakdown.map { (key, value) in (key, value) }
        let context = ServiceFeesStatsPageContext(
            title: "Service Fees Stats",
            pageType: "service-fees-stats",
            driver: driverProfile,
            stats: stats,
            currencyStats: currencyStats
        )
        return try await req.view.render("drivers/service-fees/stats", context)
    }

    // Helper methods (stubs, to be implemented)
    private func fetchDriverProfile(_ req: Request) async throws -> DriverProfileDTO {
        // ...existing code...
        return DriverProfileDTO(driverID: "", driverName: "", driverPhone: "", driverEmail: "", driverAddress: "", registrationDate: Date(), driverLicense: "", vehicle_id: nil)
    }
    private func fetchPaymentMethods(_ req: Request, driverToken: String) async throws -> [PayNowPaymentMethodResponseDTO] {
        // ...existing code...
        return []
    }
    private func fetchServiceFees(_ req: Request, driverToken: String, page: Int, perPage: Int) async throws -> DriverCustomServiceFeesListResponse {
        // ...existing code...
        return DriverCustomServiceFeesListResponse(serviceFees: [], total: 0, page: page, perPage: perPage)
    }
    private func fetchServiceFeeStats(_ req: Request, driverToken: String) async throws -> DriverServiceFeesStatsDTO? {
        // ...existing code...
        return nil
    }
    private func fetchServiceFeeByID(_ req: Request, driverToken: String, feeID: String) async throws -> DriverCustomServiceFeesDTO {
        // ...existing code...
        throw Abort(.notFound)
    }
    private func fetchPaymentMethodByID(_ req: Request, driverToken: String, paymentMethodID: String) async throws -> PayNowPaymentMethodResponseDTO? {
        // ...existing code...
        return nil
    }
    private func makeAPIRequest(req: Request, method: HTTPMethod, endpoint: String, body: ByteBuffer? = nil, driverToken: String? = nil) async throws -> ClientResponse {
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
}
