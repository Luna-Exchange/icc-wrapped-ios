import Foundation
import WebKit
import SafariServices
import UIKit

// swiftlint:disable all
public class iccWrappedSDK {
    public static var enableLogging: Bool = false
    static weak var sharedWrappedView: ICCWebView?
    static var userData: UserData?
    
    public static func handle(url: URL) -> Bool {
        guard let wrappedView = sharedWrappedView else {
            return false
        }
        //wrappedView.handleDeepLink(url)
        return true
    }
    
    public static func update(userData: UserData?) {
        self.userData = userData
        DispatchQueue.main.async {
            sharedWrappedView?.update(userData: userData)
        }
    }
}
public struct URLS {
    public let stayinthegame: String
    public init(stayinthegame: String) {
        self.stayinthegame = stayinthegame
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


public enum Environment {
    case development
    case production
}

enum LogLevel: String {
    case debug, info, warning, error
}

struct Logger {
    static var isEnabled: Bool { iccWrappedSDK.enableLogging }
    static var minimumLogLevel: LogLevel = .info
    
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled, level.rawValue >= minimumLogLevel.rawValue else { return }
        let fileName = (file as NSString).lastPathComponent
        Swift.print("[\(level.rawValue.uppercased())] [\(fileName):\(line)] \(function): \(message)")
    }
}

class WeakRef<T: AnyObject> {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}

public class ICCWebView: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, SFSafariViewControllerDelegate {
    private var urlList: [String] = []
    private var currentIndex: Int = 0
    
    public var webView: WKWebView!
    public var isFirstLoad = true
    private var baseUrlString: String
    private var UrlStringEncode: String
    private var callbackURL: String
    private var activityIndicator: UIActivityIndicatorView!
    private var backgroundImageView: UIImageView!
    private var deepLinkURLStayInTheGame: String { urls.stayinthegame }
    
    public var authToken: String? { iccWrappedSDK.userData?.token }
    public var name: String? { iccWrappedSDK.userData?.name }
    public var email: String? { iccWrappedSDK.userData?.email }
    
    public typealias NavigateToICCAction = (UIViewController) -> Void
    public var navigateToICCAction: NavigateToICCAction?
   
    public typealias NavigateToStayInTheGame = (UIViewController) -> Void
    public var navigateToStayInTheGame: NavigateToStayInTheGame?

    public typealias CloseTheWrapped = (Bool) -> Void
    public var closeTheWrapped: CloseTheWrapped?
    
    
    private let urls: URLS
    private let environment: ICCWrapped.Environment

    public init(environment: ICCWrapped.Environment, urls: URLS) {
        self.environment = environment
        self.urls = urls
        
        // Set up base URLs based on environment
        self.baseUrlString = environment.baseUrl
        self.UrlStringEncode = "\(environment.baseUrl)/"
        self.callbackURL = environment == .development ? "iccdev://" : "icc://"
        
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupBackgroundImageView()
        setupActivityIndicator()
        
        iccWrappedSDK.sharedWrappedView = self
        startSDKOperations()
    }

    func update(userData: UserData?) {
        startSDKOperations()
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
       
        let userContentController = webView.configuration.userContentController
        userContentController.add(handler, name: "goToStayInTheGame")
        userContentController.add(handler, name: "closeIccWrapped")
        
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
            window.addEventListener('goToStayInTheGame', function() {
                window.webkit.messageHandlers.goToStayInTheGame.postMessage(null);
            });
            window.addEventListener('closeIccWrapped', function() {
                  window.webkit.messageHandlers.closeIccWrapped.postMessage(null);
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
        case "goToStayInTheGame":
            Logger.log("Received 'goToStayInTheGame' event")
            openDeepLink(urlString: deepLinkURLStayInTheGame)
        case "closeIccWrapped":
            Logger.log("Received 'closeIccWrapped' event")
            navigateToICCAction?(self)
        case "navigateToIcc":
            Logger.log("Received 'navigate-to-icc' event")
            navigateToICCAction?(self)
        default:
            Logger.log("Received unknown event: \(message.name)")
        }
    }
    
    func openDeepLink(urlString: String) {
      guard let url = URL(string: urlString) else {
        Logger.log("Error: Invalid deep link URL")
        return
      }
      UIApplication.shared.open(url)
    }
    
    func startSDKOperations(accountid: String? = nil, publickey: String? = nil) {
        if let authToken = authToken {
            encryptAuthToken(authToken: authToken) { [weak self] result in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    var urlString = "\(self.baseUrlString)?wrapped_access=\(authToken)"
                    if self.isFirstLoad {
                        urlString += "&icc_client=mobile_app"
                    }
                    if let url = URL(string: urlString) {
                        let request = URLRequest(url: url)
                        self.loadURL(urlString)
                    }
                }
            }
        }
        else {
                
                self.loadURL(baseUrlString)
                
            }
        }
    
    func loadURL(_ urlString: String) {
      if let url = URL(string: urlString) {
        self.webView.load(URLRequest(url: url))
      } else {
        Logger.log("Error: Invalid URL")
      }
    }
    

    private func encryptAuthToken(authToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Prepare the request
        guard let url = URL(string: UrlStringEncode) else {
            completion(.failure(NSError(domain: "ICCWrapped", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
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
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Make the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ICCWrapped", code: -3, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let statusCode = json["statusCode"] as? Int, statusCode == 200,
                   let responseData = json["data"] as? [String: Any],
                   let encryptedToken = responseData["token"] as? String {
                    // Call completion handler with encrypted token
                    completion(.success(encryptedToken))
                } else {
                    completion(.failure(NSError(domain: "ICCWrapped", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                completion(.failure(error))
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
        if url.absoluteString == baseUrlString {
            decisionHandler(.cancel)
            // Allow other navigations
        } else {
            decisionHandler(.allow)
        }
    }
    
    private func signOut() {
        Logger.log("User signed out")
        self.dismiss(animated: true, completion: nil)
    }


    
    func retrieveEncryptedToken() -> String? {
      let defaults = UserDefaults.standard
      let encryptedToken = defaults.string(forKey: "encryptedToken")
      return encryptedToken
    }

    func presentAndHandleCallbacks(from presenter: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        presenter.present(self, animated: animated, completion: completion)
    }
}

// First, let's create a cleaner launch interface
public class ICCWrapped {
    
    public enum Environment {
        case development
        case production
        
        var baseUrl: String {
            switch self {
            case .development:
                return "https://icc-wrapped-frontend.vercel.app/"
            case .production:
                return "https://wrapped.icc-cricket.com"
            }
        }
    }
    
    public struct User {
        let token: String
        let name: String
        let email: String
        
        public init(token: String, name: String, email: String) {
            self.token = token
            self.name = name
            self.email = email
        }
    }
    
    // Static launch method similar to Android's style
    public static func launch(
        from viewController: UIViewController,
        user: User,
        environment: Environment,
        stayInGameUri: String,
        completion: (() -> Void)? = nil
    ) {
        // Create URLs configuration
        let urls = URLS(stayinthegame: stayInGameUri)
        
        // Create and configure the WebView controller
        let iccWebView = ICCWebView(environment: environment, urls: urls)
        
        // Update user data
        let userData = UserData(token: user.token, name: user.name, email: user.email)
        iccWrappedSDK.update(userData: userData)
        
        // Present the controller
        iccWebView.presentAndHandleCallbacks(from: viewController, animated: true, completion: completion)
    }
}
