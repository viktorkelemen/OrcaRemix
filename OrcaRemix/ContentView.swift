import SwiftUI

struct ContentView: View {
    @StateObject private var audioDeviceViewModel = AudioDeviceViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Hello, World!")
                .font(.largeTitle)
                .padding()

            deviceSelectionView
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding()
    }

    private var deviceSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AUDIO DEVICE")
                .font(.headline)
                .foregroundColor(.blue)

            HStack {
                Picker("Device", selection: Binding(
                    get: {
                        audioDeviceViewModel.selectedDevice?.id ?? (audioDeviceViewModel.availableDevices.first?.id ?? 0)
                    },
                    set: { deviceID in
                        if let device = audioDeviceViewModel.availableDevices.first(where: { $0.id == deviceID }) {
                            audioDeviceViewModel.selectDevice(device)
                        }
                    }
                )) {
                    ForEach(audioDeviceViewModel.availableDevices) { device in
                        HStack {
                            Text(device.name)
                            Text("(\(device.outputChannels) ch)")
                                .foregroundColor(.gray)
                        }
                        .tag(device.id)
                    }
                }
                .frame(maxWidth: .infinity)

                Button(action: {
                    audioDeviceViewModel.refreshDevices()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
