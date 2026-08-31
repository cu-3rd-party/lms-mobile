import Flutter
import SwiftUI
import UIKit

final class NativeUIPlugin: NSObject {
    static let channelName = "dev.nejok.lms/ui"

    private let channel: FlutterMethodChannel
    private weak var host: UIViewController?

    init(messenger: FlutterBinaryMessenger, host: UIViewController) {
        self.channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        self.host = host
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private var topPresenter: UIViewController? {
        var controller = host
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "isSupported":
            if #available(iOS 16.0, *) {
                result(true)
            } else {
                result(false)
            }
        case "alert":
            presentAlert(arguments: arguments, style: .alert, result: result)
        case "actionSheet":
            presentAlert(arguments: arguments, style: .actionSheet, result: result)
        case "prompt":
            presentPrompt(arguments: arguments, result: result)
        case "datePicker":
            if #available(iOS 16.0, *) {
                presentDatePicker(arguments: arguments, result: result)
            } else {
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func actionStyle(_ raw: String?) -> UIAlertAction.Style {
        switch raw {
        case "cancel": return .cancel
        case "destructive": return .destructive
        default: return .default
        }
    }

    private func presentAlert(
        arguments: [String: Any],
        style: UIAlertController.Style,
        result: @escaping FlutterResult
    ) {
        guard let presenter = topPresenter else {
            result(nil)
            return
        }

        let title = arguments["title"] as? String
        let message = arguments["message"] as? String
        let rawActions = arguments["actions"] as? [[String: Any]] ?? []

        let controller = UIAlertController(title: title, message: message, preferredStyle: style)

        var answered = false
        let answer: (Int?) -> Void = { index in
            guard !answered else { return }
            answered = true
            result(index)
        }

        for (index, raw) in rawActions.enumerated() {
            let action = UIAlertAction(
                title: raw["title"] as? String ?? "",
                style: actionStyle(raw["style"] as? String)
            ) { _ in
                answer(index)
            }
            controller.addAction(action)
        }

        if rawActions.isEmpty {
            controller.addAction(UIAlertAction(title: "OK", style: .cancel) { _ in answer(nil) })
        }

        if let popover = controller.popoverPresentationController, let view = presenter.view {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        presenter.present(controller, animated: true)
    }

    private func presentPrompt(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let presenter = topPresenter else {
            result(nil)
            return
        }

        let controller = UIAlertController(
            title: arguments["title"] as? String,
            message: arguments["message"] as? String,
            preferredStyle: .alert
        )

        controller.addTextField { field in
            field.text = arguments["value"] as? String
            field.placeholder = arguments["placeholder"] as? String
            field.clearButtonMode = .whileEditing
            field.autocorrectionType = .no
        }

        var answered = false
        let answer: (String?) -> Void = { value in
            guard !answered else { return }
            answered = true
            result(value)
        }

        controller.addAction(
            UIAlertAction(title: arguments["cancelTitle"] as? String ?? "Отмена", style: .cancel) { _ in
                answer(nil)
            }
        )
        controller.addAction(
            UIAlertAction(title: arguments["confirmTitle"] as? String ?? "Готово", style: .default) { [weak controller] _ in
                answer(controller?.textFields?.first?.text ?? "")
            }
        )

        presenter.present(controller, animated: true)
    }

    @available(iOS 16.0, *)
    private func presentDatePicker(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let presenter = topPresenter else {
            result(nil)
            return
        }

        let theme = arguments["theme"] as? String ?? "system"
        let systemScheme: ColorScheme = presenter.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        let palette = AppPalette.resolve(theme, system: systemScheme)

        let initial = date(from: arguments["initial"])  ?? Date()
        let minimum = date(from: arguments["minimum"])
        let maximum = date(from: arguments["maximum"])

        var answered = false
        var hosting: UIViewController?
        let answer: (Date?) -> Void = { value in
            guard !answered else { return }
            answered = true
            hosting?.dismiss(animated: true) {
                if let value {
                    result(Int(value.timeIntervalSince1970 * 1000))
                } else {
                    result(nil)
                }
            }
        }

        let view = NativeDatePickerSheet(
            palette: palette,
            initial: initial,
            minimum: minimum,
            maximum: maximum,
            title: arguments["title"] as? String ?? "Выберите дату",
            onDone: { answer($0) },
            onCancel: { answer(nil) }
        )

        let controller = UIHostingController(rootView: view)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        hosting = controller
        presenter.present(controller, animated: true)
    }

    private func date(from raw: Any?) -> Date? {
        guard let millis = raw as? Int else { return nil }
        return Date(timeIntervalSince1970: Double(millis) / 1000)
    }
}

@available(iOS 16.0, *)
struct NativeDatePickerSheet: View {
    let palette: AppPalette
    let initial: Date
    let minimum: Date?
    let maximum: Date?
    let title: String
    let onDone: (Date) -> Void
    let onCancel: () -> Void

    @State private var selection: Date

    init(
        palette: AppPalette,
        initial: Date,
        minimum: Date?,
        maximum: Date?,
        title: String,
        onDone: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.palette = palette
        self.initial = initial
        self.minimum = minimum
        self.maximum = maximum
        self.title = title
        self.onDone = onDone
        self.onCancel = onCancel
        _selection = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()
                picker
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, 12)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { onDone(selection) }
                }
            }
        }
        .tint(palette.accent)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .environment(\.colorScheme, palette.colorScheme)
    }

    @ViewBuilder
    private var picker: some View {
        if let minimum, let maximum {
            DatePicker(title, selection: $selection, in: minimum...maximum, displayedComponents: .date)
                .labelsHidden()
        } else if let minimum {
            DatePicker(title, selection: $selection, in: minimum..., displayedComponents: .date)
                .labelsHidden()
        } else if let maximum {
            DatePicker(title, selection: $selection, in: ...maximum, displayedComponents: .date)
                .labelsHidden()
        } else {
            DatePicker(title, selection: $selection, displayedComponents: .date)
                .labelsHidden()
        }
    }
}
