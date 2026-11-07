import SwiftUI
import UIKit

/// Hosts the emulator's picture layer.
struct GameScreenView: UIViewRepresentable {
    let layer: CALayer
    func makeUIView(context: Context) -> ScreenContainer { ScreenContainer(content: layer) }
    func updateUIView(_ uiView: ScreenContainer, context: Context) {}
}

final class ScreenContainer: UIView {
    private let content: CALayer
    init(content: CALayer) {
        self.content = content
        super.init(frame: .zero)
        backgroundColor = .black
        layer.addSublayer(content)
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.frame = bounds
        content.contentsScale = window?.screen.scale ?? UIScreen.main.scale
        CATransaction.commit()
    }
}

struct PlayerView: View {
    let request: PlayRequest
    @StateObject private var session: EmulatorSession
    @Environment(\.dismiss) private var dismiss
    @AppStorage("controlsOpacity") private var controlsOpacity = 0.95
    @AppStorage("smoothScaling") private var smoothScaling = false
    @AppStorage("autoResume") private var autoResume = true
    @State private var showMenu = false
    @State private var slotsMode: SlotsSheet.Mode?
    @State private var toast: LocalizedStringKey?

    init(request: PlayRequest) {
        self.request = request
        _session = StateObject(wrappedValue: EmulatorSession(request: request))
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()
                if landscape { landscapeLayout(geo) } else { portraitLayout(geo) }

                if case .failed(let message) = session.phase {
                    failure(message)
                }
                if let toast {
                    Text(toast)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 60)
                        .transition(.opacity)
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            session.setSmoothScaling(smoothScaling)
            session.start(resumeAutomatically: autoResume)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            session.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: smoothScaling) { session.setSmoothScaling($0) }
        .onChange(of: showMenu) { session.pause($0 || slotsMode != nil) }
        .onChange(of: slotsMode) { session.pause($0 != nil || showMenu) }
        .sheet(isPresented: $showMenu) { menuSheet }
        .sheet(item: $slotsMode) { mode in
            SlotsSheet(session: session, mode: mode) { message in
                slotsMode = nil
                if let message { flash(message) }
            }
        }
    }

    // MARK: - Layouts

    private func portraitLayout(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topBar.padding(.top, 6)
            Spacer(minLength: 8)
            GameScreenView(layer: session.videoLayer)
                .aspectRatio(session.aspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
            Spacer(minLength: 16)
            VStack(spacing: 18) {
                HStack {
                    PadPill(label: "L", button: .l, width: 84, height: 36, press: session.press)
                    Spacer()
                    PadPill(label: "R", button: .r, width: 84, height: 36, press: session.press)
                }
                HStack(alignment: .center) {
                    DPadView(size: 156, press: session.press)
                    Spacer(minLength: 8)
                    ActionCluster(size: 66, press: session.press)
                }
                HStack(spacing: 22) {
                    PadPill(label: String(localized: "pad.select"), button: .select, press: session.press)
                    PadPill(label: String(localized: "pad.start"), button: .start, press: session.press)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
            .opacity(controlsOpacity)
        }
    }

    private func landscapeLayout(_ geo: GeometryProxy) -> some View {
        ZStack {
            GameScreenView(layer: session.videoLayer)
                .aspectRatio(session.aspect, contentMode: .fit)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 8)
            HStack(alignment: .bottom) {
                VStack(spacing: 14) {
                    PadPill(label: "L", button: .l, width: 84, height: 36, press: session.press)
                    DPadView(size: 150, press: session.press)
                }
                Spacer()
                VStack(spacing: 14) {
                    PadPill(label: "R", button: .r, width: 84, height: 36, press: session.press)
                    ActionCluster(size: 64, press: session.press)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 14)
            .opacity(controlsOpacity)
            VStack {
                HStack { Spacer(); menuButton }.padding(.horizontal, 18).padding(.top, 8)
                Spacer()
                HStack(spacing: 18) {
                    PadPill(label: String(localized: "pad.select"), button: .select, width: 78, press: session.press)
                    PadPill(label: String(localized: "pad.start"), button: .start, width: 78, press: session.press)
                }
                .padding(.bottom, 14)
                .opacity(controlsOpacity)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text(request.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Spacer()
            menuButton
        }
        .padding(.horizontal, 18)
    }

    private var menuButton: some View {
        Button { showMenu = true } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .accessibilityLabel(Text("player.menu"))
    }

    // MARK: - Menu

    private var menuSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button { showMenu = false } label: { Label("player.resume", systemImage: "play.fill") }
                    Button { showMenu = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { slotsMode = .save } } label: { Label("player.save", systemImage: "square.and.arrow.down") }
                    Button { showMenu = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { slotsMode = .load } } label: { Label("player.load", systemImage: "square.and.arrow.up") }
                }
                Section {
                    Toggle(isOn: Binding(get: { session.fastForward }, set: { session.fastForward = $0 })) { Label("player.fast", systemImage: "forward.fill") }
                    Toggle(isOn: $smoothScaling) { Label("player.smooth", systemImage: "sparkles") }
                    Button(role: .destructive) { session.reset(); showMenu = false } label: { Label("player.reset", systemImage: "arrow.counterclockwise") }
                }
                Section {
                    Button(role: .destructive) { showMenu = false; dismiss() } label: { Label("player.exit", systemImage: "xmark.circle.fill") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(request.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("common.done") { showMenu = false } } }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 36)).foregroundStyle(Theme.accent)
            Text(message).foregroundStyle(Theme.text).multilineTextAlignment(.center)
            Button("player.exit") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 220)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92))
    }

    private func flash(_ message: LocalizedStringKey) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { toast = nil } }
    }
}

// MARK: - Save slots

struct SlotsSheet: View {
    enum Mode: String, Identifiable {
        case save, load
        var id: String { rawValue }
    }

    @ObservedObject var session: EmulatorSession
    let mode: Mode
    let done: (LocalizedStringKey?) -> Void
    @State private var slots: [EmulatorSession.SlotInfo] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    ForEach(slots) { slot in
                        Button { choose(slot) } label: { card(slot) }
                            .buttonStyle(.plain)
                            .disabled(mode == .load && slot.date == nil)
                            .opacity(mode == .load && slot.date == nil ? 0.45 : 1)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(LocalizedStringKey(mode == .save ? "player.save" : "player.load"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("common.done") { done(nil) } } }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        .onAppear { slots = session.slots() }
    }

    private func card(_ slot: EmulatorSession.SlotInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Theme.surface
                if let image = slot.thumbnail {
                    Image(uiImage: image).resizable().interpolation(.none).scaledToFit()
                } else {
                    Image(systemName: "plus").font(.system(size: 22)).foregroundStyle(Theme.muted)
                }
            }
            .aspectRatio(1.5, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(String(format: String(localized: "player.slot"), slot.slot))
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
            Text(slot.date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? String(localized: "player.empty"))
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .padding(10)
        .glassCard()
    }

    private func choose(_ slot: EmulatorSession.SlotInfo) {
        switch mode {
        case .save:
            session.saveState(slot: slot.slot) { ok in done(ok ? "player.saved" : "player.failed") }
        case .load:
            session.loadState(slot: slot.slot) { ok in done(ok ? "player.loaded" : "player.failed") }
        }
    }
}
