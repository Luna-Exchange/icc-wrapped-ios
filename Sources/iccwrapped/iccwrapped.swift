
import Foundation
import WebKit
import SafariServices

// swiftlint:disable all
public class iccWrappedSDK {
    public static var enableLogging: Bool = false
    static weak var sharedFanView: ICCWebView?
    static var userData: UserData?
    public static func handle(url: URL) -> Bool {
        // Ensure the shared webview is not nil
        guard let  fanView = sharedFanView else {
            return false
        }
        
        // Pass the URL to the webview
        //fanView.handleDeepLink(url)
        return true
    }
    
    public static func update(userData: UserData?) {
        self.userData = userData
        DispatchQueue.main.async {
            sharedFanView?.update(userData: userData)
        }
    }
    
    public static func logout(completion: @escaping () -> Void) {
            sharedFanView?.clearLocalStorage(completion: completion)
        }
}
public struct URLS {
    public let fantasy: String
    public let predictor: String
    public let iccBaseURL: String
    public init(fantasy: String,
                predictor: String,
                iccBaseURL: String) {
        self.fantasy = fantasy
        self.predictor = predictor
        self.iccBaseURL = iccBaseURL
    }
}
public struct UserData {
    public var token: String
    public var name: String
    public var email: String
    public init(token: String, name: String, email: String) {
        self.token = token
        self.name = name
        self.email = email
    }
}

extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true), let queryItems = components.queryItems else {
            return nil
        }
        var parameters = [String: String]()
        for item in queryItems {
            parameters[item.name] = item.value
        }
        return parameters
    }
}

public enum PassportEntryPoint: String, CustomStringConvertible {
    case defaultPath = ""
    case createAvatar = "/create-avatar"
    case onboarding = "/onboarding"
    case profile = "/profile"
    case challenges = "/challenges"
    case rewards = "/rewards"
    public var description: String { rawValue }
    var path: String {
        return self.rawValue
    }
}


public enum Environment {
    case development
    case production
}

public class ICCWebView: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, SFSafariViewControllerDelegate {
    struct Logger {
        static var isEnabled: Bool { iccWrappedSDK.enableLogging }
        static func print(_ string: CustomStringConvertible) {
            if isEnabled {
                Swift.print(string)
            }
        }
    }
    private var urlList: [String] = []
    private var currentIndex: Int = 0
    
    public var webView: WKWebView!
    var isFirstLoad = true
    private var baseUrlString: String
    private var UrlStringMint: String
    private var UrlStringMinting: String
    private var UrlStringEncode: String
    private var callbackURL: String
    private var deepLinkURLFantasy: String { urls.fantasy }
    private var deeplinkURLPrediction: String { urls.predictor }
    private var iccBaseURL: String { urls.iccBaseURL }
    private var activityIndicator: UIActivityIndicatorView!
    private var backgroundImageView: UIImageView!
    
    public var authToken: String? { iccWrappedSDK.userData?.token }
    public var name: String? { iccWrappedSDK.userData?.name }
    public var email: String? { iccWrappedSDK.userData?.email }
    public var initialEntryPoint: PassportEntryPoint
   
    public typealias NavigateToICCAction = (UIViewController) -> Void  // Define callback type for navigation
    public var navigateToICCAction: NavigateToICCAction?  // Property to store navigation callback

    public typealias SignInWithIccCompletion = (Bool) -> Void  // Define callback type for sign-in
    public var signInWithIccCompletion: SignInWithIccCompletion?  // Property to store sign-in callback
    
    public typealias SignOutToIccCompletion = (Bool) -> Void  // Define callback type for sign-in
    public var signOutToIccCompletion: SignInWithIccCompletion?
    private let urls: URLS

    public init(initialEntryPoint: PassportEntryPoint,
                environment: Environment,
                urls: URLS) {
        self.initialEntryPoint = initialEntryPoint
        self.urls = urls
        switch environment {
        case .development:
            self.baseUrlString = "https://icc-fan-passport-staging.vercel.app/"
            self.UrlStringMint = "https://testnet.wallet.mintbase.xyz/connect?theme=icc&success_url=iccdev://mintbase.xyz"
            self.UrlStringMinting = "https://testnet.wallet.mintbase.xyz/sign-transaction?theme=icc"
            self.callbackURL = "iccdev://mintbase.xyz"
            self.UrlStringEncode = "https://icc-fan-passport-stg-api.insomnialabs.xyz/auth/encode"

        case .production:
            self.baseUrlString = "https://fanpassport.icc-cricket.com/"
            self.UrlStringMint = "https://wallet.mintbase.xyz/connect?theme=icc&success_url=icc://mintbase.xyz"
            self.callbackURL = "icc://mintbase.xyz"
            self.UrlStringMinting = "https://wallet.mintbase.xyz/sign-transaction?theme=icc"
            self.UrlStringEncode = "https://passport-api.icc-cricket.com/auth/encode"

        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // Setup and operations are done in viewWillAppear to ensure they run each time the view appears
        setupWebView()
        setupBackgroundImageView()
        setupActivityIndicator()
        
        
        
        iccWrappedSDK.sharedFanView = self // Retain the reference to the shared instance
       
        startSDKOperations(entryPoint: initialEntryPoint)
        
    }
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }
    
    func update(userData: UserData?) {
        startSDKOperations(entryPoint: self.initialEntryPoint)
    }
    
    func setupWebView() {
        webView = WKWebView()
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        class Handler: NSObject, WKScriptMessageHandler {
            weak var webView: ICCWebView?
            func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                webView?.userContentController(userContentController, didReceive: message)
            }
        }
        
        let handler = Handler()
        handler.webView = self
        // Add script message handler for 'navigateToIcc'
        let userContentController = webView.configuration.userContentController
        userContentController.add(handler, name: "navigateToIcc")
        userContentController.add(handler, name: "goToFantasy")
        userContentController.add(handler, name: "signInWithIcc")
        userContentController.add(handler, name: "goToPrediction")
        userContentController.add(handler, name: "signOut")
        
        // Set up Auto Layout constraints to make the webView full screen
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
#if DEBUG
        if #available(iOS 16.4, *) {
            
            webView.isInspectable = true
        }
#endif
    }

    func setupBackgroundImageView() {
        // Initialize the background image view
        backgroundImageView = UIImageView(image: UIImage(named: "loadingpage.png"))
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        
        // Set up Auto Layout constraints to make the background image view full screen
        NSLayoutConstraint.activate([
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func setupActivityIndicator() {
        if #available(iOS 13.0, *) {
            activityIndicator = UIActivityIndicatorView(style: .large)
        } else {
            // Fallback on earlier versions
        }
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        // Center the activity indicator in the view
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        if isFirstLoad {
                    isFirstLoad = false
                    // Reload webView with the second URL
                    //loadInitialURL()
                }
        // Inject JavaScript to handle multiple events
        let script = """
            window.addEventListener('navigate-to-icc', function() {
                window.webkit.messageHandlers.navigateToIcc.postMessage(null);
            });
            window.addEventListener('go-to-fantasy', function() {
                  window.webkit.messageHandlers.goToFantasy.postMessage(null);
                });
            window.addEventListener('sign-in-with-icc', function() {
                  window.webkit.messageHandlers.signInWithIcc.postMessage(null);
                });
            window.addEventListener('sign-in-with-icc-also', function() {
                  window.webkit.messageHandlers.signInWithIccAlso.postMessage(null);
                });
            window.addEventListener('go-to-prediction', function() {
                window.webkit.messageHandlers.goToPrediction.postMessage(null);
                });
            window.addEventListener('fan-passport-sign-out', function() {
                  window.webkit.messageHandlers.signOut.postMessage(null);
                });
            window.addEventListener('go-to-prediction', function() {
                  window.webkit.messageHandlers.goToPrediction.postMessage(null);
                });
        """

        webView.evaluateJavaScript(script, completionHandler: nil)

        activityIndicator.stopAnimating()
        backgroundImageView.isHidden = true // Hide the background image when loading finishes
        
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
        backgroundImageView.isHidden = false // Show the background image when loading starts
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        backgroundImageView.isHidden = true // Hide the background image if loading fails
    }


    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "navigateToIcc":
            Logger.print("Received 'navigate-to-icc' event")
            navigateToICCAction?(self)
        case "goToFantasy":
            Logger.print("Received 'go-to-fantasy' event")
            // Call your callback action for event-name-1 here
            openDeepLink(urlString: deepLinkURLFantasy)
            Logger.print("Fantasy")
        case "signInWithIcc":
            Logger.print("Received 'sign-in-with-icc' event")
            // Call your callback action for event-name-2 here
            signInWithIccCompletion?(true)
        case "signInWithIccAlso":
            Logger.print("Received 'sign-in-with-icc-also' event")
            // Call your callback action for event-name-2 here
            signInWithIccCompletion?(true)
        case "signOut":
            Logger.print("Received 'fan-passport-sign-out' event")
            // Call your callback action for event-name-2 here
            signOutToIccCompletion?(true)
        case "goToPrediction":
            Logger.print("Received 'go-to-prediction' event")
            // Call your callback action for event-name-2 here
            openDeepLink(urlString: deeplinkURLPrediction)
        default:
            Logger.print("Received unknown event: \(message.name)")
        }
    }
    
    func openDeepLink(urlString: String) {
      guard let url = URL(string: urlString) else {
        Logger.print("Error: Invalid deep link URL")
        return
      }
      UIApplication.shared.open(url)
    }
    
    func startSDKOperations(entryPoint: PassportEntryPoint, accountid: String? = nil, publickey: String? = nil) {
        
        if let accountId = accountid, let publicKey = publickey, !accountId.isEmpty {
            DispatchQueue.main.async {
                let urlString2 = "\(self.baseUrlString)\(entryPoint)/connect-wallet?account_id=\(accountId)&public_key=\(publicKey)"
                self.loadURL(urlString2)
            }
        } else if let authToken {
            encryptAuthToken(authToken: authToken) { encryptedToken in
                DispatchQueue.main.async {
                    
                    var urlStringload = "\(self.baseUrlString)\(entryPoint)?passport_access=\(encryptedToken)"
                            if self.isFirstLoad {
                                urlStringload += "&icc_client=mobile_app"
                            }
                            if let url = URL(string: urlStringload) {
                                let request = URLRequest(url: url)
                                self.loadURL(urlStringload)
                            }
                }
            }
        } else {
            
            let script = WKUserScript(
                source: "window.localStorage.clear();", // call another JS function that "logsout" user
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            if self.isFirstLoad {
                webView.configuration.userContentController.addUserScript(script)
                var components = URLComponents(string: self.baseUrlString)
                components?.queryItems = [.init(name: "icc_client", value: "mobileapp")]
                if let string = components?.url?.absoluteString {
                    self.loadURL(string)
                }
            }else{
                self.loadURL(baseUrlString)
            }
        }
    }
    
    public func clearLocalStorage(completion: @escaping () -> Void) {
            let dataStore = webView.configuration.websiteDataStore
            let dataTypes = Set([WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeSessionStorage, WKWebsiteDataTypeIndexedDBDatabases, WKWebsiteDataTypeWebSQLDatabases])
            dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
                dataStore.removeData(ofTypes: dataTypes, for: records, completionHandler: completion)
            }
        }
    
    func loadURL(_ urlString: String) {
      if let url = URL(string: urlString) {
        self.webView.load(URLRequest(url: url))
      } else {
        Logger.print("Error: Invalid URL")
      }
    }
    

    private func encryptAuthToken(authToken: String, completion: @escaping (String) -> Void) {
        // Prepare the request
        guard let url = URL(string: UrlStringEncode) else {
            Logger.print("Invalid URL string: \(UrlStringEncode)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare the request body
        let requestBody: [String: String] = [
            "authToken": authToken,
            "name": name!,
            "email": email!
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            request.httpBody = jsonData
        } catch {
            Logger.print("Error serializing JSON: \(error.localizedDescription)")
            return
        }
        
        // Make the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.print("Network error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                Logger.print("No data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let statusCode = json["statusCode"] as? Int, statusCode == 200,
                   let responseData = json["data"] as? [String: Any],
                   let encryptedToken = responseData["token"] as? String {
                    // Call completion handler with encrypted token
                    completion(encryptedToken)
                } else {
                    Logger.print("Error: Unable to parse response or token not found")
                }
            } catch {
                Logger.print("JSON parsing error: \(error.localizedDescription)")
            }
        }
        task.resume()
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        // Ensure the URL is valid
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        if let fanURL = URL(string: iccBaseURL + "fan-passport"),
           fanURL == url {
            decisionHandler(.cancel)
            return
        }
        
        // Handle URLs containing "sign-transaction"
        if url.absoluteString.contains("sign-transaction") {
          
            let urlformintingRC = removeCallbackUrl(from: url.absoluteString) ?? "" // Empty string if nil
            let urlformintingString = "\(urlformintingRC)&callback_url=\(callbackURL)"

            guard let mintURL = URL(string: urlformintingString) else {
                decisionHandler(.cancel)
                return
            }
              // ... rest of your code
                openSafariViewController(with: mintURL)
         
            decisionHandler(.cancel)
        
        // Handle URLs that should be opened in Safari
        } else if shouldOpenURLInSafari(url) {
            guard let walletCreationURL = URL(string: UrlStringMint) else {
                decisionHandler(.cancel)
                return
            }
            openSafariViewController(with: walletCreationURL)
            decisionHandler(.cancel)
        
        // Cancel navigation to the iccBaseURL
        } else if url.absoluteString == iccBaseURL {
            decisionHandler(.cancel)
        
        // Allow other navigations
        } else {
            decisionHandler(.allow)
        }
    }

    func removeCallbackUrl(from urlString: String) -> String? {
        guard var urlComponents = URLComponents(string: urlString) else {
            print("Invalid URL")
            return nil
        }

        // Filter out the callback_url query item
        urlComponents.queryItems = urlComponents.queryItems?.filter { $0.name != "callback_url" }

        // Reconstruct the URL without the callback_url
        return urlComponents.url?.absoluteString
    }
    
    private func signOut() {
        // Perform any necessary sign-out operations here
        Logger.print("User signed out")

        // Dismiss the ICCWebView
        self.dismiss(animated: true, completion: nil)
    }
    
    func openSafariViewController(with url: URL) {
        // Dismiss any presented view controllers, such as the Safari view controller
        if let presentingVC = self.presentedViewController {
            presentingVC.dismiss(animated: true, completion: {
                UIApplication.shared.open(url)
            })
        } else {
            let safari = SFSafariViewController(url: url)
            safari.delegate = self
            self.present(safari, animated: true)
        }
    }
    func shouldOpenURLInSafari(_ url: URL) -> Bool {
        // Check if the URL's host contains "wallet.mintbase.xyz"
        //return url.host?.contains("wallet.mintbase.xyz") ?? false
        return url.host?.contains("mintbase") ?? false
    }
    
    public func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {
        // Check if the URL is a deep link that should be handled by your app
        if URL.scheme == "iccdev" {
            
           // handleDeepLink(URL)
            Logger.print("Safari Controller Did close")
            Logger.print(URL)
            controller.dismiss(animated: true, completion: nil)
        }
    }
    
    func retrieveEncryptedToken() -> String? {
      let defaults = UserDefaults.standard
      let encryptedToken = defaults.string(forKey: "encryptedToken")
      return encryptedToken
    }

//    func handleDeepLink(_ url: URL) {
//        // Check if the URL contains "mintbase.xyz"
//        if url.host == "mintbase.xyz" {
//            if url.absoluteString.contains("account_id") {
//                // Use URLComponents to parse the URL and extract the query parameters
//                if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
//                    var accountId: String?
//                    var publicKey: String?
//                    
//                    // Loop through the query items to find account_id and public_key
//                    if let queryItems = urlComponents.queryItems {
//                        for queryItem in queryItems {
//                            if queryItem.name == "account_id" {
//                                accountId = queryItem.value
//                            } else if queryItem.name == "public_key" {
//                                publicKey = queryItem.value
//                            }
//                        }
//                    }
//                    
//                    // Debugging output
//                    Logger.print("Account ID: \(accountId ?? "N/A")")
//                    Logger.print("Public Key: \(publicKey ?? "N/A")")
//                    
//                    // Inject JavaScript to handle the deeplink within the webview
//                    let jsCommand = "handleDeepLink('\(url.absoluteString)')"
//                    Logger.print(url.absoluteString)
//                    webView.evaluateJavaScript(jsCommand, completionHandler: nil)
//                    
//                    // Restart SDK operations with the extracted account_id and public_key
//                    if let accountId = accountId, let publicKey = publicKey {
//                        startSDKOperations(entryPoint: .onboarding, accountid: accountId, publickey: publicKey)
//                    }
//                }
//                
//            } else if url.absoluteString.contains("transactionHashes") {
//                var claimTierURL = URLComponents(string: baseUrlString)!
//                claimTierURL.path += "onboarding/claim-tier"
//                
//                // Access the final URL
//                let claimteir = claimTierURL.url!
//                //claimteir = "\(self.baseUrlString)onboarding/claim-tier"
//                self.loadURL(claimteir.absoluteString)
//                
//            }
//            else {
//                Logger.print("No other url")
//            }
//            
//            // Dismiss any presented view controllers, such as a Safari view controller
//            self.presentedViewController?.dismiss(animated: true)
//        }
//    }
    func presentAndHandleCallbacks(animated: Bool = true, completion: (() -> Void)? = nil) {
        self.present(self, animated: animated, completion: completion)  // Present the ICCWebView
      }
}
