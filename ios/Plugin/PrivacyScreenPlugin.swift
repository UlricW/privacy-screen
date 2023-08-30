import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(PrivacyScreenPlugin)
public class PrivacyScreenPlugin: CAPPlugin {
    private var isEnabled = true
    private var privacyViewController: UIViewController?

    override public func load() {
        self.isEnabled = privacyScreenConfig().enable
        self.privacyViewController = UIViewController()
        if(!privacyScreenConfig().useImageBackground){
            self.privacyViewController!.view.backgroundColor = UIColor.gray
        }else{
            self.privacyViewController!.view.backgroundColor = UIColor.systemBackground
            var imageView = UIImageView()
            imageView.frame = CGRect(x: 0, y: 0, width: self.privacyViewController!.view.bounds.width  , height:  self.privacyViewController!.view.bounds.height)
            imageView.contentMode = .center
            imageView.clipsToBounds = true
            let imageBackground = UIImage(named: privacyScreenConfig().imageName)
            imageView.image = imageBackground
            self.privacyViewController!.view.addSubview(imageView)
        }
        self.privacyViewController!.modalPresentationStyle = UIModalPresentationStyle.overFullScreen


        NotificationCenter.default.addObserver(self, selector: #selector(self.onAppDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAppWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAppDetectCapturing),
                                               name: UIScreen.capturedDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAppDetectScreenshot),
                                               name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAppOrientationChanged),
                                               name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func enable(_ call: CAPPluginCall) {
        self.isEnabled = true
        DispatchQueue.main.async {
            self.bridge?.webView?.disableScreenshots(self.privacyScreenConfig().useImageBackground, self.privacyScreenConfig().imageName)
        }
        call.resolve()
    }

    @objc func disable(_ call: CAPPluginCall) {
        self.isEnabled = false
        DispatchQueue.main.async {
            self.bridge?.webView?.enableScreenshots()
        }
        call.resolve()
    }

    @objc func onAppWillResignActive() {
        guard self.isEnabled else {
            return
        }

        DispatchQueue.main.async {
            self.bridge?.viewController?.present(self.privacyViewController!, animated: false, completion: nil)
        }
    }

    @objc func onAppDidBecomeActive() {
        DispatchQueue.main.async {
            self.privacyViewController?.dismiss(animated: false, completion: nil)
        }
    }

    @objc private func onAppDetectCapturing() {
        if #available(iOS 11.0, *) {
            if UIScreen.main.isCaptured {
                self.notifyListeners("screenRecordingStarted", data: nil)
            } else {
                self.notifyListeners("screenRecordingStopped", data: nil)
            }
        }
    }

    @objc private func onAppDetectScreenshot() {
        self.notifyListeners("screenshotTaken", data: nil)
    }

    @objc private func onAppOrientationChanged() {
        self.bridge?.webView?.frame = CGRect(x: 0.0, y: 0.0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    }

    public func privacyScreenConfig() -> PrivacyScreenConfig {
        var config = PrivacyScreenConfig()
        config.enable = getConfig().getBoolean("enable", config.enable)
        if config.enable {
            DispatchQueue.main.async {
                self.bridge?.webView?.disableScreenshots(config.useImageBackground, config.imageName)
            }
        }
        config.useImageBackground = getConfig().getBoolean("useImageBackground", config.useImageBackground)
        config.imageName = getConfig().getString("imageName", config.imageName)!
        return config
    }
}

public extension WKWebView {
    func disableScreenshots(_ useImageBackground: Bool, _ imageName: String) {
        let field = UITextField()
        field.isSecureTextEntry = true
        if(useImageBackground){
            let imageBackground = UIImage(named: imageName)
            field.backgroundColor = UIColor.systemBackground

            var backgroundView = UIView()
            backgroundView.backgroundColor = UIColor.systemBackground
            backgroundView.frame = self.bounds
            field.addSubview(backgroundView)

            var imageView = UIImageView()
            imageView.frame = self.bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            imageView.contentMode = .center
            imageView.clipsToBounds = true
            imageView.image = imageBackground
            field.addSubview(imageView)
        }

        field.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(field)
        field.centerYAnchor.constraint(equalTo: self.topAnchor).isActive = true
        field.centerXAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        self.layer.superlayer?.addSublayer(field.layer)
        field.layer.sublayers?.first?.addSublayer(self.layer)
    }

    func enableScreenshots() {
        for view in self.subviews {
            if let textField = view as? UITextField {
                textField.isSecureTextEntry = false
            }
        }
    }
}
