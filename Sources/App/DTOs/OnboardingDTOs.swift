import Vapor

// MARK: - Onboarding DTOs

struct WelcomePageContext: Content {
    let title: String
    let pageType: String
}

struct JoinDriverPageContext: Content {
    let title: String
    let pageType: String
}

struct SignupPageContext: Content {
    let title: String
    let pageType: String
    let errorMessage: String?
}

struct SignupFormData: Content {
    let email: String
    let password: String
    let confirmPassword: String
}

struct DriverRegistrationPageContext: Content {
    let title: String
    let pageType: String
    let errorMessage: String?
    let prefillData: DriverRegistrationFormData?
}

struct DriverRegistrationFormData: Content {
    let driverID: String
    let driverName: String
    let driverPhone: String
    let driverEmail: String
    let driverAddress: String
    let driverLicense: String
}

struct VehicleChoicePageContext: Content {
    let title: String
    let pageType: String
    let driverID: String
    let driverName: String
}

struct VehicleChoiceFormData: Content {
    let registerVehicleNow: Bool
}

struct RegistrationSuccessContext: Content {
    let title: String
    let pageType: String
    let driverName: String
    let hasVehicle: Bool
    let nextStepURL: String
}