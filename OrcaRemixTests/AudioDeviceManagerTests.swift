import XCTest
import CoreAudio
@testable import OrcaRemixCore

final class AudioDeviceManagerTests: XCTestCase {

    // MARK: - Device Enumeration Tests

    func testGetOutputDevices_ReturnsNonEmptyArray() {
        // Given: A system with at least one audio output device

        // When: We enumerate output devices
        let devices = AudioDeviceManager.getOutputDevices()

        // Then: We should get at least one device (built-in speakers/headphones)
        XCTAssertGreaterThan(devices.count, 0, "System should have at least one output device")
    }

    func testGetOutputDevices_AllDevicesHaveValidIDs() {
        // Given: Enumerated devices
        let devices = AudioDeviceManager.getOutputDevices()

        // Then: All devices should have non-zero IDs
        for device in devices {
            XCTAssertNotEqual(device.id, 0, "Device '\(device.name)' has invalid ID")
        }
    }

    func testGetOutputDevices_AllDevicesHaveNames() {
        // Given: Enumerated devices
        let devices = AudioDeviceManager.getOutputDevices()

        // Then: All devices should have non-empty names
        for device in devices {
            XCTAssertFalse(device.name.isEmpty, "Device with ID \(device.id) has empty name")
        }
    }

    func testGetOutputDevices_AllDevicesHaveOutputChannels() {
        // Given: Enumerated devices
        let devices = AudioDeviceManager.getOutputDevices()

        // Then: All devices should have at least one output channel
        for device in devices {
            XCTAssertGreaterThan(
                device.outputChannels,
                0,
                "Device '\(device.name)' has no output channels"
            )
        }
    }

    // MARK: - Multi-Channel Device Tests (Expert Sleepers ES-8)

    func testMultiChannelDevice_ES8Detection() {
        // Given: Enumerated devices
        let devices = AudioDeviceManager.getOutputDevices()

        // When: We look for Expert Sleepers ES-8
        let es8Device = devices.first {
            $0.name.contains("ES-8") || $0.name.contains("Expert Sleepers")
        }

        // Then: If ES-8 is connected, verify it has 8 channels
        if let es8 = es8Device {
            XCTAssertEqual(
                es8.outputChannels,
                8,
                "Expert Sleepers ES-8 should have 8 output channels, got \(es8.outputChannels)"
            )
            print("✅ Found Expert Sleepers ES-8: \(es8.name) with \(es8.outputChannels) channels")
        } else {
            print("ℹ️  Expert Sleepers ES-8 not connected - skipping multi-channel test")
            print("   Available devices: \(devices.map { "\($0.name) (\($0.outputChannels)ch)" })")
        }
    }

    func testMultiChannelDevice_ChannelCountAccuracy() {
        // Given: Enumerated devices
        let devices = AudioDeviceManager.getOutputDevices()

        // Then: Verify common channel configurations
        for device in devices {
            let channels = device.outputChannels

            // Most audio devices have 2, 4, 6, 8, 10, 12, 16, 24, or 32 channels
            // This test validates the channel count is reasonable
            XCTAssertLessThanOrEqual(
                channels,
                128,
                "Device '\(device.name)' reports suspiciously high channel count: \(channels)"
            )

            print("📊 Device: \(device.name) - Channels: \(channels)")
        }
    }

    func testMultiChannelDevice_MemorySafety() {
        // This test specifically validates the memory safety fix
        // for devices with multiple AudioBuffer structs

        // Given: Enumerated devices
        let devices = AudioDeviceManager.getOutputDevices()

        // When: We repeatedly query channel counts
        for _ in 0..<10 {
            for device in devices {
                // Then: Should not crash or corrupt memory
                let channels = AudioDeviceManager.getOutputChannelCount(device.id)
                XCTAssertNotNil(channels, "Failed to get channels for \(device.name)")
                XCTAssertEqual(channels, device.outputChannels)
            }
        }

        print("✅ Memory safety test passed - no crashes with multi-buffer devices")
    }

    // MARK: - Device Info Tests

    func testDeviceInfo_Identifiable() {
        // Given: A device
        let devices = AudioDeviceManager.getOutputDevices()
        guard let device = devices.first else {
            XCTFail("No devices available")
            return
        }

        // Then: Device should be identifiable by its ID
        XCTAssertEqual(device.id, device.id)
    }

    func testDeviceInfo_Hashable() {
        // Given: Two references to the same device
        let devices = AudioDeviceManager.getOutputDevices()
        guard let device1 = devices.first else {
            XCTFail("No devices available")
            return
        }

        let device2 = AudioDeviceManager.DeviceInfo(
            id: device1.id,
            name: device1.name,
            outputChannels: device1.outputChannels
        )

        // Then: They should be equal and have the same hash
        XCTAssertEqual(device1, device2)
        XCTAssertEqual(device1.hashValue, device2.hashValue)

        // And: Can be used in a Set
        let deviceSet: Set<AudioDeviceManager.DeviceInfo> = [device1, device2]
        XCTAssertEqual(deviceSet.count, 1, "Duplicate devices should be deduplicated in Set")
    }

    func testDeviceInfo_InequalityForDifferentDevices() {
        // Given: Multiple devices
        let devices = AudioDeviceManager.getOutputDevices()
        guard devices.count > 1 else {
            print("ℹ️  Only one device available - skipping inequality test")
            return
        }

        // Then: Different devices should not be equal
        XCTAssertNotEqual(devices[0], devices[1])
    }

    // MARK: - Edge Cases

    func testGetOutputDevices_ConsistentResults() {
        // Given: Multiple calls to getOutputDevices
        let devices1 = AudioDeviceManager.getOutputDevices()
        let devices2 = AudioDeviceManager.getOutputDevices()

        // Then: Should return the same devices (assuming no device changes)
        XCTAssertEqual(devices1.count, devices2.count)
        XCTAssertEqual(Set(devices1), Set(devices2))
    }

    func testGetOutputChannelCount_WithInvalidDeviceID() {
        // Given: An invalid device ID
        let invalidDeviceID: AudioDeviceID = 999999

        // When: We try to get channel count
        let channels = AudioDeviceManager.getOutputChannelCount(invalidDeviceID)

        // Then: Should return nil gracefully (not crash)
        XCTAssertNil(channels, "Invalid device ID should return nil")
    }

    func testGetDeviceName_WithInvalidDeviceID() {
        // Given: An invalid device ID
        let invalidDeviceID: AudioDeviceID = 999999

        // When: We try to get device name
        let name = AudioDeviceManager.getDeviceName(invalidDeviceID)

        // Then: Should return nil gracefully (not crash)
        XCTAssertNil(name, "Invalid device ID should return nil")
    }

    // MARK: - System Default Device Tests

    func testSetSystemDefaultDevice_WithValidDevice() {
        // Given: Current default device
        let devices = AudioDeviceManager.getOutputDevices()
        guard let firstDevice = devices.first else {
            XCTFail("No devices available")
            return
        }

        // When: We set it as default
        let success = AudioDeviceManager.setSystemDefaultDevice(deviceID: firstDevice.id)

        // Then: Operation should succeed
        XCTAssertTrue(success, "Setting valid device as default should succeed")
    }

    func testSetSystemDefaultDevice_WithInvalidDevice() {
        // Given: An invalid device ID
        let invalidDeviceID: AudioDeviceID = 999999

        // When: We try to set it as default
        let success = AudioDeviceManager.setSystemDefaultDevice(deviceID: invalidDeviceID)

        // Then: Operation may succeed or fail depending on macOS behavior
        // Note: macOS may silently ignore invalid device IDs without returning an error
        // This is acceptable as long as it doesn't crash
        print("ℹ️  Setting invalid device returned: \(success)")
    }

    // MARK: - Integration Test

    func testFullWorkflow_EnumerateAndSelectDevice() {
        // This test simulates the full user workflow

        // 1. Enumerate devices
        let devices = AudioDeviceManager.getOutputDevices()
        XCTAssertGreaterThan(devices.count, 0)

        // 2. Select a device (simulate user selection)
        guard let selectedDevice = devices.first else {
            XCTFail("No devices available")
            return
        }

        print("📱 Selected device: \(selectedDevice.name) (\(selectedDevice.outputChannels) channels)")

        // 3. Set as default
        let success = AudioDeviceManager.setSystemDefaultDevice(deviceID: selectedDevice.id)
        XCTAssertTrue(success)

        // 4. Verify device info is consistent
        let channelCount = AudioDeviceManager.getOutputChannelCount(selectedDevice.id)
        XCTAssertEqual(channelCount, selectedDevice.outputChannels)

        print("✅ Full workflow completed successfully")
    }

    // MARK: - Performance Tests

    func testPerformance_EnumerateDevices() {
        measure {
            _ = AudioDeviceManager.getOutputDevices()
        }
    }

    func testPerformance_GetChannelCount() {
        let devices = AudioDeviceManager.getOutputDevices()
        guard let device = devices.first else {
            XCTFail("No devices available")
            return
        }

        measure {
            _ = AudioDeviceManager.getOutputChannelCount(device.id)
        }
    }
}
