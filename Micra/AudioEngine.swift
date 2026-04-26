import Foundation
import AudioToolbox

class AudioEngine {
    var onStateChange: (() -> Void)?
    private var lastListenedDeviceID: AudioDeviceID?

    private var inputDevice: AudioDeviceID? {
        var deviceId = kAudioObjectUnknown
        var deviceIdSize = UInt32(MemoryLayout.size(ofValue: deviceId))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        let error = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &deviceIdSize, &deviceId)
        return error == kAudioHardwareNoError && deviceId != kAudioObjectUnknown ? deviceId : nil
    }

    var currentDeviceID: AudioDeviceID? { inputDevice }

    func setDefaultInputDevice(_ deviceID: AudioDeviceID) {
        var device = deviceID
        let size = UInt32(MemoryLayout.size(ofValue: device))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        _ = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &device)
    }

    func isDeviceAvailable(id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices)
        return devices.contains(id)
    }

    var currentDeviceUID: String? {
        guard let deviceId = inputDevice else { return nil }
        var name: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout.size(ofValue: name))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let error = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &nameSize, &name)
        return error == kAudioHardwareNoError ? (name?.takeRetainedValue() as String?) : nil
    }

    func getDeviceID(for uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices)
        for deviceId in devices {
            var deviceUID: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout.size(ofValue: deviceUID))
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            if AudioObjectGetPropertyData(deviceId, &uidAddress, 0, nil, &uidSize, &deviceUID) == kAudioHardwareNoError {
                if let currentUID = deviceUID?.takeRetainedValue() as String?, currentUID == uid { return deviceId }
            }
        }
        return nil
    }

    var deviceName: String {
        guard let deviceId = inputDevice else { return "No Input Device" }
        var name: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout.size(ofValue: name))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let error = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &nameSize, &name)
        if error == kAudioHardwareNoError, let unmanagedName = name { return unmanagedName.takeRetainedValue() as String }
        return "Unknown"
    }

    var isMuted: Bool {
        get {
            guard let deviceId = inputDevice else { return true }
            var muteState: UInt32 = 0
            var muteStateSize = UInt32(MemoryLayout.size(ofValue: muteState))
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var error = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &muteStateSize, &muteState)
            if error != kAudioHardwareNoError {
                address.mScope = kAudioObjectPropertyScopeGlobal
                error = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &muteStateSize, &muteState)
            }
            return error == kAudioHardwareNoError ? muteState == 1 : true
        }
        set {
            guard let deviceId = inputDevice else { return }
            var muteState: UInt32 = newValue ? 1 : 0
            let muteStateSize = UInt32(MemoryLayout.size(ofValue: muteState))
            var inputAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            _ = AudioObjectSetPropertyData(deviceId, &inputAddress, 0, nil, muteStateSize, &muteState)
            var globalAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            _ = AudioObjectSetPropertyData(deviceId, &globalAddress, 0, nil, muteStateSize, &muteState)
        }
    }

    var isRunning: Bool {
        guard let deviceId = inputDevice else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let error = AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &value)
        return error == kAudioHardwareNoError ? value == 1 : false
    }

    init() { setupListeners() }

    private func setupListeners() {
        var defaultInputAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputAddress, .main) { [weak self] _, _ in
            self?.updateDeviceSpecificListeners()
            self?.onStateChange?()
        }
        var devicesAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, .main) { [weak self] _, _ in
            self?.updateDeviceSpecificListeners()
            self?.onStateChange?()
        }
        updateDeviceSpecificListeners()
    }

    private func updateDeviceSpecificListeners() {
        let currentID = inputDevice
        if currentID == lastListenedDeviceID && currentID != nil { return }
        if let newID = currentID {
            var inputMute = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementWildcard)
            AudioObjectAddPropertyListenerBlock(newID, &inputMute, .main) { [weak self] _, _ in self?.onStateChange?() }
            var globalMute = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementWildcard)
            AudioObjectAddPropertyListenerBlock(newID, &globalMute, .main) { [weak self] _, _ in self?.onStateChange?() }
            var isRunning = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectAddPropertyListenerBlock(newID, &isRunning, .main) { [weak self] _, _ in self?.onStateChange?() }
            lastListenedDeviceID = newID
        }
    }
}
