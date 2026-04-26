import SwiftUI
import Observation
import ServiceManagement
import AudioToolbox
import AppKit

@Observable
@MainActor
class MicraState {
    private enum Keys {
        static let walkieTalkieMode = "WalkieTalkieMode"
        static let audioFeedbackEnabled = "AudioFeedbackEnabled"
        static let isLockIntentActive = "IsLockIntentActive"
        static let lockedDeviceUID = "LockedDeviceUID"
        static let micraShortcut = "MicraShortcut"
    }

    private let engine = AudioEngine()
    
    var isMuted: Bool = true {
        didSet {
            if oldValue != isMuted {
                playFeedbackSound(forMute: isMuted)
            }
        }
    }
    var isRunning: Bool = false
    var launchAtLogin: Bool = false {
        didSet {
            if launchAtLogin != (SMAppService.mainApp.status == .enabled) {
                do {
                    if launchAtLogin { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch {
                    print("Login item error: \(error)")
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        }
    }
    
    var isWalkieTalkieMode: Bool = false {
        didSet {
            UserDefaults.standard.set(isWalkieTalkieMode, forKey: Keys.walkieTalkieMode)
            if isWalkieTalkieMode { engine.isMuted = true }
            registerGlobalShortcut(currentShortcut)
        }
    }

    var isAudioFeedbackEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isAudioFeedbackEnabled, forKey: Keys.audioFeedbackEnabled)
        }
    }
    
    var isLockedToCurrentDevice: Bool = false {
        didSet {
            if isLockedToCurrentDevice {
                UserDefaults.standard.set(true, forKey: Keys.isLockIntentActive)
                if let uid = engine.currentDeviceUID {
                    UserDefaults.standard.set(uid, forKey: Keys.lockedDeviceUID)
                }
            } else {
                let preferredUID = UserDefaults.standard.string(forKey: Keys.lockedDeviceUID)
                if let uid = preferredUID, engine.getDeviceID(for: uid) != nil {
                    UserDefaults.standard.set(false, forKey: Keys.isLockIntentActive)
                }
            }
        }
    }
    
    var deviceName: String { engine.deviceName }
    var currentShortcut: Shortcut? {
        didSet {
            saveShortcut(currentShortcut)
            registerGlobalShortcut(currentShortcut)
        }
    }
    
    init() {
        self.isMuted = engine.isMuted
        self.isRunning = engine.isRunning
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.isWalkieTalkieMode = UserDefaults.standard.bool(forKey: Keys.walkieTalkieMode)
        self.isAudioFeedbackEnabled = UserDefaults.standard.object(forKey: Keys.audioFeedbackEnabled) as? Bool ?? true
        self.handleDeviceChange()
        self.currentShortcut = loadShortcut()
        engine.onStateChange = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in self.handleDeviceChange() }
        }
        registerGlobalShortcut(currentShortcut)
    }

    private func playFeedbackSound(forMute muted: Bool) {
        guard isAudioFeedbackEnabled else { return }
        if muted {
            NSSound(named: "Frog")?.play()
        } else {
            NSSound(named: "Morse")?.play()
        }
    }

    private func handleDeviceChange() {
        self.isMuted = engine.isMuted
        self.isRunning = engine.isRunning
        let isLockIntentActive = UserDefaults.standard.bool(forKey: Keys.isLockIntentActive)
        let preferredUID = UserDefaults.standard.string(forKey: Keys.lockedDeviceUID)
        if isLockIntentActive, let uid = preferredUID {
            if let targetID = engine.getDeviceID(for: uid) {
                if engine.currentDeviceID != targetID {
                    engine.setDefaultInputDevice(targetID)
                }
                self.isLockedToCurrentDevice = true
            } else {
                self.isLockedToCurrentDevice = false
            }
        } else {
            self.isLockedToCurrentDevice = false
        }
    }

    func toggleMute() {
        engine.isMuted.toggle()
        self.isMuted = engine.isMuted
    }

    private func registerGlobalShortcut(_ shortcut: Shortcut?) {
        guard let shortcut = shortcut else { 
            GlobalHotKeyManager.shared.unregister()
            return 
        }
        GlobalHotKeyManager.shared.register(
            keyCode: UInt32(shortcut.keyCode), 
            modifiers: shortcut.modifierFlags,
            onDown: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    if self.isWalkieTalkieMode { self.engine.isMuted = false }
                    else { self.toggleMute() }
                }
            },
            onUp: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    if self.isWalkieTalkieMode { self.engine.isMuted = true }
                }
            }
        )
    }
    
    private func saveShortcut(_ shortcut: Shortcut?) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: Keys.micraShortcut)
        }
    }
    
    private func loadShortcut() -> Shortcut? {
        guard let data = UserDefaults.standard.data(forKey: Keys.micraShortcut),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) else {
            return Shortcut(keyCode: 46, modifierFlags: 0x0100 | 0x0200)
        }
        return shortcut
    }
}
