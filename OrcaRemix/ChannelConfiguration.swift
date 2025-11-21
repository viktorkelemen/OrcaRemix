import Foundation
import CoreAudio

/// Configuration for a single output channel
struct ChannelConfiguration: Identifiable {
    let id: Int  // Channel number (1-8)
    var signal: SignalType

    enum SignalType: String, CaseIterable, Identifiable {
        case none = "None"
        case gate = "Gate"

        var id: String { rawValue }
    }
}

/// Manages all 8 channel configurations
class ChannelConfigurationManager: ObservableObject {
    @Published var channels: [ChannelConfiguration]
    private var audioEngine: GateAudioEngine?
    var selectedDeviceID: AudioDeviceID?

    init() {
        // Initialize 8 channels, channel 2 defaults to Gate
        self.channels = (1...8).map { channelNumber in
            ChannelConfiguration(id: channelNumber, signal: channelNumber == 2 ? .gate : .none)
        }
    }

    /// Get channels that have Gate signal configured
    func gateChannels() -> [Int] {
        return channels
            .filter { $0.signal == .gate }
            .map { $0.id }
    }

    /// Setup audio engine with selected device
    func setupAudioEngine(deviceID: AudioDeviceID?) {
        // Stop existing engine first
        audioEngine?.stop()
        
        selectedDeviceID = deviceID
        let newEngine = GateAudioEngine()
        do {
            try newEngine.setup(deviceID: deviceID)
            self.audioEngine = newEngine
        } catch {
            print("⚠️ Failed to setup audio engine: \(error)")
            self.audioEngine = nil
        }
    }

    /// Trigger gate signal to configured channels
    func triggerGate() {
        let activeChannels = gateChannels()
        guard !activeChannels.isEmpty else {
            print("⚠️  No channels configured for Gate signal")
            return
        }

        // Setup audio engine if needed
        if audioEngine == nil {
            setupAudioEngine(deviceID: selectedDeviceID)
        }

        // Trigger the gate
        audioEngine?.triggerGate(channels: activeChannels)
    }
}
