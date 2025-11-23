import Vapor

func routes(_ app: Application) throws {
    // Register all controllers
    try app.routes.register(collection: DriversUIController())
    try app.routes.register(collection: VehicleUIController())
    try app.routes.register(collection: TripUIController())
    
    // Root redirect to welcome page
    app.get { req in
        req.redirect(to: "/products/gofloradriver")
    }
}