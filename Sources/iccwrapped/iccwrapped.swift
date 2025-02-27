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
    
    private var pendingDownloads: [WKDownload: URL] = [:]
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
    
    public typealias SignInWithIcc = (Bool) -> Void  // Define callback type for sign-in
    public var signInWithIcc: SignInWithIcc?
    
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
        userContentController.add(handler, name: "signInWithIcc")
        userContentController.add(handler, name: "loginIcc")
        userContentController.add(handler, name: "downloadBase64Image") // Add this for base64 images

        
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
        
        if isFirstLoad {
                    isFirstLoad = false
                    // Reload webView with the second URL
                    //loadInitialURL()
                }
        // Inject JavaScript to handle multiple events
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
            window.addEventListener('download-icc-wrapped', function(event) {
                window.webkit.messageHandlers.downloadIccWrapped.postMessage(null);
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
        
//        window.addEventListener('download-icc-wrapped', function(event) {
//                    const imageUrl = event.detail ? event.detail.image : null;
//                    console.log("Image URL:", imageUrl);
//
//                    window.webkit.messageHandlers.downloadIccWrapped.postMessage({
//                        imageUrl: imageUrl
//                    });
//                });

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
            signInWithIcc?(true)
        case "downloadIccWrapped":
                Logger.log("Received 'downloadIccWrapped' event")
                
                // For regular image URLs
                if let messageBody = message.body as? [String: Any],
                   let imageUrlString = messageBody["imageUrl"] as? String,
                   let imageUrl = URL(string: imageUrlString) {
                    
                    // Use direct download instead of WKDownload
                    let session = URLSession.shared
                    let task = session.dataTask(with: imageUrl) { [weak self] (data, response, error) in
                        guard let self = self else { return }
                        
                        DispatchQueue.main.async {
                            if let error = error {
                                Logger.log("Download error: \(error.localizedDescription)")
                                self.showAlert(title: "Download Failed", message: "Error: \(error.localizedDescription)")
                                return
                            }
                            
                            guard let data = data else {
                                Logger.log("No data received")
                                self.showAlert(title: "Download Failed", message: "No data received")
                                return
                            }
                            
                            if let image = UIImage(data: data) {
                                self.requestPhotoLibraryPermission { granted in
                                    if granted {
                                        UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                                    } else {
                                        self.showAlert(title: "Permission Denied", message: "Unable to save image without photo library access")
                                    }
                                }
                            } else {
                                Logger.log("Invalid image data")
                                self.showAlert(title: "Download Failed", message: "Invalid image format")
                            }
                        }
                    }
                    task.resume()
                } else {
                    Logger.log("No valid image URL found in message")
                    self.showAlert(title: "Download Failed", message: "No image URL received")
                }
        case "downloadBase64Image":
                Logger.log("Received 'downloadBase64Image' event")
                
                if let messageBody = message.body as? [String: Any],
                   let base64String = messageBody["imageData"] as? String {
                    
                    Logger.log("Base64 string received (first 50 chars): \(String(base64String.prefix(50)))...")
                    
                    // Extract the base64 data - find the data after the comma in data:image/png;base64,
                    if let range = base64String.range(of: ";base64,") {
                        let dataStartIndex = range.upperBound
                        let dataString = String(base64String[dataStartIndex...])
                        
                        Logger.log("Extracted base64 data (length: \(dataString.count))")
                        
                        // Convert base64 to Data
                        if let imageData = Data(base64Encoded: dataString) {
                            Logger.log("Successfully converted to data (size: \(imageData.count) bytes)")
                            
                            // Create image from data
                            if let image = UIImage(data: imageData) {
                                Logger.log("Successfully created image of size: \(image.size)")
                                
                                // Save to photos
                                self.requestPhotoLibraryPermission { granted in
                                    if granted {
                                        Logger.log("Photo library permission granted, saving image")
                                        UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                                    } else {
                                        Logger.log("Photo library permission denied")
                                        self.showAlert(title: "Permission Denied", message: "Unable to save image without photo library access")
                                    }
                                }
                            } else {
                                Logger.log("Failed to create image from base64 data")
                                self.showAlert(title: "Download Failed", message: "Invalid image format")
                            }
                        } else {
                            Logger.log("Invalid base64 data")
                            self.showAlert(title: "Download Failed", message: "Invalid image data")
                        }
                    } else {
                        Logger.log("Invalid base64 image format - no ;base64, marker found")
                        self.showAlert(title: "Download Failed", message: "Invalid image format")
                    }
                } else {
                    Logger.log("No valid base64 data found in message")
                    self.showAlert(title: "Download Failed", message: "No image data received")
                }
        
        default:
            Logger.log("Received unknown event: \(message.name)")
        }
    }
    
//case "downloadIccWrapped":
    //Logger.log("Received 'downloadIccWrapped' event")
    //Logger.log("Message body: \(String(describing: message.body))")
//
//            // Extract the image URL from the message body
//            if let messageBody = message.body as? [String: Any] {
//                Logger.log("Message body parsed as dictionary")
//
//                if let imageUrlString = messageBody["imageUrl"] as? String {
//                    Logger.log("Image URL string: \(imageUrlString)")
//
//                    if let imageUrl = URL(string: imageUrlString) {
//                        Logger.log("Valid URL created: \(imageUrl.absoluteString)")
//                        // Download the image
//                        downloadImage(from: imageUrl)
//                    } else {
//                        Logger.log("Failed to create URL from string: \(imageUrlString)")
//                        showAlert(title: "Invalid URL", message: "The image URL provided is not valid")
//                    }
//                } else {
//                    Logger.log("No imageUrl found in message body: \(messageBody)")
//                    showAlert(title: "Missing Image", message: "No image URL was provided")
//                }
//            } else {
//                Logger.log("Message body could not be parsed as dictionary: \(message.body)")
//                showAlert(title: "Format Error", message: "The message format is incorrect")
//            }
    
    // Method to download using WKDownload
       private func downloadWithWKDownload(url: URL) {
           Logger.log("Starting download from URL: \(url.absoluteString)")
           
           // Create a URLRequest with the image URL
           let request = URLRequest(url: url)
           
           // Start the download process
           if #available(iOS 14.5, *) {
               // Use WKDownload on iOS 14.5 and later
               webView.startDownload(using: request) { [weak self] download in
                   guard let self = self else { return }
                   
                   // Store the download and URL for later use
                   self.pendingDownloads[download] = url
                   download.delegate = self
                   Logger.log("Download started successfully")
               }
           } else {
               // Fallback for earlier versions - direct download
               directDownload(from: url)
           }
       }
    // Fallback method for direct download (for iOS versions < 14.5)
        private func directDownload(from url: URL) {
            Logger.log("Using direct download for URL: \(url.absoluteString)")
            
            let session = URLSession.shared
            let task = session.dataTask(with: url) { [weak self] (data, response, error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        Logger.log("Download error: \(error.localizedDescription)")
                        self.showAlert(title: "Download Failed", message: "Error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data else {
                        Logger.log("No data received")
                        self.showAlert(title: "Download Failed", message: "No data received")
                        return
                    }
                    
                    // For images, create a UIImage and save to photo library
                    if let image = UIImage(data: data) {
                        self.requestPhotoLibraryPermission { granted in
                            if granted {
                                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                            } else {
                                self.showAlert(title: "Permission Denied", message: "Unable to save image without photo library access")
                            }
                        }
                    } else {
                        // For other file types, save to documents directory
                        self.saveFileToDocuments(data: data, url: url)
                    }
                }
            }
            task.resume()
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
                message: "Your ICC Wrapped image has been saved to your photo library.",
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
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        
        Logger.log("Navigation requested to: \(url.absoluteString)")
        
        // Handle data URLs (base64 images)
        if url.absoluteString.hasPrefix("data:image") {
            Logger.log("Detected navigation to base64 image")
            
            // Extract and process the base64 image
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
            
            // Cancel navigation to prevent error
            decisionHandler(.cancel)
            return
        }
        
        // Handle file downloads
        let fileExtensions = ["jpg", "jpeg", "png", "gif", "pdf", "zip", "doc", "docx", "xls", "xlsx"]
        if fileExtensions.contains(url.pathExtension.lowercased()) {
            Logger.log("Detected navigation to file: \(url.absoluteString)")
            
            // Use direct download
            let session = URLSession.shared
            let task = session.dataTask(with: url) { [weak self] (data, response, error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        Logger.log("Download error: \(error.localizedDescription)")
                        self.showAlert(title: "Download Failed", message: "Error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data else {
                        Logger.log("No data received")
                        return
                    }
                    
                    // For images, save to photo library
                    if let image = UIImage(data: data) {
                        self.requestPhotoLibraryPermission { granted in
                            if granted {
                                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                            }
                        }
                    }
                }
            }
            task.resume()
            
            // Cancel navigation to prevent error
            decisionHandler(.cancel)
            return
        }
        
        // Regular navigation
        if url.absoluteString == baseUrlString {
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
    func startDownloadWithURLSession(url: URL) {
        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
            guard let location = location, error == nil else {
                print("Download error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // Move file to Documents Directory
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsPath.appendingPathComponent(response?.suggestedFilename ?? "downloadedFile")

            do {
                try fileManager.moveItem(at: location, to: destinationURL)
                print("File saved to: \(destinationURL)")
            } catch {
                print("File move error: \(error.localizedDescription)")
            }
        }
        task.resume()
    }
    
//    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//
//        // Ensure the URL is valid
//        guard let url = navigationAction.request.url else {
//            decisionHandler(.cancel)
//            return
//        }
//        // Check if this is a download link by file extension
//        let fileExtensions = ["jpg", "jpeg", "png", "gif", "pdf", "zip", "doc", "docx", "xls", "xlsx"]
//        if fileExtensions.contains(url.pathExtension.lowercased()) {
//            // This appears to be a file download, intercept it
//            Logger.log("Detected file download: \(url.absoluteString)")
//            downloadWithWKDownload(url: url)
//            decisionHandler(.cancel) // Cancel navigation to prevent WebKit error
//            return
//        }
//        if url.absoluteString == baseUrlString {
//            decisionHandler(.cancel)
//            // Allow other navigations
//        } else {
//            decisionHandler(.allow)
//        }
//    }
    @available(iOS 14.5, *)
        public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            Logger.log("Download started: \(suggestedFilename)")
            
            // Create a destination URL in the Documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDirectory.appendingPathComponent(suggestedFilename)
            
            // Remove any existing file
            try? FileManager.default.removeItem(at: destinationURL)
            
            // Return the destination URL
            completionHandler(destinationURL)
        }
        
        // Called when download finishes
        @available(iOS 14.5, *)
        public func downloadDidFinish(_ download: WKDownload) {
            Logger.log("Download finished successfully")
            
            // Get the original URL
            guard let originalURL = pendingDownloads[download] else {
                return
            }
            
            // Clean up
            pendingDownloads.removeValue(forKey: download)
            
            // Show success alert
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Check if this is an image
                if originalURL.pathExtension.lowercased() == "jpg" ||
                   originalURL.pathExtension.lowercased() == "jpeg" ||
                   originalURL.pathExtension.lowercased() == "png" ||
                   originalURL.pathExtension.lowercased() == "gif" {
                    self.showAlert(title: "Download Complete", message: "Image saved successfully")
                } else {
                    self.showAlert(title: "Download Complete", message: "File saved to Documents folder")
                }
            }
        }
        
        // Called if download fails
        @available(iOS 14.5, *)
        public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            Logger.log("Download failed with error: \(error.localizedDescription)")
            
            // Clean up
            pendingDownloads.removeValue(forKey: download)
            
            // Show error alert
            DispatchQueue.main.async { [weak self] in
                self?.showAlert(title: "Download Failed", message: error.localizedDescription)
            }
        }
        
    
    private func signOut() {
        Logger.log("User signed out")
        self.dismiss(animated: true, completion: nil)
    }
    
    // Save file to documents directory
        private func saveFileToDocuments(data: Data, url: URL) {
            // Extract filename from URL
            let filename = url.lastPathComponent
            
            // Get documents directory
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                Logger.log("Could not access documents directory")
                showAlert(title: "Save Failed", message: "Could not access documents directory")
                return
            }
            
            let fileURL = documentsDirectory.appendingPathComponent(filename)
            
            do {
                // Write data to file
                try data.write(to: fileURL)
                Logger.log("File saved to: \(fileURL.path)")
                showAlert(title: "Download Complete", message: "File saved to Documents folder")
            } catch {
                Logger.log("Error saving file: \(error.localizedDescription)")
                showAlert(title: "Save Failed", message: "Error: \(error.localizedDescription)")
            }
        }
        
        
//        // Show alert helper
//        private func showAlert(title: String, message: String) {
//            let alert = UIAlertController(
//                title: title,
//                message: message,
//                preferredStyle: .alert
//            )
//            alert.addAction(UIAlertAction(title: "OK", style: .default))
//            present(alert, animated: true)
//        }


    
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
@available(iOS 14.5, *)
public class ICCWrapped {
    
    public enum Environment {
        case development
        case production
        
        var baseUrl: String {
            switch self {
            case .development:
                return "https://icc-wrapped-frontend.vercel.app/"
                //return "https://www.pexels.com/"
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

@available(iOS 14.5, *)
extension ICCWebView {
    // Permission request method
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
            // For iOS 14+, limited access might be enough for saving
            completion(true)
            
        @unknown default:
            completion(false)
        }
    }
    
    // Alert for denied permission
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Photo Library Access",
            message: "ICC Wrapped needs permission to save images to your photo library. Please enable it in Settings.",
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

