import AVFoundation
import Foundation
import GameController
import UIKit

/// RetroPad button numbers (the numbering libretro cores use).
enum PadButton: UInt32 {
    case b = 0, y = 1, select = 2, start = 3, up = 4, down = 5, left = 6, right = 7, a = 8, x = 9, l = 10, r = 11
}

/// Runs one game: the core on its own thread, sound through AVAudioEngine, the picture on a CALayer, save states and
/// battery saves in the app's Saves folder. Everything that touches the core runs on the emulation thread; everything
/// the screens observe is changed on the main thread.
final class EmulatorSession: ObservableObject {
    enum Phase: Equatable { case idle, running, paused, failed(String) }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var aspect: Double = 1.5
    @Published private(set) var lastImage: CGImage?
    @Published var fastForward = false { didSet { fastForwardFlag.set(fastForward) } }

    /// The layer that shows the picture; SwiftUI hosts it in `GameScreenView`.
    let videoLayer = CALayer()

    private let request: PlayRequest
    private let saveFolder: URL
    private var thread: Thread?
    private let queue = CommandQueue()
    private let stopFlag = AtomicFlag()
    private let pauseFlag = AtomicFlag()
    private let fastForwardFlag = AtomicFlag()
    private var displayLink: CADisplayLink?
    private var displayProxy: DisplayLinkProxy?
    private var engine: AVAudioEngine?
    private var audioScratch: UnsafeMutablePointer<Int16>?
    private var frameBuffer = [UInt8](repeating: 0, count: 4 * 1024 * 1024)
    private var lastFrameCounter: UInt64 = 0
    private var controllerObservers: [NSObjectProtocol] = []

    init(request: PlayRequest) {
        self.request = request
        self.saveFolder = Paths.saveFolder(for: request.key)
        videoLayer.backgroundColor = UIColor.black.cgColor
        videoLayer.contentsGravity = .resizeAspect
        videoLayer.magnificationFilter = .nearest
        videoLayer.minificationFilter = .linear
    }

    deinit {
        audioScratch?.deallocate()
    }

    // MARK: - File names

    private var sramPath: String { saveFolder.appendingPathComponent("game.sav").path }
    private func statePath(_ slot: Int) -> URL { saveFolder.appendingPathComponent(slot == 0 ? "auto.state" : "slot\(slot).state") }
    private func thumbPath(_ slot: Int) -> URL { saveFolder.appendingPathComponent("slot\(slot).png") }

    // MARK: - Start and stop

    func start(resumeAutomatically: Bool) {
        guard thread == nil else { return }
        let rom = request.romPath
        let systemDir = Paths.system.path
        let saveDir = saveFolder.path
        let sram = sramPath
        let auto = statePath(0)
        let resume = resumeAutomatically
        let stop = stopFlag, pause = pauseFlag, fast = fastForwardFlag, commands = queue

        let t = Thread { [weak self] in
            let result = rh_open(rom, systemDir, saveDir)
            if result != 0 {
                let message: String
                switch result {
                case -1: message = String(localized: "player.error.file")
                case -2: message = String(localized: "player.error.core")
                default: message = String(localized: "player.error.memory")
                }
                DispatchQueue.main.async { self?.phase = .failed(message) }
                return
            }
            _ = rh_sram_load(sram)
            if resume, let data = try? Data(contentsOf: auto) {
                data.withUnsafeBytes { raw in
                    if let base = raw.baseAddress, rh_state_size() == data.count { _ = rh_state_load(base, data.count) }
                }
            }
            let info = rh_get_info()
            DispatchQueue.main.async { self?.coreOpened(info) }

            let frameTime = 1.0 / max(info.fps, 30)
            let targetFill = Int(Double(RH_AUDIO_RATE) * 0.07)
            var nextFrame = DispatchTime.now().uptimeNanoseconds
            var framesSinceSave = 0
            while !stop.get() {
                commands.runAll()
                if pause.get() { usleep(20_000); nextFrame = DispatchTime.now().uptimeNanoseconds; continue }
                if fast.get() {
                    rh_run()
                    let step = UInt64(frameTime / 4 * 1_000_000_000)
                    nextFrame += step
                    let now = DispatchTime.now().uptimeNanoseconds
                    if nextFrame > now { usleep(UInt32((nextFrame - now) / 1000)) } else { nextFrame = now }
                } else if rh_audio_fill() < targetFill {
                    rh_run()
                    framesSinceSave += 1
                } else {
                    usleep(1_500)
                }
                if framesSinceSave > 600 { _ = rh_sram_save(sram); framesSinceSave = 0 }
            }
            commands.runAll()
            _ = rh_sram_save(sram)
            rh_close()
        }
        t.name = "RetroManette.Emulation"
        t.qualityOfService = .userInteractive
        t.stackSize = 2 * 1024 * 1024
        thread = t
        t.start()
    }

    private func coreOpened(_ info: rh_info) {
        aspect = info.aspect > 0.3 ? info.aspect : 1.5
        startAudio()
        startDisplay()
        observeControllers()
        phase = .running
    }

    /// Saves the battery save and a resume point, then stops everything.
    func stop(saveResume: Bool = true) {
        guard thread != nil else { return }
        if saveResume { saveState(slot: 0, thumbnail: false) { _ in } }
        pauseFlag.set(false)
        // give the queued auto-save a moment to run before the thread ends
        queue.runAfter {
            self.stopFlag.set(true)
        }
        stopDisplay()
        engine?.stop()
        engine = nil
        for o in controllerObservers { NotificationCenter.default.removeObserver(o) }
        controllerObservers = []
        thread = nil
        phase = .idle
    }

    func pause(_ on: Bool) {
        pauseFlag.set(on)
        if phase == .running || phase == .paused { phase = on ? .paused : .running }
        if on { engine?.pause() } else { try? engine?.start() }
    }

    func reset() { queue.async { rh_reset() } }

    // MARK: - Input

    func press(_ button: PadButton, down: Bool) { rh_set_button(button.rawValue, down ? 1 : 0) }

    func releaseAll() { for id in 0..<12 { rh_set_button(UInt32(id), 0) } }

    private func observeControllers() {
        let center = NotificationCenter.default
        controllerObservers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.bindControllers()
        })
        bindControllers()
    }

    private func bindControllers() {
        for controller in GCController.controllers() {
            guard let pad = controller.extendedGamepad else { continue }
            let map: [(GCControllerButtonInput, PadButton)] = [
                (pad.buttonA, .a), (pad.buttonB, .b), (pad.buttonX, .x), (pad.buttonY, .y),
                (pad.leftShoulder, .l), (pad.rightShoulder, .r),
                (pad.dpad.up, .up), (pad.dpad.down, .down), (pad.dpad.left, .left), (pad.dpad.right, .right),
                (pad.buttonMenu, .start),
            ]
            for (input, button) in map {
                input.pressedChangedHandler = { _, _, pressed in rh_set_button(button.rawValue, pressed ? 1 : 0) }
            }
            pad.buttonOptions?.pressedChangedHandler = { _, _, pressed in rh_set_button(PadButton.select.rawValue, pressed ? 1 : 0) }
            // the left stick works as a second D-pad
            pad.leftThumbstick.valueChangedHandler = { _, x, y in
                rh_set_button(PadButton.left.rawValue, x < -0.5 ? 1 : 0)
                rh_set_button(PadButton.right.rawValue, x > 0.5 ? 1 : 0)
                rh_set_button(PadButton.up.rawValue, y > 0.5 ? 1 : 0)
                rh_set_button(PadButton.down.rawValue, y < -0.5 ? 1 : 0)
            }
        }
    }

    // MARK: - Picture

    private func startDisplay() {
        let proxy = DisplayLinkProxy { [weak self] in self?.showNewFrame() }
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        displayProxy = proxy
        displayLink = link
    }

    private func stopDisplay() {
        displayLink?.invalidate()
        displayLink = nil
        displayProxy = nil
    }

    private func showNewFrame() {
        var w: Int32 = 0, h: Int32 = 0
        let counter = frameBuffer.withUnsafeMutableBufferPointer { buf in
            rh_copy_frame(buf.baseAddress, buf.count, &w, &h)
        }
        guard counter != 0, counter != lastFrameCounter, w > 0, h > 0 else { return }
        lastFrameCounter = counter
        let bytes = Int(w) * Int(h) * 4
        let data = Data(frameBuffer[0..<bytes])
        guard let provider = CGDataProvider(data: data as CFData) else { return }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let image = CGImage(width: Int(w), height: Int(h), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Int(w) * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info, provider: provider, decode: nil,
                                  shouldInterpolate: false, intent: .defaultIntent) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.contents = image
        CATransaction.commit()
        lastImage = image
    }

    func setSmoothScaling(_ smooth: Bool) {
        videoLayer.magnificationFilter = smooth ? .linear : .nearest
    }

    // MARK: - Sound

    private func startAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            return
        }
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(RH_AUDIO_RATE), channels: 2)!
        let scratch = UnsafeMutablePointer<Int16>.allocate(capacity: 4096 * 2)
        audioScratch = scratch
        let fast = fastForwardFlag
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            var done = 0
            let total = Int(frameCount)
            while done < total {
                let n = min(total - done, 4096)
                _ = rh_audio_pop(scratch, n)
                let mute = fast.get()
                for i in 0..<n {
                    left[done + i] = mute ? 0 : Float(scratch[i * 2]) / 32768
                    right[done + i] = mute ? 0 : Float(scratch[i * 2 + 1]) / 32768
                }
                done += n
            }
            return noErr
        }
        let engine = AVAudioEngine()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            self.engine = engine
        } catch {
            self.engine = nil
        }
    }

    // MARK: - Save states

    struct SlotInfo: Identifiable {
        let slot: Int
        let date: Date?
        let thumbnail: UIImage?
        var id: Int { slot }
    }

    func slots() -> [SlotInfo] {
        (1...9).map { slot in
            let url = statePath(slot)
            let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            let image = UIImage(contentsOfFile: thumbPath(slot).path)
            return SlotInfo(slot: slot, date: date, thumbnail: date == nil ? nil : image)
        }
    }

    func saveState(slot: Int, thumbnail: Bool = true, completion: @escaping (Bool) -> Void) {
        let url = statePath(slot)
        let thumb = thumbnail ? lastImage.map { UIImage(cgImage: $0) }?.pngData() : nil
        let thumbURL = thumbPath(slot)
        queue.async {
            let size = rh_state_size()
            var ok = false
            if size > 0 {
                var data = Data(count: size)
                let saved = data.withUnsafeMutableBytes { raw -> Int32 in
                    guard let base = raw.baseAddress else { return 0 }
                    return rh_state_save(base, size)
                }
                if saved == 1 { ok = (try? data.write(to: url, options: .atomic)) != nil }
            }
            if ok, let thumb { try? thumb.write(to: thumbURL, options: .atomic) }
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func loadState(slot: Int, completion: @escaping (Bool) -> Void) {
        let url = statePath(slot)
        queue.async {
            var ok = false
            if let data = try? Data(contentsOf: url), rh_state_size() == data.count {
                ok = data.withUnsafeBytes { raw -> Bool in
                    guard let base = raw.baseAddress else { return false }
                    return rh_state_load(base, data.count) == 1
                }
            }
            DispatchQueue.main.async { completion(ok) }
        }
    }
}

// MARK: - Small helpers

/// A flag several threads can read and write.
final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ new: Bool) { lock.lock(); value = new; lock.unlock() }
}

/// Work for the emulation thread: it runs between two frames.
final class CommandQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [() -> Void] = []
    func async(_ work: @escaping () -> Void) { lock.lock(); items.append(work); lock.unlock() }
    func runAfter(_ work: @escaping () -> Void) { async(work) }
    func runAll() {
        lock.lock(); let current = items; items = []; lock.unlock()
        for work in current { work() }
    }
}

final class DisplayLinkProxy: NSObject {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func tick() { handler() }
}
