import Foundation
import Combine

class AudioDeviceViewModel: ObservableObject {
    @Published var availableDevices: [AudioDeviceManager.DeviceInfo] = []
    @Published var selectedDevice: AudioDeviceManager.DeviceInfo?

    init() {
        refreshDevices()
    }

    func refreshDevices() {
        availableDevices = AudioDeviceManager.getOutputDevices()

        if selectedDevice == nil {
            selectedDevice = availableDevices.first
        }
    }

    func selectDevice(_ device: AudioDeviceManager.DeviceInfo) {
        selectedDevice = device
        _ = AudioDeviceManager.setSystemDefaultDevice(deviceID: device.id)
    }
}
