import Foundation
import CoreAudio
import AVFoundation
import Combine

/// Manages audio device detection and configuration
class AudioDeviceManager {

    // MARK: - Publishers
    static let devicesChanged = PassthroughSubject<Void, Never>()


    // MARK: - Device Information

    struct DeviceInfo: Identifiable, Hashable {
        let id: AudioDeviceID
        let name: String
        let outputChannels: Int

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
            return lhs.id == rhs.id
        }
    }

    // MARK: - Device Enumeration

    /// Get all available audio output devices
    static func getOutputDevices() -> [DeviceInfo] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        ) == noErr else {
            print("Failed to get device list size")
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        ) == noErr else {
            print("Failed to get device list")
            return []
        }

        return deviceIDs.compactMap { deviceID in
            guard let name = getDeviceName(deviceID) else { return nil }
            guard let channels = getOutputChannelCount(deviceID), channels > 0 else { return nil }

            return DeviceInfo(
                id: deviceID,
                name: name,
                outputChannels: channels
            )
        }
    }

    // MARK: - Device Properties

    internal static func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)

        let result = withUnsafeMutablePointer(to: &deviceName) { pointer in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                pointer
            )
        }

        guard result == noErr, let name = deviceName else {
            return nil
        }

        return name as String
    }

    internal static func getOutputChannelCount(_ deviceID: AudioDeviceID) -> Int? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return nil
        }

        // Allocate raw bytes based on the actual size CoreAudio needs
        // This is critical for devices with multiple buffers (e.g., Expert Sleepers ES-8)
        let bufferListPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListPointer.deallocate() }

        guard AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferListPointer
        ) == noErr else {
            return nil
        }

        // Cast raw memory to typed pointer
        let bufferList = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer<AudioBufferList>(OpaquePointer(bufferListPointer))
        )
        var totalChannels = 0

        for buffer in bufferList {
            totalChannels += Int(buffer.mNumberChannels)
        }

        return totalChannels
    }

    /// Set the system default output device
    static func setSystemDefaultDevice(deviceID: AudioDeviceID) -> Bool {
        var deviceIDCopy = deviceID
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let result = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceIDCopy
        )

        return result == noErr
    }

    /// Get the current system default output device ID
    static func getSystemDefaultOutputDeviceID() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = kAudioDeviceUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        return result == noErr ? deviceID : nil
    }

    // MARK: - Listeners

    private static var isListening = false

    private static let propertyListener: AudioObjectPropertyListenerBlock = { _, _ in
        DispatchQueue.main.async {
            devicesChanged.send()
        }
    }

    static func startListening() {
        guard !isListening else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            nil,
            propertyListener
        )

        // Also listen for default device changes
        propertyAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            nil,
            propertyListener
        )

        isListening = true
    }

    static func stopListening() {
        guard isListening else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            nil,
            propertyListener
        )

        propertyAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            nil,
            propertyListener
        )

        isListening = false
    }
}
