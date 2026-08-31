import Flutter
import SwiftUI
import UIKit

final class NativeAuthPlugin: NSObject {
    static let channelName = "dev.nejok.lms/auth"

    private let channel: FlutterMethodChannel
    private weak var host: UIViewController?
    private weak var presented: UIViewController?

    init(messenger: FlutterBinaryMessenger, host: UIViewController) {
        self.channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        self.host = host
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            if #available(iOS 16.0, *) {
                result(true)
            } else {
                result(false)
            }
        case "present":
            if #available(iOS 16.0, *) {
                present(arguments: call.arguments as? [String: Any] ?? [:], result: result)
            } else {
                result(["status": "unsupported"])
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.0, *)
    private func present(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let host else {
            result(["status": "unsupported"])
            return
        }

        let theme = arguments["theme"] as? String ?? "system"
        let version = arguments["version"] as? String ?? ""
        let systemScheme: ColorScheme = host.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        let palette = AppPalette.resolve(theme, system: systemScheme)

        var finished = false
        let finish: (AuthOutcome) -> Void = { [weak self] outcome in
            guard !finished else { return }
            finished = true
            self?.dismissPresented {
                switch outcome {
                case .cookie(let value):
                    result(["status": "cookie", "value": value])
                case .demo:
                    result(["status": "demo"])
                case .cancelled:
                    result(["status": "cancelled"])
                }
            }
        }

        let view = AuthFlowView(
            palette: palette,
            version: version,
            onEvent: { [weak self] event in
                self?.channel.invokeMethod("analytics", arguments: event)
            },
            onVerify: { [weak self] cookie, completion in
                guard let self else {
                    completion(false)
                    return
                }
                self.channel.invokeMethod("verifyCookie", arguments: cookie) { response in
                    completion((response as? Bool) ?? false)
                }
            },
            onFinish: finish
        )

        let hosting = UIHostingController(rootView: view)
        hosting.modalPresentationStyle = .fullScreen
        hosting.isModalInPresentation = true
        presented = hosting
        host.present(hosting, animated: true)
    }

    private func dismissPresented(_ completion: @escaping () -> Void) {
        guard let presented else {
            completion()
            return
        }
        presented.dismiss(animated: true) {
            completion()
        }
    }
}
