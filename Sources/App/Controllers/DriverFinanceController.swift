import Vapor
import Leaf
import DriversDTO
import Foundation

struct DriverFinanceController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let financeRoute = routes.grouped("products", "gofloradriver", "finance")

        // Service Fees Routes
        financeRoute.get("service-fees", use: renderServiceFeesPage)
        financeRoute.get("service-fees", "new", use: renderCreateServiceFeePage)
        financeRoute.post("service-fees", use: createServiceFee)
        financeRoute.get("service-fees", ":serviceFeeID", "edit", use: renderEditServiceFeePage)
        financeRoute.post("service-fees", ":serviceFeeID", "update", use: updateServiceFee)
        financeRoute.post("service-fees", ":serviceFeeID", "delete", use: deleteServiceFee)
        financeRoute.post("service-fees", ":serviceFeeID", "toggle", use: toggleServiceFee)

        // Invoice Routes
        financeRoute.get("invoices", use: renderInvoicesPage)
        financeRoute.get("invoices", "stats", use: renderInvoiceStatsPage)
        financeRoute.get("invoices", "earnings", use: renderEarningsReportPage)
        financeRoute.get("invoices", ":invoiceID", use: renderInvoiceDetailPage)
        financeRoute.post("invoices", ":invoiceID", "mark-paid", use: markInvoicePaid)
    }

    // MARK: - Service Fees Handlers

    @Sendable func renderServiceFeesPage(_ req: Request) async throws -> View {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        do {
            let serviceFees = try await fetchServiceFees(req)
            let stats = try await fetchServiceFeesStats(req)

            let context = ServiceFeesPageContext(
                title: "Service Fees Management",
                pageType: "finance",
                serviceFees: serviceFees.serviceFees,
                stats: stats,
                pagination: PaginationContextDTO(
                    currentPage: serviceFees.page,
                    totalPages: (serviceFees.total + serviceFees.perPage - 1) / serviceFees.perPage,
                    total: serviceFees.total,
                    perPage: serviceFees.perPage
                )
            )

            return try await req.view.render("drivers/finance/service-fees", context)

        } catch {
            req.logger.error("Failed to fetch service fees: \(error)")
            throw error
        }
    }

    @Sendable func renderCreateServiceFeePage(_ req: Request) async throws -> View {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        let context = CreateServiceFeePageContext(
            title: "Create Service Fee",
            pageType: "finance",
            currencies: ["USD", "EUR", "GBP", "CAD", "AUD"],
            paymentMethods: try await fetchPaymentMethods(req)
        )

        return try await req.view.render("drivers/finance/create-service-fee", context)
    }

    @Sendable func createServiceFee(_ req: Request) async throws -> Response {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        let createRequest = try req.content.decode(CreateDriverCustomServiceFeesRequest.self)
        let jsonData = try JSONEncoder().encode(createRequest)
        let buffer = req.application.allocator.buffer(data: jsonData)

        do {
            _ = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: "/api/driver/service-fees",
                body: buffer,
                driverToken:driverToken
            )

            req.session.data["success_message"] = "Service fee created successfully"
            return req.redirect(to: "/products/gofloradriver/finance/service-fees")

        } catch {
            req.logger.error("Failed to create service fee: \(error)")
            req.session.data["error_message"] = "Failed to create service fee: \(error.localizedDescription)"
            return req.redirect(to: "/products/gofloradriver/finance/service-fees/new")
        }
    }

    @Sendable func renderEditServiceFeePage(_ req: Request) async throws -> View {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        guard let serviceFeeID = req.parameters.get("serviceFeeID") else {
            throw Abort(.badRequest)
        }

        do {
            let serviceFeeResponse = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: "/api/driver/service-fees/\(serviceFeeID)",
                driverToken: driverToken
            )

            let serviceFee = try serviceFeeResponse.content.decode(DriverCustomServiceFeesDTO.self)

            let context = EditServiceFeePageContext(
                title: "Edit Service Fee",
                pageType: "finance",
                serviceFee: serviceFee,
                currencies: ["USD", "EUR", "GBP", "CAD", "AUD"],
                paymentMethods: try await fetchPaymentMethods(req)
            )

            return try await req.view.render("drivers/finance/edit-service-fee", context)

        } catch {
            req.logger.error("Failed to fetch service fee: \(error)")
            throw error
        }
    }

    @Sendable func updateServiceFee(_ req: Request) async throws -> Response {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        guard let serviceFeeID = req.parameters.get("serviceFeeID") else {
            throw Abort(.badRequest)
        }

        let updateRequest = try req.content.decode(UpdateDriverCustomServiceFeesRequest.self)

        let jsonData = try JSONEncoder().encode(updateRequest)
        let buffer = req.application.allocator.buffer(data: jsonData)

        do {
            _ = try await makeAPIRequest(
                req: req,
                method: .PUT,
                endpoint: "/api/driver/service-fees/\(serviceFeeID)",
                 body: buffer,
                driverToken: driverToken
            )

            req.session.data["success_message"] = "Service fee updated successfully"
            return req.redirect(to: "/products/gofloradriver/finance/service-fees")

        } catch {
            req.logger.error("Failed to update service fee: \(error)")
            req.session.data["error_message"] = "Failed to update service fee: \(error.localizedDescription)"
            return req.redirect(to: "/products/gofloradriver/finance/service-fees/\(serviceFeeID)/edit")
        }
    }

    @Sendable func deleteServiceFee(_ req: Request) async throws -> Response {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        guard let serviceFeeID = req.parameters.get("serviceFeeID") else {
            throw Abort(.badRequest)
        }

        do {
            try await makeAPIRequest(
                req: req,
                method: .DELETE,
                endpoint: "/api/driver/service-fees/\(serviceFeeID)",
                driverToken: driverToken
            )

            req.session.data["success_message"] = "Service fee deleted successfully"
            return req.redirect(to: "/products/gofloradriver/finance/service-fees")

        } catch {
            req.logger.error("Failed to delete service fee: \(error)")
            req.session.data["error_message"] = "Failed to delete service fee: \(error.localizedDescription)"
            return req.redirect(to: "/products/gofloradriver/finance/service-fees")
        }
    }

    @Sendable func toggleServiceFee(_ req: Request) async throws -> Response {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        guard let serviceFeeID = req.parameters.get("serviceFeeID") else {
            throw Abort(.badRequest)
        }

        do {
            _ = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: "/api/driver/service-fees/\(serviceFeeID)/toggle-active",
                driverToken: driverToken
            )

            req.session.data["success_message"] = "Service fee status updated successfully"
            return req.redirect(to: "/products/gofloradriver/finance/service-fees")

        } catch {
            req.logger.error("Failed to toggle service fee: \(error)")
            req.session.data["error_message"] = "Failed to update service fee status: \(error.localizedDescription)"
            return req.redirect(to: "/products/gofloradriver/finance/service-fees")
        }
    }

    // MARK: - Invoice Handlers

    @Sendable func renderInvoicesPage(_ req: Request) async throws -> View {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        do {
            let invoices = try await fetchInvoices(req)
            let stats = try await fetchInvoiceStats(req)

            let context = InvoicesPageContext(
                title: "Invoice Management",
                pageType: "finance",
                invoices: invoices.invoices,
                stats: stats,
                pagination: PaginationContextDTO(
                    currentPage: invoices.page,
                    totalPages: (invoices.total + invoices.perPage - 1) / invoices.perPage,
                    total: invoices.total,
                    perPage: invoices.perPage
                ),
                totalAmount: invoices.totalAmount,
                paidAmount: invoices.paidAmount,
                pendingAmount: invoices.pendingAmount
            )

            return try await req.view.render("drivers/finance/invoices", context)

        } catch {
            req.logger.error("Failed to fetch invoices: \(error)")
            throw error
        }
    }

    @Sendable func renderInvoiceStatsPage(_ req: Request) async throws -> View {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        do {
            let stats = try await fetchInvoiceStats(req)

            let context = InvoiceStatsPageContext(
                title: "Invoice Statistics",
                pageType: "finance",
                stats: stats
            )

            return try await req.view.render("drivers/finance/invoice-stats", context)

        } catch {
            req.logger.error("Failed to fetch invoice stats: \(error)")
            throw error
        }
    }

    @Sendable func renderEarningsReportPage(_ req: Request) async throws -> View {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        do {
            let earningsReport = try await fetchEarningsReport(req)

            let context = EarningsReportPageContext(
                title: "Earnings Report",
                pageType: "finance",
                report: earningsReport
            )

            return try await req.view.render("drivers/finance/earnings-report", context)

        } catch {
            req.logger.error("Failed to fetch earnings report: \(error)")
            throw error
        }
    }

    @Sendable func renderInvoiceDetailPage(_ req: Request) async throws -> View {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        guard let invoiceID = req.parameters.get("invoiceID") else {
            throw Abort(.badRequest)
        }

        do {
            let invoiceresponse = try await makeAPIRequest(
                req: req,
                method: .GET,
                endpoint: "/api/driver/invoices/\(invoiceID)",
                driverToken: driverToken
            )
             let invoice = try  invoiceresponse.content.decode(DriverInvoiceDTO.self)

            if let id = invoice.id {
            } else {
                   throw Abort(.notFound, reason: "Invoice not found")
               }



            let context = InvoiceDetailPageContext(
                title: "Invoice Details",
                pageType: "finance",
                invoice: invoice
            )

            return try await req.view.render("drivers/finance/invoice-detail", context)

        } catch {
            req.logger.error("Failed to fetch invoice: \(error)")
            throw error
        }
    }

    @Sendable func markInvoicePaid(_ req: Request) async throws -> Response {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }

        guard let invoiceID = req.parameters.get("invoiceID") else {
            throw Abort(.badRequest)
        }

        let markPaidRequest = try req.content.decode(MarkInvoicePaidRequest.self)
        let jsonData = try JSONEncoder().encode(markPaidRequest)
        let buffer = req.application.allocator.buffer(data: jsonData)

        do {
            _ = try await makeAPIRequest(
                req: req,
                method: .POST,
                endpoint: "/api/driver/invoices/\(invoiceID)/mark-paid",
                body: buffer,
                driverToken: driverToken
            )

            req.session.data["success_message"] = "Invoice marked as paid successfully"
            return req.redirect(to: "/products/gofloradriver/finance/invoices/\(invoiceID)")

        } catch {
            req.logger.error("Failed to mark invoice as paid: \(error)")
            req.session.data["error_message"] = "Failed to mark invoice as paid: \(error.localizedDescription)"
            return req.redirect(to: "/products/gofloradriver/finance/invoices/\(invoiceID)")
        }
    }

    // MARK: - API Helper Methods

    private func fetchServiceFees(_ req: Request) async throws -> DriverCustomServiceFeesListResponse {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }
        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = req.query[Int.self, at: "per"] ?? 20
        let active = req.query[Bool.self, at: "active"]

        var queryItems = [URLQueryItem(name: "page", value: "\(page)"),
                          URLQueryItem(name: "per", value: "\(perPage)")]

        if let active = active {
            queryItems.append(URLQueryItem(name: "active", value: "\(active)"))
        }

        let endpoint = "/api/driver/service-fees/my-fees?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")

      return try await makeAPIRequest(
            req: req,
            method: .GET,
            endpoint: endpoint,
            driverToken: driverToken
        ).content.decode(DriverCustomServiceFeesListResponse.self)
    }

    private func fetchServiceFeesStats(_ req: Request) async throws -> DriverServiceFeesStatsDTO {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }
        return try await makeAPIRequest(
            req: req,
            method: .GET,
            endpoint: "/api/driver/service-fees/stats",
            driverToken: driverToken
        ).content.decode(DriverServiceFeesStatsDTO.self)
    }

    private func fetchInvoices(_ req: Request) async throws -> DriverInvoiceListResponse {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }
        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = req.query[Int.self, at: "per"] ?? 20
        let status = req.query[String.self, at: "status"]

        var queryItems = [URLQueryItem(name: "page", value: "\(page)"),
                          URLQueryItem(name: "per", value: "\(perPage)")]

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }

        let endpoint = "/api/driver/invoices?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")

        return try await makeAPIRequest(
            req: req,
            method: .GET,
            endpoint: endpoint,
            driverToken: driverToken
        ).content.decode(DriverInvoiceListResponse.self)
    }

    private func fetchInvoiceStats(_ req: Request) async throws -> DriverInvoiceStatsDTO {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }
        return try await makeAPIRequest(
            req: req,
            method: .GET,
            endpoint: "/api/driver/invoices/stats",
            driverToken: driverToken
        ).content.decode(DriverInvoiceStatsDTO.self)
    }

    private func fetchEarningsReport(_ req: Request) async throws -> DriverEarningsReportDTO {
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }
        let fromDate = req.query[String.self, at: "from_date"]
        let toDate = req.query[String.self, at: "to_date"]

        var queryItems = [URLQueryItem]()

        if let fromDate = fromDate {
            queryItems.append(URLQueryItem(name: "from_date", value: fromDate))
        }
        if let toDate = toDate {
            queryItems.append(URLQueryItem(name: "to_date", value: toDate))
        }

        let endpoint = "/api/driver/invoices/earnings" + (queryItems.isEmpty ? "" : "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&"))

        return try await makeAPIRequest(
            req: req,
            method: .GET,
            endpoint: endpoint,
           driverToken: driverToken
        ).content.decode(DriverEarningsReportDTO.self)
    }

    private func fetchPaymentMethods(_ req: Request) async throws -> [PaymentMethodDTO] {
        guard let driverToken = req.session.data["driverToken"] else {
            throw Abort(.unauthorized)
        }

        let baseURL = APIConfig.mainAppBaseURL
        let endpoint = baseURL + "/api/payment-methods"

        let response = try await makeAPIRequest(
            req: req,
            method: .GET,
            endpoint: endpoint,
            body: nil,
            driverToken: driverToken
        )

        guard response.status.code >= 200 && response.status.code < 300 else {
            throw Abort(response.status)
        }

        guard let responseBody = response.body else {
            throw Abort(.internalServerError, reason: "No response body")
        }

        let decoder = JSONDecoder()
        let responseData = Data(buffer: responseBody)
        return try decoder.decode([PaymentMethodDTO].self, from: responseData)
    }

  


}

// MARK: - Context Models

struct ServiceFeesPageContext: Content {
    let title: String
    let pageType: String
    let serviceFees: [DriverCustomServiceFeesDTO]
    let stats: DriverServiceFeesStatsDTO
    let pagination: PaginationContextDTO
}

struct CreateServiceFeePageContext: Content {
    let title: String
    let pageType: String
    let currencies: [String]
    let paymentMethods: [PaymentMethodDTO]
}

struct EditServiceFeePageContext: Content {
    let title: String
    let pageType: String
    let serviceFee: DriverCustomServiceFeesDTO
    let currencies: [String]
    let paymentMethods: [PaymentMethodDTO]
}

struct InvoicesPageContext: Content {
    let title: String
    let pageType: String
    let invoices: [DriverInvoiceDTO]
    let stats: DriverInvoiceStatsDTO
    let pagination: PaginationContextDTO
    let totalAmount: Double
    let paidAmount: Double
    let pendingAmount: Double
}

struct InvoiceStatsPageContext: Content {
    let title: String
    let pageType: String
    let stats: DriverInvoiceStatsDTO
}

struct EarningsReportPageContext: Content {
    let title: String
    let pageType: String
    let report: DriverEarningsReportDTO
}

struct InvoiceDetailPageContext: Content {
    let title: String
    let pageType: String
    let invoice: DriverInvoiceDTO
}

struct PaginationContextDTO: Content {
    let currentPage: Int
    let totalPages: Int
    let total: Int
    let perPage: Int
}

struct PaymentMethodDTO: Content {
    let id: UUID
    let name: String
    let description: String?
    let isActive: Bool
}
