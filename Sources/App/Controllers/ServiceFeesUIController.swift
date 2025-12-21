import Vapor
import Leaf
import DriversDTO
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
    }

    // GET /my-fees
    @Sendable func renderMyFees(_ req: Request) async throws -> Response {
        do {
            let driverToken = req.session.data["driverToken"] ?? ""
            let page = Int(req.query["page"] ?? "1") ?? 1
            let perPage = Int(req.query["perPage"] ?? "25") ?? 25
            let paymentMethods = try await fetchPaymentMethods(req, driverToken: driverToken)
            let feesResponse = try await fetchServiceFees(req, driverToken: driverToken, page: page, perPage: perPage)
            let totalPages = Int(ceil(Double(feesResponse.total) / Double(perPage)))
            let context = ServiceFeesListPageContext(
                title: "My Service Fees",
                pageType: "service-fees-list",
                serviceFees: feesResponse.serviceFees,
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
            return try await req.view.render("drivers/service-fees/my-fees", context).encodeResponse(for: req)
        } catch {
            let context = ServiceFeesListPageContext(
                title: "My Service Fees",
                pageType: "service-fees-list",
                serviceFees: [],
                total: 0,
                page: 1,
                perPage: 25,
                paymentMethods: [],
                successMessage: nil,
                errorMessage: nil,
                totalPages: 0,
                hasNextPage: false,
                hasPrevPage: false
            )
            return try await req.view.render("drivers/service-fees/my-fees", context).encodeResponse(for: req)
        }
    }

    // GET /create
    @Sendable func renderCreateFee(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let paymentMethods: [PayNowPaymentMethodResponseDTO] = try await fetchPaymentMethods(req, driverToken: driverToken)
        let context = ServiceFeeCreatePageContext(
            title: "Create Service Fee",
            pageType: "service-fee-create",
            paymentMethods: paymentMethods,
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/service-fees/fee-form-create", context)
    }

    // POST /create
    @Sendable func handleCreateFee(_ req: Request) async throws -> Response {
        let driverToken = req.session.data["driverToken"] ?? ""
        struct CreateServiceFeeViaPayNowRequest: Content {
            let paymentMethodId: UUID
            let usMethods: [String]
            let zwMethods: [String]
            let priority: Int
            let isActive: Bool
        }
        let form = try req.content.decode(CreateServiceFeeViaPayNowRequest.self)
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
        let feeID = req.parameters.get("serviceFeeID") ?? ""
        let fee = try await fetchServiceFeeByID(req, driverToken: driverToken, feeID: feeID)
        let paymentMethods = try await fetchPaymentMethods(req, driverToken: driverToken)
        let context = ServiceFeeDetailsPageContext(
            title: "Service Fee Details",
            pageType: "service-fee-details",
            fee: fee,
            paymentMethods: paymentMethods,
            successMessage: req.query["success"],
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/service-fees/fee-details", context)
    }

    // GET /:serviceFeeID/edit
    @Sendable func renderEditFee(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let feeID = req.parameters.get("serviceFeeID") ?? ""
        let fee = try await fetchServiceFeeByID(req, driverToken: driverToken, feeID: feeID)
        let paymentMethods = try await fetchPaymentMethods(req, driverToken: driverToken)
        let context = ServiceFeeEditPageContext(
            title: "Edit Service Fee",
            pageType: "service-fee-edit",
            paymentMethods: paymentMethods,
            fee: fee,
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/service-fees/fee-form-edit", context)
    }

    // PUT /:serviceFeeID
    @Sendable func handleEditFee(_ req: Request) async throws -> Response {
        let driverToken = req.session.data["driverToken"] ?? ""
        let feeID = req.parameters.get("serviceFeeID") ?? ""
        struct UpdateServiceFeeViaPayNowRequest: Content {
            let paymentMethodId: UUID
            let usMethods: [String]
            let zwMethods: [String]
            let priority: Int
            let isActive: Bool
        }
        let form = try req.content.decode(UpdateServiceFeeViaPayNowRequest.self)
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

    // Stats removed per new workflow

    // Helper methods (stubs, to be implemented)
    // Driver profile fetch removed for service-fee pages

    private func fetchPaymentMethods(_ req: Request, driverToken: String) async throws -> [PayNowPaymentMethodResponseDTO] {
        let baseURL = APIConfig.mainAppBaseURL
        let endpoint = baseURL + "/api/goflorapayment/paymentmethods"
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        guard response.status.code >= 200 && response.status.code < 300 else {
            throw Abort(response.status)
        }
        guard let responseBody = response.body else {
            throw Abort(.internalServerError, reason: "No response body")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let responseData = Data(buffer: responseBody)
        return try decoder.decode([PayNowPaymentMethodResponseDTO].self, from: responseData)
    }

    private func fetchServiceFees(_ req: Request, driverToken: String, page: Int, perPage: Int) async throws -> DriverCustomServiceFeesListResponse {
        let queryItems = [URLQueryItem(name: "page", value: "\(page)"),
                  URLQueryItem(name: "per", value: "\(perPage)")]
        let endpoint = (APIConfig.endpoints["service-fees"] ?? "urlfailed") + "/my-fees?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        return try response.content.decode(DriverCustomServiceFeesListResponse.self)
    }

    // Stats fetch removed

    private func fetchServiceFeeByID(_ req: Request, driverToken: String, feeID: String) async throws -> DriverCustomServiceFeesDTO {
        let endpoint = (APIConfig.endpoints["service-fees"] ?? "urlfailed") + "/\(feeID)"
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        return try response.content.decode(DriverCustomServiceFeesDTO.self)
    }

    private func fetchPaymentMethodByID(_ req: Request, driverToken: String, paymentMethodID: String) async throws -> PayNowPaymentMethodResponseDTO? {
        let baseURL = APIConfig.mainAppBaseURL
        let endpoint = baseURL + "/api/goflorapayment/\(paymentMethodID)"
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        guard response.status.code >= 200 && response.status.code < 300 else {
            return nil
        }
        guard let responseBody = response.body else {
            return nil
        }
        let decoder = JSONDecoder()
        let responseData = Data(buffer: responseBody)
        return try? decoder.decode(PayNowPaymentMethodResponseDTO.self, from: responseData)
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
