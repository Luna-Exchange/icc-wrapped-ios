import Foundation
import WebKit
import SafariServices
import UIKit
import Photos


// swiftlint:disable all
@available(iOS 14.5, *)
public class iccWrappedSDK {
    public static var enableLogging: Bool = false
    public static weak var sharedWrappedView: ICCWebView?
    static var userData: UserData?
    
    public static func handle(url: URL) -> Bool {
        guard let wrappedView = sharedWrappedView else {
            return false
        }
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

@available(iOS 14.5, *)
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

@available(iOS 14.5, *)
public class ICCWebView: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, SFSafariViewControllerDelegate, WKDownloadDelegate {
    public override var prefersStatusBarHidden: Bool {
            return true
        }
    
    private var pendingDownloads: [WKDownload: URL] = [:]
    private var urlList: [String] = []
    private var currentIndex: Int = 0
    
    public var webView: WKWebView!
    public var isFirstLoad = true
    private var baseUrlString: String
    private var urlStringEncode: String
    private var callbackURL: String
    private var activityIndicator: UIActivityIndicatorView!
    private var backgroundImageView: UIImageView!
    private var deepLinkURLStayInTheGame: String { urls.stayinthegame }
    
    public var authToken: String? { iccWrappedSDK.userData?.token }
    public var name: String? { iccWrappedSDK.userData?.name }
    public var email: String? { iccWrappedSDK.userData?.email }
    
    public typealias SignInWithIccCompletion = (Bool) -> Void  // Define callback type for sign-in
    public var signInWithIccCompletion: SignInWithIccCompletion?
    
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
        self.urlStringEncode = "\(environment.urlStringEncode)/"
        self.callbackURL = environment == .development ? "iccdev://" : "icc://"
        
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        edgesForExtendedLayout = .all
        
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
        webView.backgroundColor = UIColor.blue // Choose a color that matches your site
        webView.scrollView.contentInset = .zero
        webView.isOpaque = true
        view.backgroundColor = UIColor.blue
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
        userContentController.add(handler, name: "signInWithIcc")
        userContentController.add(handler, name: "loginIcc")
        userContentController.add(handler, name: "downloadBase64Image")

        
        NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                webView.topAnchor.constraint(equalTo: view.topAnchor),
                webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
#if DEBUG
        if #available(iOS 16.4, *) {
            
            webView.isInspectable = true
        }
#endif
    }

    func setupBackgroundImageView() {
        backgroundImageView = UIImageView(image: UIImage(named: "loadingpage.png"))
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        
       
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
            activityIndicator = UIActivityIndicatorView(style: .large)
        }
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    func injectImageDownloadHandler() {
            let script = """
            document.addEventListener('click', function(event) {
                // Check if the clicked element is an image
                if (event.target.tagName === 'IMG') {
                    // Prevent default behavior to avoid navigation
                    event.preventDefault();
                    
                    // Get the image URL
                    const imageUrl = event.target.src;
                    console.log('Image clicked, URL:', imageUrl);
                    
                    // Send the URL to Swift for download
                    window.webkit.messageHandlers.downloadIccWrapped.postMessage({
                        imageUrl: imageUrl
                    });
                    
                    // Return false to prevent default handling
                    return false;
                }
            }, true);
            """
            
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            webView.configuration.userContentController.addUserScript(userScript)
        }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
       
        
        let cssInjection = """
            var style = document.createElement('style');
            style.innerHTML = `
                body, html {
                    margin: 0 !important;
                    padding: 0 !important;
                    width: 100% !important;
                    height: 100% !important;
                    overflow-x: hidden !important;
                }
            `;
            document.head.appendChild(style);
            """
            
            webView.evaluateJavaScript(cssInjection, completionHandler: nil)
        let script = """
            window.addEventListener('go-to-stay-in-the-game', function() {
                window.webkit.messageHandlers.goToStayInTheGame.postMessage(null);
            });
            window.addEventListener('close-icc-wrapped', function() {
                window.webkit.messageHandlers.closeIccWrapped.postMessage(null);
                });
            window.addEventListener('share-icc-wrapped', function() {
                window.webkit.messageHandlers.shareIccWrapped.postMessage(null);
                });
            window.addEventListener('login-icc', function() {
                window.webkit.messageHandlers.loginIcc.postMessage(null);
                });
            // Handle base64 image downloads
            window.addEventListener('download-icc-wrapped', function(event) {
                console.log('download-icc-wrapped event triggered');
                console.log('Event object:', event);
                        
                const imageElement = event.detail && event.detail.image ? event.detail.image : null;
                let imageData = null;
                        
                        if (imageElement && imageElement.src) {
                            // If the event contains an image element reference
                            imageData = imageElement.src;
                        } else if (event.detail && event.detail.image && typeof event.detail.image === 'string') {
                            // If the event contains an image URL or base64 string
                            imageData = event.detail.image;
                        }
                        
                        console.log('Image data extracted:', imageData ? imageData.substring(0, 50) + '...' : null);
                        
                        if (imageData) {
                            if (imageData.startsWith('data:image')) {
                                // This is a base64 image
                                console.log('Detected base64 image');
                                window.webkit.messageHandlers.downloadBase64Image.postMessage({
                                    imageData: imageData
                                });
                            } else {
                                // Regular URL
                                console.log('Detected regular image URL');
                                window.webkit.messageHandlers.downloadIccWrapped.postMessage({
                                    imageUrl: imageData
                                });
                            }
                        } else {
                            console.log('No image data found in event');
                        }
                    });
                    
                    // Also handle direct image clicks
                    document.addEventListener('click', function(event) {
                        // Check if clicked element is an image
                        if (event.target.tagName === 'IMG') {
                            console.log('Image clicked');
                            const img = event.target;
                            const src = img.src;
                            
                            // Check if this is a base64 image
                            if (src.startsWith('data:image')) {
                                console.log('Base64 image clicked');
                                window.webkit.messageHandlers.downloadBase64Image.postMessage({
                                    imageData: src
                                });
                                
                                // Prevent navigation
                                event.preventDefault();
                                event.stopPropagation();
                                return false;
                            }
                        }
                    }, true);
                    
                    console.log('All event listeners registered');
            
        """

        webView.evaluateJavaScript(script, completionHandler: nil)

        activityIndicator.stopAnimating()
        backgroundImageView.isHidden = true
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
        backgroundImageView.isHidden = false
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        backgroundImageView.isHidden = true
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "goToStayInTheGame":
            Logger.log("Stay In the Game Worked")
            openDeepLink(urlString: deepLinkURLStayInTheGame)
            
        case "closeIccWrapped":
            Logger.log("Closed Wrapped Worked")
            navigateToICCAction?(self)
            
        case "shareIccWrapped":
            Logger.log("Share Triggered")
            // navigateToICCAction?(self)
            
        case "loginIcc":
            Logger.log("Login Worked")
            //testDirectImageDownload()
            signInWithIccCompletion?(true)

        case "downloadBase64Image":
                Logger.log("Received 'downloadBase64Image' event")
        
        default:
            Logger.log("Received unknown event: \(message.name)")
        }
    }
    
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    private func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    // 5. Add a callback method for the image saving process
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            Logger.log("Error saving image: \(error.localizedDescription)")
            // Show error alert if needed
            let alert = UIAlertController(
                title: "Save Error",
                message: "Could not save image: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
            Logger.log("Image saved successfully")
            // Show success message if needed
            let alert = UIAlertController(
                title: "Image Saved",
                message: "Your ICC Recapped image has been saved to your photo library.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    func openDeepLink(urlString: String) {
      guard let url = URL(string: urlString) else {
        Logger.log("Error: Invalid deep link URL")
        return
      }
      UIApplication.shared.open(url)
    }
    
    func startSDKOperations() {
        if let authToken = authToken {
            encryptAuthToken(authToken: authToken) { encryptedToken in
                DispatchQueue.main.async {
                    var urlString = "\(self.baseUrlString)?recapped_access=\(encryptedToken)"
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
    
    private func encryptAuthToken(authToken: String, completion: @escaping (String) -> Void) {
        
        guard let url = URL(string: urlStringEncode) else {
            Logger.log("Invalid URL string: \(urlStringEncode)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: String] = [
            "authToken": authToken,
            "name": name!,
            "email": email!
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            request.httpBody = jsonData
        } catch {
            Logger.log("Error serializing JSON: \(error.localizedDescription)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.log("Network error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                Logger.log("No data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let statusCode = json["statusCode"] as? Int, statusCode == 200,
                   let responseData = json["data"] as? [String: Any],
                   let encryptedToken = responseData["token"] as? String {
                    completion(encryptedToken)
                } else {
                    Logger.log("Error: Unable to parse response or token not found")
                }
            } catch {
                Logger.log("JSON parsing error: \(error.localizedDescription)")
            }
        }
        task.resume()
    }
    
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        
        if url.absoluteString.hasPrefix("data:image") {
            Logger.log("Detected navigation to base64 image")
            
            let base64String = url.absoluteString
            
            if let range = base64String.range(of: ";base64,") {
                let dataStartIndex = range.upperBound
                let dataString = String(base64String[dataStartIndex...])
                
                if let imageData = Data(base64Encoded: dataString) {
                    if let image = UIImage(data: imageData) {
                        self.requestPhotoLibraryPermission { granted in
                            if granted {
                                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                            } else {
                                self.showAlert(title: "Permission Denied", message: "Unable to save image without photo library access")
                            }
                        }
                    }
                }
            }
            
            decisionHandler(.cancel)
            return
        }

        if url.absoluteString == baseUrlString {
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
    @available(iOS 14.5, *)
        public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            Logger.log("Download started: \(suggestedFilename)")
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDirectory.appendingPathComponent(suggestedFilename)
            
            try? FileManager.default.removeItem(at: destinationURL)
            
            completionHandler(destinationURL)
        }

        
        @available(iOS 14.5, *)
        public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            Logger.log("Download failed with error: \(error.localizedDescription)")
            
       
            pendingDownloads.removeValue(forKey: download)
            
            DispatchQueue.main.async { [weak self] in
                self?.showAlert(title: "Download Failed", message: error.localizedDescription)
            }
        }
        
    
    private func signOut() {
        Logger.log("User signed out")
        self.dismiss(animated: true, completion: nil)
    }
    
        private func saveFileToDocuments(data: Data, url: URL) {
            // Extract filename from URL
            let filename = url.lastPathComponent
            
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                Logger.log("Could not access documents directory")
                showAlert(title: "Save Failed", message: "Could not access documents directory")
                return
            }
            
            let fileURL = documentsDirectory.appendingPathComponent(filename)
            
            do {
                try data.write(to: fileURL)
                Logger.log("File saved to: \(fileURL.path)")
                showAlert(title: "Download Complete", message: "File saved to Documents folder")
            } catch {
                Logger.log("Error saving file: \(error.localizedDescription)")
                showAlert(title: "Save Failed", message: "Error: \(error.localizedDescription)")
            }
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

@available(iOS 14.5, *)
public class ICCWrapped {
    
    public enum Environment {
        case development
        case production
        
        var baseUrl: String {
            switch self {
            case .development:
                return "https://iccwrapped-ui-dev.aws.insomnialabs.xyz/"
            case .production:
                return "https://recapped.icc-cricket.com/"
            }
        }
        var urlStringEncode: String {
            switch self {
            case .development:
                return "https://iccwrapped-api-dev.aws.insomnialabs.xyz/auth/encode"
                //return "https://www.pexels.com/"
            case .production:
                return "https://recapped-api.icc-cricket.com/auth/encode"
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
    
    public static func launch(
        from viewController: UIViewController,
        user: User,
        environment: Environment,
        stayInGameUri: String,
        completion: (() -> Void)? = nil
    ) {
        let urls = URLS(stayinthegame: stayInGameUri)
        
        let iccWebView = ICCWebView(environment: environment, urls: urls)
        iccWebView.modalPresentationStyle = .fullScreen
        iccWebView.modalPresentationCapturesStatusBarAppearance = true

        let userData = UserData(token: user.token, name: user.name, email: user.email)
        iccWrappedSDK.update(userData: userData)
        
        iccWebView.presentAndHandleCallbacks(from: viewController, animated: true, completion: completion)
    }
    
}

@available(iOS 14.5, *)
extension ICCWebView {

    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            completion(true)
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized)
                }
            }
            
        case .denied, .restricted:
            showPermissionAlert()
            completion(false)
            
        case .limited:

            completion(true)
            
        @unknown default:
            completion(false)
        }
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Photo Library Access",
            message: "ICC Recapped needs permission to save images to your photo library. Please enable it in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        present(alert, animated: true)
    }
}

