# ICC Wrapped iOS SDK

[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-iOS-green.svg)](https://www.apple.com/ios/)
[![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://www.apple.com/ios/)

ICC Wrapped SDK enables seamless integration of ICC's wrapped experience into iOS applications, providing a customizable web-based interface with native callbacks and navigation controls.

## Table of Contents
- [Requirements](#requirements)
- [Installation](#installation)
- [Integration Guide](#integration-guide)
- [Configuration](#configuration)
- [Callbacks](#callbacks)

## Requirements

- iOS 14.5+
- Swift 5.0+
- Xcode 13.0+

## Installation

### Swift Package Manager

The ICC Wrapped SDK is available through [Swift Package Manager](https://github.com/Luna-Exchange/icc-wrapped-ios.git).

## Integration Guide

### Basic Implementation

1. Import the SDK:

```swift
import ICCWrapped
```

2. Create a basic integration:

```swift
class ExampleViewController: UIViewController {
    private var user: ICCWrapped.User?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUser()
    }
    
    private func setupUser() {
        user = ICCWrapped.User(
            token: "your-auth-token",
            name: "User Name",
            email: "user@example.com"
        )
    }
    
    func launchICCWrapped() {
        guard let user = user else { return }
        
        ICCWrapped.launch(
            from: self,
            user: user,
            environment: .production,
            stayInGameUri: "iccdev://stayinthegame",
            completion: {
                print("ICC Wrapped launched successfully")
            }
        )
        
        // Set up callbacks after launch
        if let iccWebView = iccWrappedSDK.sharedWrappedView {
            setupCallbacks(for: iccWebView)
        }
    }
}
```

## Configuration

### Environment Settings

```swift
public enum Environment {
    case development  // Uses staging URL
    case production   // Uses production URL
}
```

### User Configuration

```swift
let user = ICCWrapped.User(
    token: "your-auth-token",    // Authentication token
    name: "User Name",           // User's name
    email: "user@example.com"    // User's email
)
```
## URI to be pass
```
    stayInGameUri: "iccdev://stayinthegame"
```

## Share and Download

### 1. Share is handled Natively
### 2. Download is also handled natively


## Callbacks

### Setting Up Callbacks
####

```swift
private func setupCallbacks(for iccWebView: ICCWebView) {
    // Handle navigation to ICC
    iccWebView.navigateToICCAction = { [weak self] viewController in
        self?.handleNavigateToICC(from: viewController)
    }
    
    // Handle navigation to Stay in the Game
    iccWebView.navigateToStayInTheGame = { [weak self] viewController in
        self?.handleNavigateToStayInTheGame(from: viewController)
    }
        // Handle navigation to Handle Login
    iccWebView.signInWithIcc = { [weak self] viewController in
        self?.handleSignInWithIcc(from: viewController)
    }
    
    // Handle closing the wrapped view
    iccWebView.closeTheWrapped = { [weak self] success in
        self?.handleCloseWrapped(success: success)
    }
}

private func handleNavigateToICC(from viewController: UIViewController) {
    viewController.dismiss(animated: true) {
        // Add your ICC navigation logic here
    }
}
    
private func handleSignInWithIcc(from viewController: UIViewController) {
    viewController.dismiss(animated: true) {
        // Add your ICC navigation logic here
    }
}

private func handleNavigateToStayInTheGame(from viewController: UIViewController) {
    // Add your Stay in the Game navigation logic here
}

private func handleCloseWrapped(success: Bool) {
    // Add your cleanup or post-close logic here
}
```
