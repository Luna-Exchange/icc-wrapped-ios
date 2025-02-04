# ICC Wrapped iOS SDK

ICC Wrapped SDK allows you to integrate ICC's wrapped experience into your iOS application.

## Requirements
- iOS 13.0+
- Swift 5.0+
- Xcode 13.0+

## Installation

### Swift Package Manager

The ICC Wrapped SDK is available through [Swift Package Manager](https://github.com/Luna-Exchange/icc-wrapped-ios.git).

1. In Xcode, select **File** → **Add Packages...**
2. Enter the following URL in the search field:
3. Select the version you want to use
4. Click **Add Package**


swift
dependencies: [
.package(url: "https://github.com/Luna-Exchange/icc-wrapped-ios.git", from: "1.0.0")
]

## Quick Start Guide

### 1. Import the SDK

### 2. Initialize and Present ICC Wrapped

import UIKit
import ICCWrapped

_class YourViewController: UIViewController {
    func showICCWrapped() {
        // Create user object
        let user = ICCWrapped.User(
            token: "your_auth_token",
            name: "User Name",
            email: "user@example.com"
        )_

        // Launch ICC Wrapped
        ICCWrapped.launch(
            from: self,
            user: user,
            environment: .production,
            stayInGameUri: "your_stay_in_game_url"
        ) {
            print("ICC Wrapped presented successfully")
        }
    }
}
## Complete Integration Example

Here's a complete example showing how to integrate ICC Wrapped into your app:
import UIKit
import iccwrapped

_class MainViewController: UIViewController {
    // MARK: - Properties
    private lazy var launchButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Launch ICC Wrapped", for: .normal)
        button.addTarget(self, action: #selector(launchICCWrapped), for: .touchUpInside)
        return button
    }()_
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(launchButton)
        launchButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            launchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            launchButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func launchICCWrapped() {
        guard let userData = getCurrentUser() else {
            showError("User not logged in")
            return
        }
        
        let user = ICCWrapped.User(
            token: userData.token,
            name: userData.name,
            email: userData.email
        )
        
        ICCWrapped.launch(
            from: self,
            user: user,
            environment: .production,
            stayInGameUri: "https://your-stay-in-game-url.com"
        ) {
            print("ICC Wrapped launched successfully")
        }
    }
}


## Environment Configuration

The SDK supports two environments:
swift
public enum Environment {
    case development
    case production
}
- Use `.development` for testing
- Use `.production` for release builds

## User Object

The User object requires the following parameters:
swift
let user = ICCWrapped.User(
    token: String, // Authentication token
    name: String, // User's name
    email: String // User's email
)
