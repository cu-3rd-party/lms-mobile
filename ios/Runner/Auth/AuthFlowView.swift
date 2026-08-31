import SwiftUI

enum AuthOutcome {
    case cookie(String)
    case demo
    case cancelled
}

@available(iOS 16.0, *)
private struct CardBackground: ViewModifier {
    let palette: AppPalette

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(14)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content
                .padding(14)
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(palette.border, lineWidth: 1)
                )
        }
    }
}

@available(iOS 16.0, *)
struct AuthFlowView: View {
    let palette: AppPalette
    let version: String
    let onEvent: (String) -> Void
    let onVerify: (String, @escaping (Bool) -> Void) -> Void
    let onFinish: (AuthOutcome) -> Void

    @State private var showWeb = false

    var body: some View {
        NavigationStack {
            AuthStartView(
                palette: palette,
                version: version,
                onLogin: {
                    onEvent("auth.login.buttonPressed")
                    showWeb = true
                },
                onDemo: {
                    onEvent("auth.demo.buttonPressed")
                    onFinish(.demo)
                }
            )
            .navigationDestination(isPresented: $showWeb) {
                AuthWebScreen(
                    palette: palette,
                    onVerify: onVerify,
                    onSuccess: { onFinish(.cookie($0)) }
                )
            }
        }
        .tint(palette.accent)
        .preferredColorScheme(palette.colorScheme)
    }
}

@available(iOS 16.0, *)
struct AuthStartView: View {
    let palette: AppPalette
    let version: String
    let onLogin: () -> Void
    let onDemo: () -> Void

    private let steps = [
        "Нажмите «Войти через браузер».",
        "Войдите в LMS в открывшемся окне.",
        "После входа вернёмся в приложение сами."
    ]

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                logo
                    .frame(height: 96)
                    .padding(.bottom, 16)

                Text("Авторизация")
                    .font(.system(size: 18))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.bottom, 16)

                Text("Авторизуйтесь через браузер, мы сохраним сессию автоматически.")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                stepsCard
                    .padding(.bottom, 24)

                loginButton
                    .padding(.bottom, 12)

                Button(action: onDemo) {
                    Text("Попробовать без входа")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Text("Версия \(version)")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textTertiary)
                    .padding(.bottom, 12)
            }
            .padding(24)
        }
        .navigationBarHidden(true)
    }

    private var logo: some View {
        Group {
            if palette.isDark {
                Image("AuthLogo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image("AuthLogo")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(palette.textPrimary)
            }
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.accent)
                Text("Как войти")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackground(palette: palette))
    }

    private var loginButton: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: onLogin) {
                    Text("Войти через браузер")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.glassProminent)
                .tint(palette.accent)
            } else {
                Button(action: onLogin) {
                    Text("Войти через браузер")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(palette.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

@available(iOS 16.0, *)
struct AuthWebScreen: View {
    let palette: AppPalette
    let onVerify: (String, @escaping (Bool) -> Void) -> Void
    let onSuccess: (String) -> Void

    @StateObject private var controller = AuthWebController()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            palette.background.ignoresSafeArea()

            AuthWebViewRepresentable(controller: controller)
                .ignoresSafeArea(edges: .bottom)

            if controller.isLoading {
                ProgressView(value: max(controller.progress, 0.02))
                    .progressViewStyle(.linear)
                    .tint(palette.accent)
            }

            if let errorText = controller.errorText {
                VStack {
                    Spacer()
                    Text(errorText)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(palette.danger.opacity(0.9))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("Авторизация")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    controller.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            controller.onCookie = { value in
                onVerify(value) { ok in
                    if ok {
                        onSuccess(value)
                    } else {
                        controller.rejectCookie(message: "Не удалось подтвердить авторизацию. Попробуйте снова.")
                    }
                }
            }
            controller.start()
        }
    }
}
