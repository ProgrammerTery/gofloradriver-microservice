import Vapor

// MARK: - Vehicle Registration DTOs

struct ServiceTypeSelectionContext: Content {
    let title: String
    let pageType: String
    let driverID: String
    let driverName: String
    let serviceTypes: [ServiceTypeContext]
    let errorMessage: String?
}

struct ServiceTypeContext: Content {
    let id: String
    let name: String
    let description: String
    let baseRate: Double
}

struct ServiceTypeSelectionFormData: Content {
    let serviceTypeID: String
}

struct VehicleRegistrationPageContext: Content {
    let title: String
    let pageType: String
    let driverID: String
    let driverName: String
    let selectedServiceType: ServiceTypeContext?
    let errorMessage: String?
}

struct VehicleRegistrationFormData: Content {
    let make: String
    let model: String
    let year: Int
    let licensePlate: String
    let color: String
    let serviceTypeID: String
}

struct VehicleConfirmationContext: Content {
    let title: String
    let pageType: String
    let driverName: String
    let vehicle: VehicleContext
    let serviceType: ServiceTypeContext
}

struct VehicleContext: Content {
    let make: String
    let model: String
    let year: Int
    let licensePlate: String
    let color: String
}