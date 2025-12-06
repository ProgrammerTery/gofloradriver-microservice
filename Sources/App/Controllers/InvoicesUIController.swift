import Vapor
import Leaf
import DriversDTO
import Foundation

struct InvoicesUIController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let invoicesRoute = routes.grouped("products", "gofloradriver", "invoices").grouped(DriverAuthMiddleware())
        invoicesRoute.get(use: renderInvoicesList)
        invoicesRoute.get(":invoiceID", use: renderInvoiceDetails)
        invoicesRoute.post(":invoiceID", "mark-paid", use: handleMarkPaid)
        invoicesRoute.get("earnings", use: renderEarningsReport)
        invoicesRoute.get("stats", use: renderStats)
    }

    // GET /invoices
    @Sendable func renderInvoicesList(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let filter = req.query["filter"] ?? "all"
        let page = Int(req.query["page"] ?? "1") ?? 1
        let perPage = 25
        let driverProfile = try await fetchDriverProfile(req)
        let invoicesResponse = try await fetchInvoices(req, driverToken: driverToken, filter: filter, page: page, perPage: perPage)
        let totalPages = Int(ceil(Double(invoicesResponse.total) / Double(perPage)))
        let context = InvoicesListPageContext(
            title: "My Invoices",
            pageType: "invoices-list",
            driver: driverProfile,
            invoices: invoicesResponse.invoices,
            stats: nil,
            total: invoicesResponse.total,
            page: page,
            perPage: perPage,
            totalAmount: invoicesResponse.totalAmount,
            paidAmount: invoicesResponse.paidAmount,
            pendingAmount: invoicesResponse.pendingAmount,
            filter: filter,
            successMessage: req.query["success"],
            errorMessage: req.query["error"],
            totalPages: totalPages,
            hasNextPage: page < totalPages,
            hasPrevPage: page > 1
        )
        return try await req.view.render("drivers/invoices/list", context)
    }

    // GET /invoices/:invoiceID
    @Sendable func renderInvoiceDetails(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let invoiceID = req.parameters.get("invoiceID") ?? ""
        let driverProfile = try await fetchDriverProfile(req)
        let invoice = try await fetchInvoiceByID(req, driverToken: driverToken, invoiceID: invoiceID)
        let canMarkPaid = invoice.status == "pending"
        let context = InvoiceDetailsPageContext(
            title: "Invoice Details",
            pageType: "invoice-details",
            driver: driverProfile,
            invoice: invoice,
            canMarkPaid: canMarkPaid,
            successMessage: req.query["success"],
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/invoices/details", context)
    }

    // POST /invoices/:invoiceID/mark-paid
    @Sendable func handleMarkPaid(_ req: Request) async throws -> Response {
        let driverToken = req.session.data["driverToken"] ?? ""
        let invoiceID = req.parameters.get("invoiceID") ?? ""
        let endpoint = (APIConfig.endpoints["invoices"] ?? "urlfailed") + "/\(invoiceID)/mark-paid"
        let response = try await makeAPIRequest(req: req, method: .POST, endpoint: endpoint, driverToken: driverToken)
        if response.status == .ok {
            return req.redirect(to: "/products/gofloradriver/invoices/\(invoiceID)?success=Invoice marked as paid")
        } else {
            let errorData = try? response.content.decode([String: String].self)
            let error = errorData?["message"] ?? "Failed to mark invoice as paid"
            return req.redirect(to: "/products/gofloradriver/invoices/\(invoiceID)?error=\(error)")
        }
    }

    // GET /invoices/earnings
    @Sendable func renderEarningsReport(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let period = req.query["period"] ?? "this_month"
        let from = req.query["from"]
        let to = req.query["to"]
        let driverProfile = try await fetchDriverProfile(req)
        let report = try await fetchEarningsReport(req, driverToken: driverToken, period: period, from: from, to: to)
        let currencyEarnings = report?.currencyBreakdown.map { (key, value) in (currency: key, earnings: value) } ?? []
        let periodOptions = buildPeriodOptions()
        let context = EarningsReportPageContext(
            title: "Earnings Report",
            pageType: "earnings-report",
            driver: driverProfile,
            report: report,
            currencyEarnings: currencyEarnings,
            periodOptions: periodOptions,
            selectedPeriod: period
        )
        return try await req.view.render("drivers/invoices/earnings", context)
    }

    // GET /invoices/stats
    @Sendable func renderStats(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let driverProfile = try await fetchDriverProfile(req)
        let stats = try await fetchInvoiceStats(req, driverToken: driverToken)
        let context = InvoiceStatsPageContext(
            title: "Invoice Statistics",
            pageType: "invoice-stats",
            driver: driverProfile,
            stats: stats
        )
        return try await req.view.render("drivers/invoices/stats", context)
    }

    // Helper methods (stubs, to be implemented)
    private func fetchDriverProfile(_ req: Request) async throws -> DriverProfileDTO {
        // ...existing code...
        return DriverProfileDTO(driverID: "", driverName: "", driverPhone: "", driverEmail: "", driverAddress: "", registrationDate: Date(), driverLicense: "", vehicle_id: nil)
    }
    private func fetchInvoices(_ req: Request, driverToken: String, filter: String, page: Int, perPage: Int) async throws -> DriverInvoiceListResponse {
        // ...existing code...
        return DriverInvoiceListResponse(invoices: [], total: 0, page: page, perPage: perPage, totalAmount: 0, paidAmount: 0, pendingAmount: 0)
    }
    private func fetchInvoiceByID(_ req: Request, driverToken: String, invoiceID: String) async throws -> DriverInvoiceDTO {
        // ...existing code...
        throw Abort(.notFound)
    }
    private func fetchEarningsReport(_ req: Request, driverToken: String, period: String, from: String?, to: String?) async throws -> DriverEarningsReportDTO? {
        // ...existing code...
        return nil
    }
    private func fetchInvoiceStats(_ req: Request, driverToken: String) async throws -> DriverInvoiceStatsDTO? {
        // ...existing code...
        return nil
    }
    private func buildPeriodOptions() -> [PeriodOption] {
        return [
            PeriodOption(value: "this_week", label: "This Week", from: "", to: ""),
            PeriodOption(value: "this_month", label: "This Month", from: "", to: ""),
            PeriodOption(value: "last_month", label: "Last Month", from: "", to: ""),
            PeriodOption(value: "custom", label: "Custom Range", from: "", to: "")
        ]
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
