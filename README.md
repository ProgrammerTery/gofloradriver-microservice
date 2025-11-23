# GoFlora Driver Microservice

A Vapor-based microservice for managing driver operations in the GoFlora transportation platform.

## Overview

This microservice handles driver registration, onboarding, vehicle management, and driver-related UI operations. Built with Swift Vapor framework, it provides a web-based interface for drivers to register and manage their vehicles.

## Features

- **Driver Registration & Authentication**
  - Driver signup and registration
  - Session-based authentication middleware
  - Registration success confirmation

- **Vehicle Management**
  - Service type selection (Economy, Premium, SUV)
  - Vehicle registration with make, model, year, license plate, and color
  - Vehicle confirmation and validation

- **Web UI**
  - Responsive driver onboarding interface
  - Vehicle registration forms
  - Landing pages and welcome screens

## Tech Stack

- **Framework**: Vapor 4.89.0+ (Swift server-side framework)
- **Template Engine**: Leaf 4.2.4+ (for server-side rendering)
- **Platform**: macOS 13+
- **Language**: Swift 5.9+

## Project Structure

```
├── Sources/
│   └── App/
│       ├── Controllers/          # Route handlers
│       │   ├── DriversUIController.swift
│       │   ├── VehicleUIController.swift
│       │   └── TripUIController.swift
│       ├── DTOs/                 # Data Transfer Objects
│       │   ├── OnboardingDTOs.swift
│       │   ├── VehicleDTOs.swift
│       │   └── TripDTOs.swift
│       ├── Config/               # Configuration files
│       │   └── APIConfig.swift
│       ├── configure.swift       # App configuration
│       ├── entrypoint.swift     # App entry point
│       └── routes.swift         # Route definitions
├── Resources/
│   └── Views/                   # Leaf templates
│       └── drivers/
│           ├── auth/            # Authentication views
│           ├── landing/         # Landing pages
│           └── vehicle/         # Vehicle management views
├── Public/                      # Static assets
│   ├── css/
│   └── js/
└── Tests/                      # Test files
```

## Installation

### Prerequisites

- Xcode 14.0+ or Swift 5.9+ toolchain
- macOS 13+

### Setup

1. Clone the repository:
```bash
git clone https://github.com/[your-username]/gofloradriver-microservice.git
cd gofloradriver-microservice
```

2. Install dependencies:
```bash
swift package resolve
```

3. Build the project:
```bash
swift build
```

4. Run the application:
```bash
swift run
```

The server will start on `http://localhost:8080`

## API Endpoints

### Driver Registration
- `GET /products/gofloradriver/register` - Driver registration form
- `POST /products/gofloradriver/register` - Handle driver registration
- `GET /products/gofloradriver/success` - Registration success page

### Vehicle Management
- `GET /products/gofloradriver/vehicle/service-type` - Service type selection
- `POST /products/gofloradriver/vehicle/service-type` - Handle service type selection
- `GET /products/gofloradriver/vehicle/register` - Vehicle registration form
- `POST /products/gofloradriver/vehicle/register` - Handle vehicle registration
- `GET /products/gofloradriver/vehicle/confirm` - Vehicle confirmation page

### Landing Pages
- `GET /products/gofloradriver/` - Welcome page
- `GET /products/gofloradriver/join` - Join driver page

## Configuration

The application uses `APIConfig.swift` to manage external API endpoints. Update the configuration as needed for your environment.

## Development

### Running in Development
```bash
swift run App serve --env development
```

### Running Tests
```bash
swift test
```

### Code Style
This project follows Swift standard coding conventions. Please ensure your code is properly formatted before submitting.

## Dependencies

- [Vapor](https://github.com/vapor/vapor) - Web framework
- [Leaf](https://github.com/vapor/leaf) - Templating engine
- [GoFloraSharedPackage](https://github.com/ProgrammerTery/GoFloraSharedPackage) - Shared DTOs and utilities

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is part of the GoFlora transportation platform.

## Support

For questions or support, please contact the GoFlora development team.