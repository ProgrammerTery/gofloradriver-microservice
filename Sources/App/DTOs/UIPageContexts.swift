import Vapor
import Foundation
import DriversDTO

// Service Fees Contexts
struct ServiceFeesListPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO
    let serviceFees: [DriverCustomServiceFeesDTO]
    let stats: DriverServiceFeesStatsDTO?
    let total: Int
    let page: Int
    let perPage: Int
    let paymentMethods: [PayNowPaymentMethodResponseDTO]
    let successMessage: String?
    let errorMessage: String?
    let totalPages: Int
    let hasNextPage: Bool
    let hasPrevPage: Bool
}

struct ServiceFeeFormPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO
    let fee: DriverCustomServiceFeesDTO?
    let paymentMethods: [PayNowPaymentMethodResponseDTO]
    let currencies: [String]
    let isEdit: Bool
    let errorMessage: String?
}

struct ServiceFeeDetailsPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO
    let fee: DriverCustomServiceFeesDTO
    let paymentMethod: PayNowPaymentMethodResponseDTO?
    let successMessage: String?
    let errorMessage: String?
}

struct CurrencyStatItem: Content {
    let currency: String
    let stats: CurrencyStatsDTO
}

struct ServiceFeesStatsPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO
    let stats: DriverServiceFeesStatsDTO?
    let currencyStats: [CurrencyStatItem]
}

// Invoices Contexts
struct InvoicesListPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO
    let invoices: [DriverInvoiceDTO]
    let stats: DriverInvoiceStatsDTO?
    let total: Int
    let page: Int
    let perPage: Int
    let totalAmount: Double
    let paidAmount: Double
    let pendingAmount: Double
    let filter: String
    let successMessage: String?
    let errorMessage: String?
    let totalPages: Int
    let hasNextPage: Bool
    let hasPrevPage: Bool
}

struct InvoiceStatsPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO
    let stats: DriverInvoiceStatsDTO?
}

struct InvoiceDetailsPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO
    let invoice: DriverInvoiceDTO
    let canMarkPaid: Bool
    let successMessage: String?
    let errorMessage: String?
}

struct PeriodOption: Content {
    let value: String
    let label: String
    let from: String
    let to: String
}

struct CurrencyEarningsItem: Content {
    let currency: String
    let earnings: CurrencyEarningsDTO
}

struct EarningsReportPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO
    let report: DriverEarningsReportDTO?
    let periodOptions: [PeriodOption]
    let currencyEarnings: [CurrencyEarningsItem]
    let selectedPeriod: String
}

struct InvoiceFormPageContext: Content {
    let title: String
    let pageType: String
    let driver: DriverProfileDTO?
    let invoice: DriverInvoiceDTO?
    let serviceFees: [DriverCustomServiceFeesDTO]
    let currencies: [String]
    let isEdit: Bool
    let tripId: String?
    let errorMessage: String?
}

struct InvoiceFormData: Content {
    let driverCustomFeesId: String
    let tripId: String
    let method: String
    let currency: String
    let baseFare: Double
    let driverServiceFee: Double
    let platformFee: Double
    let status: String
}

// Vehicles Page Contexts
public struct VehiclesListContext: Content {
    public let title: String
    public let pageType: String
    public let driverName: String
    public let vehicles: [VehicleDTO]
    public let successMessage: String?
    public let errorMessage: String?
}

public struct VehicleDeleteConfirmationContext: Content {
    public let title: String
    public let pageType: String
    public let driverName: String
    public let vehicle: VehicleDTO
    public let errorMessage: String?
}
