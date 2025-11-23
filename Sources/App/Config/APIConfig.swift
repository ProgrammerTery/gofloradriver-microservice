import Vapor

struct APIConfig {
    static let mainAppBaseURL = Environment.get("MAIN_APP_URL") ?? "http://127.0.0.1:8080"
    
    static let endpoints = [
        "drivers": "\(mainAppBaseURL)/api/gofloradrivers",
        "transportServiceTypes": "\(mainAppBaseURL)/api/transportservicetype",
        "vehicles": "\(mainAppBaseURL)/api/vehicles",
        "unsecuredDrivers": "\(mainAppBaseURL)/api/unsecureddriver"
    ]
}