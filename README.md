Here's a README documentation for the ICC Wrapped SDK:

# ICC Wrapped SDK

## Overview
The ICC Wrapped SDK is a Swift framework that provides a seamless integration for ICC's web-based services into iOS applications. It includes functionality for authentication, web content display, and handling deep links.

## Features
- Web content integration using WKWebView
- Authentication token handling and encryption
- Environment-specific configuration (Development/Production)



### Initialization
```swift
// Initialize the SDK with required URLs
let urls = URLS(
    fantasy: "your_fantasy_url",
    predictor: "your_predictor_url",
    iccBaseURL: "your_icc_base_url"
)

// Create an instance of ICCWebView
let webView = ICCWebView(environment: .development, urls: urls)
```

### User Authentication
```swift
// Update user data
let userData = UserData(
    token: "user_token",
    name: "User Name",
    email: "user@example.com"
)
iccWrappedSDK.update(userData: userData)
```



### Environment Setup
The SDK supports two environments:
- Development (.development)
- Production (.production)


### Callbacks
```swift
webView.StayInTheGameCompletion = { success in
    // Handle sign-in result
}

webView.signOutToIccCompletion = { success in
    // Handle sign-out result
}
```

