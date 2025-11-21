import SwiftUI

struct ChannelRoutingView: View {
    @ObservedObject var configManager: ChannelConfigurationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CHANNEL ROUTING")
                .font(.headline)
                .foregroundColor(.blue)

            // 8 channel rows
            VStack(spacing: 8) {
                ForEach($configManager.channels) { $channel in
                    HStack {
                        Text("Channel \(channel.id)")
                            .frame(width: 80, alignment: .leading)
                            .foregroundColor(.primary)

                        Picker("", selection: $channel.signal) {
                            ForEach(ChannelConfiguration.SignalType.allCases) { signalType in
                                Text(signalType.rawValue)
                                    .tag(signalType)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)

                        Spacer()

                        // Indicator for active gate channels
                        if channel.signal == .gate {
                            Image(systemName: "waveform")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Trigger button
            HStack {
                Button(action: {
                    configManager.triggerGate()
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Trigger Gate")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(gateChannelsCount > 0 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(gateChannelsCount == 0)

                if gateChannelsCount > 0 {
                    Text("\(gateChannelsCount) channel\(gateChannelsCount == 1 ? "" : "s")")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var gateChannelsCount: Int {
        configManager.gateChannels().count
    }
}

#Preview {
    ChannelRoutingView(configManager: ChannelConfigurationManager())
        .frame(width: 400)
}
