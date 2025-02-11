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
```
import UIKit
import ICCWrapped

class YourViewController: UIViewController {
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
```

### 2. Handle "Stay in the Game" Callback

```swift
class YourViewController: UIViewController {
    func launchWrapped() {
        // Create the ICCWebView instance
        let urls = URLS(stayinthegame: "your-stay-in-game-uri")
        let webViewController = ICCWebView(environment: .production, urls: urls)
        
        // Set up the Stay in the Game callback
        webViewController.navigateToStayInTheGame = { [weak self] viewController in
            // Handle navigation to Stay in the Game
            self?.handleStayInTheGame(from: viewController)
        }
        
        // Set up close callback if needed
        webViewController.closeTheWrapped = { success in
            if success {
                // Handle successful closure
                self.dismiss(animated: true)
            }
        }
        
        // Update user data and present
        let userData = UserData(
            token: "your-auth-token",
            name: "User Name",
            email: "user@example.com"
        )
        iccWrappedSDK.update(userData: userData)
        webViewController.presentAndHandleCallbacks(from: self)
    }
    
    private func handleStayInTheGame(from viewController: UIViewController) {
        // Dismiss the current wrapped view
        viewController.dismiss(animated: true) { [weak self] in
            // Navigate to your Stay in the Game screen
            self?.navigateToStayInTheGame()
        }
    }
    
    private func navigateToStayInTheGame() {
        // Implement your navigation logic here
        // For example:
        let stayInGameVC = StayInGameViewController()
        self.navigationController?.pushViewController(stayInGameVC, animated: true)
    }
}
```


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
