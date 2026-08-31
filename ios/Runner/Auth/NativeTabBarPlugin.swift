import Flutter
import SwiftUI
import UIKit

final class NativeTabBarPlugin: NSObject {
    static let channelName = "dev.nejok.lms/tabbar"

    private let channel: FlutterMethodChannel
    private weak var host: UIViewController?

    private var container: PassthroughContainerView?
    private var hostingController: UIViewController?
    private var model: AnyObject?

    init(messenger: FlutterBinaryMessenger, host: UIViewController) {
        self.channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        self.host = host
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.0, *) else {
            result(nil)
            return
        }

        switch call.method {
        case "isSupported":
            result(true)
        case "attach":
            attach(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "setSelected":
            if let index = call.arguments as? Int {
                (model as? NativeTabBarModel)?.selected = index
            }
            result(nil)
        case "setTheme":
            if let theme = call.arguments as? String {
                (model as? NativeTabBarModel)?.palette = resolvePalette(theme)
            }
            result(nil)
        case "setVisible":
            container?.isHidden = !((call.arguments as? Bool) ?? true)
            result(nil)
        case "detach":
            detach()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.0, *)
    private func resolvePalette(_ theme: String) -> AppPalette {
        let systemScheme: ColorScheme = host?.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        return AppPalette.resolve(theme, system: systemScheme)
    }

    @available(iOS 16.0, *)
    private func attach(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let host, let hostView = host.view else {
            result(nil)
            return
        }

        let rawItems = arguments["items"] as? [[String: Any]] ?? []
        let items = rawItems.enumerated().map { index, raw in
            NativeTabItem(
                id: index,
                icon: raw["icon"] as? String ?? "circle",
                selectedIcon: raw["selectedIcon"] as? String ?? raw["icon"] as? String ?? "circle",
                label: raw["label"] as? String ?? ""
            )
        }
        let selected = arguments["selected"] as? Int ?? 0
        let palette = resolvePalette(arguments["theme"] as? String ?? "system")

        if let existing = model as? NativeTabBarModel {
            existing.items = items
            existing.selected = selected
            existing.palette = palette
            container?.isHidden = false
            result(["height": NativeTabBarHost.barHeight + NativeTabBarHost.bottomInset])
            return
        }

        let barModel = NativeTabBarModel(items: items, selected: selected, palette: palette)
        model = barModel

        let rootView = NativeTabBarHost(model: barModel) { [weak self] index in
            guard let self else { return }
            barModel.selected = index
            self.channel.invokeMethod("tabSelected", arguments: index)
        }

        let hosting = UIHostingController(rootView: rootView)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        let box = PassthroughContainerView()
        box.backgroundColor = .clear
        box.translatesAutoresizingMaskIntoConstraints = false

        hostView.addSubview(box)
        host.addChild(hosting)
        box.addSubview(hosting.view)
        hosting.didMove(toParent: host)

        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            box.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            box.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor),
            box.heightAnchor.constraint(equalToConstant: NativeTabBarHost.barHeight + NativeTabBarHost.bottomInset),
            hosting.view.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: box.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])

        container = box
        hostingController = hosting

        result(["height": NativeTabBarHost.barHeight + NativeTabBarHost.bottomInset])
    }

    private func detach() {
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        container?.removeFromSuperview()
        hostingController = nil
        container = nil
        model = nil
    }
}
