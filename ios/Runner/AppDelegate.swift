import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nativeAuth: NativeAuthPlugin?
  private var nativeTabBar: NativeTabBarPlugin?
  private var nativeUI: NativeUIPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      nativeAuth = NativeAuthPlugin(messenger: controller.binaryMessenger, host: controller)
      nativeTabBar = NativeTabBarPlugin(messenger: controller.binaryMessenger, host: controller)
      nativeUI = NativeUIPlugin(messenger: controller.binaryMessenger, host: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
