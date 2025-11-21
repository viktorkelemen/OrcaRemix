import Foundation

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

    init() {
        // Initialize 8 channels, all set to None
        self.channels = (1...8).map { channelNumber in
            ChannelConfiguration(id: channelNumber, signal: .none)
        }
    }

    /// Get channels that have Gate signal configured
    func gateChannels() -> [Int] {
        return channels
            .filter { $0.signal == .gate }
            .map { $0.id }
    }

    /// Trigger gate signal to configured channels
    func triggerGate() {
        let activeChannels = gateChannels()
        guard !activeChannels.isEmpty else {
            print("⚠️  No channels configured for Gate signal")
            return
        }

        print("🎵 Triggering Gate on channels: \(activeChannels)")
        // TODO: Send actual gate signal to audio device
    }
}
