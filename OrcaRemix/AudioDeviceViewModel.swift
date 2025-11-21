import Foundation
import Combine

class AudioDeviceViewModel: ObservableObject {
    @Published var availableDevices: [AudioDeviceManager.DeviceInfo] = []
    @Published var selectedDevice: AudioDeviceManager.DeviceInfo?

    private var cancellables = Set<AnyCancellable>()

    init() {
        AudioDeviceManager.startListening()

        AudioDeviceManager.devicesChanged
            .sink { [weak self] in
                self?.refreshDevices()
            }
            .store(in: &cancellables)

        refreshDevices()
    }

    deinit {
        AudioDeviceManager.stopListening()
    }

    func refreshDevices() {
        availableDevices = AudioDeviceManager.getOutputDevices()

        // Clear stale selection if device was unplugged
        if let selected = selectedDevice,
           !availableDevices.contains(where: { $0.id == selected.id }) {
            selectedDevice = nil
        }

        // 1. Try to find ES-8
        if let es8 = availableDevices.first(where: { $0.name.contains("ES-8") }) {
            selectedDevice = es8
            return
        }

        // 2. Fallback to current system default
        if let defaultID = AudioDeviceManager.getSystemDefaultOutputDeviceID(),
           let defaultDevice = availableDevices.first(where: { $0.id == defaultID }) {
            selectedDevice = defaultDevice
            return
        }

        // 3. Fallback to first available
        if selectedDevice == nil {
            selectedDevice = availableDevices.first
        }
    }

    func selectDevice(_ device: AudioDeviceManager.DeviceInfo) {
        selectedDevice = device
        _ = AudioDeviceManager.setSystemDefaultDevice(deviceID: device.id)
    }
}
