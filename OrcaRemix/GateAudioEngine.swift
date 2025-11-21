import Foundation
import AVFoundation

/// Manages audio output for gate signals
class GateAudioEngine {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var format: AVAudioFormat?

    /// Initialize the audio engine with a specific device
    func setup(deviceID: AudioDeviceID?) throws {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let engine = audioEngine, let player = playerNode else {
            throw GateAudioError.engineInitFailed
        }

        // Attach player node
        engine.attach(player)

        // Get output node
        let outputNode = engine.outputNode

        // Set device if specified
        if let deviceID = deviceID {
            try setOutputDevice(deviceID: deviceID)
        }

        // Create format matching output
        let outputFormat = outputNode.outputFormat(forBus: 0)
        format = AVAudioFormat(
            standardFormatWithSampleRate: outputFormat.sampleRate,
            channels: outputFormat.channelCount
        )

        // Connect player to output
        if let format = format {
            engine.connect(player, to: outputNode, format: format)
        }

        // Start engine
        try engine.start()
        player.play()

        print("🎛️ Audio engine started: \(outputFormat.sampleRate)Hz, \(outputFormat.channelCount) channels")
    }

    /// Set the audio output device
    private func setOutputDevice(deviceID: AudioDeviceID) throws {
        guard let engine = audioEngine else { return }

        // Get the Audio Unit from the output node
        let outputNode = engine.outputNode
        guard let audioUnit = outputNode.audioUnit else {
            print("⚠️ Failed to get audio unit from output node")
            return
        }

        // Set the device
        var deviceIDCopy = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDCopy,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            print("⚠️ Failed to set output device: \(status)")
        }
    }

    /// Trigger a gate signal on specified channels (Make Noise compatible)
    func triggerGate(channels: [Int]) {
        guard let player = playerNode, let format = format else {
            print("⚠️ Audio engine not initialized")
            return
        }

        let sampleRate = format.sampleRate
        let duration: TimeInterval = 0.01  // 10ms gate pulse
        let frameCount = AVAudioFrameCount(duration * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("⚠️ Failed to create audio buffer")
            return
        }

        buffer.frameLength = frameCount

        // Generate gate signal compatible with Make Noise and Expert Sleepers
        // Gate HIGH = 0.8 (not 1.0) per Make Noise/modular standards
        if let channelData = buffer.floatChannelData {
            let channelCount = Int(format.channelCount)

            for frame in 0..<Int(frameCount) {
                for channel in 0..<channelCount {
                    // Channel numbers are 1-based, array is 0-based
                    if channels.contains(channel + 1) {
                        // Gate HIGH = 0.8 (Make Noise compatible)
                        channelData[channel][frame] = 0.8
                    } else {
                        // Gate LOW (0V)
                        channelData[channel][frame] = 0.0
                    }
                }
            }
        }

        // Schedule and play the buffer
        player.scheduleBuffer(buffer, completionHandler: nil)

        print("🎵 Gate triggered on channels: \(channels) (10ms @ 0.8V)")
    }

    /// Stop the audio engine
    func stop() {
        playerNode?.stop()
        audioEngine?.stop()
        print("🛑 Audio engine stopped")
    }

    enum GateAudioError: Error {
        case engineInitFailed
        case deviceNotFound
    }
}
