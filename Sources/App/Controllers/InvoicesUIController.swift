import Vapor
import Leaf
import DriversDTO
import Foundation

// Use canonical contexts from UIPageContexts.swift

struct InvoicesUIController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let invoicesRoute = routes.grouped("products", "gofloradriver", "invoices").grouped(DriverAuthMiddleware())
        invoicesRoute.get(use: renderInvoicesList)
        invoicesRoute.get(":invoiceID", use: renderInvoiceDetails)
        invoicesRoute.post(":invoiceID", "mark-paid", use: handleMarkPaid)
        invoicesRoute.get("earnings", use: renderEarningsReport)
        invoicesRoute.get("stats", use: renderStats)
        invoicesRoute.get("generate-for-trip", ":tripID", use: renderGenerateForTrip)
        invoicesRoute.post("generate-for-trip", ":tripID", use: handleGenerateForTrip)
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
        let from: String? = req.query["from"]
        let to: String? = req.query["to"]
        let driverProfile = try await fetchDriverProfile(req)
        let report = try await fetchEarningsReport(req, driverToken: driverToken, period: period, from: from, to: to)
        let currencyEarnings: [CurrencyEarningsItem] = report?.currencyBreakdown.map { (key, value) in CurrencyEarningsItem(currency: key, earnings: value) } ?? []
        let periodOptions = buildPeriodOptions()
        let context = EarningsReportPageContext(
            title: "Earnings Report",
            pageType: "earnings-report",
            driver: driverProfile,
            report: report,
            periodOptions: periodOptions,
            currencyEarnings: currencyEarnings,
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
        guard let driverToken = req.session.data["driverToken"], !driverToken.isEmpty else {
            throw Abort.redirect(to: "/products/gofloradriver/login")
        }
        let endpoint = APIConfig.endpoints["gofloradriver-profiles"] ?? "urlfailed"
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint + "/me", driverToken: driverToken)
        return try response.content.decode(DriverProfileDTO.self)
    }

    private func fetchInvoices(_ req: Request, driverToken: String, filter: String, page: Int, perPage: Int) async throws -> DriverInvoiceListResponse {
        var queryItems = [URLQueryItem(name: "page", value: "\(page)"),
                          URLQueryItem(name: "per", value: "\(perPage)")]
        if filter == "pending" || filter == "paid" {
            queryItems.append(URLQueryItem(name: "status", value: filter))
        }
        let endpoint = (APIConfig.endpoints["invoices"] ?? "urlfailed") + "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        return try response.content.decode(DriverInvoiceListResponse.self)
    }

    private func fetchInvoiceByID(_ req: Request, driverToken: String, invoiceID: String) async throws -> DriverInvoiceDTO {
        let endpoint = (APIConfig.endpoints["invoices"] ?? "urlfailed") + "/\(invoiceID)"
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        return try response.content.decode(DriverInvoiceDTO.self)
    }

    private func fetchEarningsReport(_ req: Request, driverToken: String, period: String, from: String?, to: String?) async throws -> DriverEarningsReportDTO? {
        var queryItems: [URLQueryItem] = []
        if period == "this_month" || period == "last_month" || period == "this_week" {
            // Server may compute period based on keyword
            queryItems.append(URLQueryItem(name: "period", value: period))
        }
        if let from = from { queryItems.append(URLQueryItem(name: "from_date", value: from)) }
        if let to = to { queryItems.append(URLQueryItem(name: "to_date", value: to)) }
        let base = (APIConfig.endpoints["invoices"] ?? "urlfailed") + "/earnings"
        let endpoint = queryItems.isEmpty ? base : base + "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        return try? response.content.decode(DriverEarningsReportDTO.self)
    }

    private func fetchInvoiceStats(_ req: Request, driverToken: String) async throws -> DriverInvoiceStatsDTO? {
        let endpoint = (APIConfig.endpoints["invoices"] ?? "urlfailed") + "/stats"
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        return try? response.content.decode(DriverInvoiceStatsDTO.self)
    }

    // MARK: - Generate Invoice Flow

    @Sendable private func renderGenerateForTrip(_ req: Request) async throws -> View {
        let driverToken = req.session.data["driverToken"] ?? ""
        let tripID = req.parameters.get("tripID") ?? ""
        let driverProfile = try await fetchDriverProfile(req)
        // Fetch driver service fees to select one
        let serviceFees = try await fetchServiceFeesForDriver(req, driverToken: driverToken)
        // Basic currencies
        let currencies = ["USD", "ZWL", "ZAR", "EUR", "GBP"]
        // Prefill form context
        let context = InvoiceFormPageContext(
            title: "Generate Invoice",
            pageType: "invoice-generate",
            driver: driverProfile,
            invoice: nil,
            serviceFees: serviceFees,
            currencies: currencies,
            isEdit: false,
            tripId: tripID,
            errorMessage: req.query["error"]
        )
        return try await req.view.render("drivers/invoices/invoice-preview", context)
    }

    @Sendable private func handleGenerateForTrip(_ req: Request) async throws -> Response {
        let driverToken = req.session.data["driverToken"] ?? ""
        let tripID = req.parameters.get("tripID") ?? ""
        // Decode form data and map to CreateDriverInvoiceRequest
        let form = try req.content.decode(InvoiceFormData.self)
        guard let feesUUID = UUID(uuidString: form.driverCustomFeesId), let tripUUID = UUID(uuidString: form.tripId) else {
            return req.redirect(to: "/products/gofloradriver/invoices/generate-for-trip/\(tripID)?error=Invalid IDs")
        }
        let payload = CreateDriverInvoiceRequest(
            driverCustomFeesId: feesUUID,
            tripId: tripUUID,
            method: form.method,
            currency: form.currency,
            baseFare: form.baseFare,
            driverServiceFee: form.driverServiceFee,
            platformFee: form.platformFee,
            amount: form.baseFare + form.driverServiceFee + form.platformFee,
            status: form.status,
            paidAt: nil
        )
        let jsonData = try JSONEncoder().encode(payload)
        let buffer = req.application.allocator.buffer(data: jsonData)
        let endpoint = (APIConfig.endpoints["invoices"] ?? "urlfailed")
        let response = try await makeAPIRequest(req: req, method: .POST, endpoint: endpoint, body: buffer, driverToken: driverToken)
        if response.status == .created || response.status == .ok {
            // decode created invoice to get id
            if let created = try? response.content.decode(DriverInvoiceDTO.self), let id = created.id?.uuidString {
                return req.redirect(to: "/products/gofloradriver/invoices/\(id)?success=Invoice created")
            }
            return req.redirect(to: "/products/gofloradriver/invoices?success=Invoice created")
        } else {
            let errorData = try? response.content.decode([String: String].self)
            let error = errorData?["message"] ?? "Failed to create invoice"
            return req.redirect(to: "/products/gofloradriver/invoices/generate-for-trip/\(tripID)?error=\(error)")
        }
    }

    private func fetchServiceFeesForDriver(_ req: Request, driverToken: String) async throws -> [DriverCustomServiceFeesDTO] {
        let queryItems = [URLQueryItem(name: "page", value: "1"), URLQueryItem(name: "per", value: "100")]
        let endpoint = (APIConfig.endpoints["service-fees"] ?? "urlfailed") + "/my-fees?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        let response = try await makeAPIRequest(req: req, method: .GET, endpoint: endpoint, driverToken: driverToken)
        let list = try response.content.decode(DriverCustomServiceFeesListResponse.self)
        return list.serviceFees
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
