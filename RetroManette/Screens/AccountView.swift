import SwiftUI

/// Sign in with the email of retromanette.com, sign out, or delete the account.
struct AccountView: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var confirmDelete = false
    @FocusState private var focus: Field?
    private enum Field { case email, code }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.16)).frame(width: 72, height: 72)
                        Image(systemName: account.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                            .font(.system(size: 34)).foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 20)

                    if account.isSignedIn { signedIn } else { signedOut }

                    if let key = account.errorKey {
                        Text(LocalizedStringKey(key)).font(.system(size: 14)).foregroundStyle(.red).multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("account.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("common.done") { dismiss() } } }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear { account.clearMessages() }
        .alert("account.delete.title", isPresented: $confirmDelete) {
            Button("account.delete", role: .destructive) { Task { if await account.deleteAccount() { dismiss() } } }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("account.delete.message")
        }
    }

    private var signedOut: some View {
        VStack(spacing: 16) {
            Text("account.intro")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            field("account.email", text: $email, focused: .email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .disabled(account.codeSent)
                .opacity(account.codeSent ? 0.6 : 1)

            if account.codeSent {
                Text(String(format: String(localized: "account.codeSent"), email.trimmingCharacters(in: .whitespaces)))
                    .font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                field("account.code", text: $code, focused: .code)
                    .keyboardType(.asciiCapable)
                    .textContentType(.oneTimeCode)
                Button { Task { await account.verify(email: email, code: code) } } label: {
                    HStack(spacing: 10) { if account.isBusy { ProgressView().tint(Theme.accentInk) }; Text("account.verify") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(account.isBusy || code.trimmingCharacters(in: .whitespaces).count < 6)
                Button { code = ""; account.startOver() } label: { Text("account.other").font(.system(size: 15)).foregroundStyle(Theme.accent) }
            } else {
                Button { Task { await account.requestCode(email: email); if account.codeSent { focus = .code } } } label: {
                    HStack(spacing: 10) { if account.isBusy { ProgressView().tint(Theme.accentInk) }; Text("account.sendCode") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(account.isBusy || email.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("account.optional")
                .font(.system(size: 12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
    }

    private var signedIn: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("account.signedInAs").font(.system(size: 13)).foregroundStyle(Theme.muted)
                Text(account.email ?? "").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text)
            }
            Text("account.signedIn.note")
                .font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button { Task { await account.signOut() } } label: { Text("account.signout") }
                .buttonStyle(PrimaryButtonStyle(prominent: false))
            Button(role: .destructive) { confirmDelete = true } label: {
                Text("account.delete").font(.system(size: 15, weight: .medium))
            }
            .padding(.top, 8)
        }
    }

    private func field(_ title: LocalizedStringKey, text: Binding<String>, focused: Field) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focus, equals: focused)
            .font(.system(size: 17))
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.surfaceHigh))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}
