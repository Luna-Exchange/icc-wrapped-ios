# ICC Recapped iOS SDK

[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-iOS-green.svg)](https://www.apple.com/ios/)
[![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://www.apple.com/ios/)

ICC Recapped SDK enables seamless integration of ICC's recapped experience into iOS applications, providing a customizable web-based interface with native callbacks and navigation controls.

## Table of Contents
- [Requirements](#requirements)
- [Installation](#installation)
- [Integration Guide](#integration-guide)
- [Configuration](#configuration)
- [Media Features](#media-features)
- [Callbacks](#callbacks)

## Requirements

- iOS 14.5+
- Swift 5.0+
- Xcode 13.0+

## Installation

### Swift Package Manager

The ICC Recapped SDK is available through [Swift Package Manager](https://github.com/Luna-Exchange/icc-wrapped-ios.git).

## Tag version
    ### 1.4.3

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
                print("ICC Recapped launched successfully")
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

The SDK supports two environments:

```swift
public enum Environment {
    case development  // Uses staging URL
    case production   // Uses production URL
}
```

### User Configuration

Configure user details for authentication:

```swift
let user = ICCWrapped.User(
    token: "your-auth-token",    // Authentication token
    name: "User Name",           // User's name
    email: "user@example.com"    // User's email
)
```

### URI Configuration

Configure the URI for the "Stay in the Game" feature:

```swift
stayInGameUri: "iccdev://stayinthegame"
```

## Media Features

### 1. Sharing Images

Images are handled natively through the iOS Share Sheet. When a user triggers an image share action, the SDK will present the standard iOS share sheet with available options for the user to share the image.

### 2. Downloading Images

Image downloading is handled natively by the SDK. When a user selects to download an image, it will be saved directly to the device's photo library.

### Required Permissions

To enable image downloading functionality, you must add the following permissions to your app's Info.plist:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need access to save images to your photo library when you download content from the ICC Recapped experience.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app requires access to your photo library to upload and share photos.</string>
```

This permission will prompt the user to allow your app to save images to their photo library the first time they attempt to download an image.

## Callbacks

### Setting Up Callbacks

Register callback handlers to respond to user actions:

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
    iccWebView.signInWithIccCompletion = { [weak self] success in
        self?.handleSignInWithIcc(success: success)
    }
    
    // Handle closing the wrapped view
    iccWebView.closeTheWrapped = { [weak self] success in
        self?.handleCloseWrapped(success: success)
    }
}
```

### Implementing Callback Handlers

```swift
private func handleNavigateToICC(from viewController: UIViewController) {
    viewController.dismiss(animated: true) {
        // Add your ICC navigation logic here
    }
}
    
private func handleSignInWithIcc(success: Bool) {
    if success {
        // Handle successful login
    } else {
        // Handle login failure
    }
}

private func handleNavigateToStayInTheGame(from viewController: UIViewController) {
    // Add your Stay in the Game navigation logic here
}

private func handleCloseWrapped(success: Bool) {
    // Add your cleanup or post-close logic here
}
```
