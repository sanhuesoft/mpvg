//
//  MPVProcessManager.swift
//  mpvg
//
//  Manages the mpv player subprocess with CoreAudio exclusive mode,
//  dynamic USB DAC hotplug detection, and reliable socket IPC.
//

#if os(macOS)
import Foundation
import Combine
import CoreAudio
import AppKit
import AVFoundation

@MainActor
final class MPVProcessManager: ObservableObject {
    private var process: Process?
    let socketPath = "/tmp/mpv_player.sock"
    private var pollTimer: Timer?
    
    // Native fallback engine (AVFoundation) when mpv binary cannot be executed (e.g. App Sandbox)
    @Published var isUsingNativeEngine = false
    private var nativePlayer: AVPlayer?
    private var nativeTimeObserverToken: Any?
    private var nativeItemStatusObserver: AnyCancellable?
    private var nativeEndObserverToken: Any?
    private var nativeErrorObserverToken: Any?
    private var hoggedDeviceID: AudioDeviceID? = nil
    
    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
    
    private static let selectedDeviceKey = "MPVSelectedAudioDevice"
    private static let selectedDeviceNameKey = "MPVSelectedAudioDeviceName"
    private static let exclusiveModeKey = "MPVExclusiveMode"
    private static let physicalFormatKey = "MPVPhysicalFormat"
    private static let gaplessKey = "MPVGapless"
    
    @Published var isRunning = false
    @Published var currentDevice: String = "auto"
    @Published var preferredDeviceName: String = ""
    @Published var availableDevices: [AudioDeviceInfo] = []
    @Published var isDeviceConnected: Bool = true
    @Published var deviceWarning: String? = nil
    
    @Published var isExclusive: Bool = true
    @Published var changePhysicalFormat: Bool = true
    @Published var isGapless: Bool = true
    
    @Published var isPaused: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var volume: Double = 100.0
    
    @Published var audioSampleRate: Int? = nil
    @Published var audioFormat: String? = nil
    @Published var audioChannels: String? = nil
    @Published var binaryPath: String = "/opt/homebrew/bin/mpv"
    
    var onTrackFinished: (() -> Void)?
    var onPlaybackError: ((Error?) -> Void)?
    private var hasHandledEOF: Bool = false
    private var isAwaitingPlayback: Bool = false
    private var playbackStartTimer: Task<Void, Never>?
    
    init() {
        if let savedDevice = UserDefaults.standard.string(forKey: Self.selectedDeviceKey) {
            self.currentDevice = savedDevice
        }
        if let savedName = UserDefaults.standard.string(forKey: Self.selectedDeviceNameKey) {
            self.preferredDeviceName = savedName
        }
        if UserDefaults.standard.object(forKey: Self.exclusiveModeKey) != nil {
            self.isExclusive = UserDefaults.standard.bool(forKey: Self.exclusiveModeKey)
        }
        if UserDefaults.standard.object(forKey: Self.physicalFormatKey) != nil {
            self.changePhysicalFormat = UserDefaults.standard.bool(forKey: Self.physicalFormatKey)
        }
        if UserDefaults.standard.object(forKey: Self.gaplessKey) != nil {
            self.isGapless = UserDefaults.standard.bool(forKey: Self.gaplessKey)
        }
        
        findMpvBinary()
        Self.killStaleMpvProcesses()
        detectAudioDevices()
        setupCoreAudioListener()
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }
    
    deinit {
        pollTimer?.invalidate()
        if let token = nativeTimeObserverToken {
            nativePlayer?.removeTimeObserver(token)
        }
        if let token = nativeEndObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = nativeErrorObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
        nativeItemStatusObserver?.cancel()
        nativePlayer?.pause()
        if let hogged = hoggedDeviceID {
            Self.setHogMode(for: hogged, enable: false)
        }
        if let proc = process, proc.isRunning {
            let pid = proc.processIdentifier
            proc.terminate()
            if kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
            }
        }
        Self.killStaleMpvProcesses()
        try? FileManager.default.removeItem(atPath: socketPath)
    }
    
    private func cleanupNativeObservers() {
        if let token = nativeTimeObserverToken {
            nativePlayer?.removeTimeObserver(token)
            nativeTimeObserverToken = nil
        }
        if let token = nativeEndObserverToken {
            NotificationCenter.default.removeObserver(token)
            nativeEndObserverToken = nil
        }
        if let token = nativeErrorObserverToken {
            NotificationCenter.default.removeObserver(token)
            nativeErrorObserverToken = nil
        }
        nativeItemStatusObserver?.cancel()
        nativeItemStatusObserver = nil
    }
    
    nonisolated static func killStaleMpvProcesses() {
        guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil else { return }
        // 1. Kill any mpv associated with our IPC socket
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-9", "-f", "mpv_player.sock"]
        try? pkill.run()
        pkill.waitUntilExit()
        
        // 2. Kill all mpv instances on system to completely disengage CoreAudio exclusive hog mode
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["-9", "mpv"]
        try? killall.run()
        killall.waitUntilExit()
    }
    
    // MARK: - CoreAudio Hotplug Listener
    private func setupCoreAudioListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleDeviceListChange()
            }
        }
    }
    
    private func handleDeviceListChange() {
        let previousDevice = currentDevice
        detectAudioDevices()
        
        // If device changed or preferred DAC was plugged in, restart mpv
        if currentDevice != previousDevice {
            restart()
        }
    }
    
    // MARK: - Binary Location
    func findMpvBinary() {
        if Self.isSandboxed {
            self.isUsingNativeEngine = true
            self.binaryPath = "Apple CoreAudio / AVFoundation (Native)"
            return
        }
        let candidates = [
            "/opt/homebrew/bin/mpv",
            "/usr/local/bin/mpv",
            "/usr/bin/mpv"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                self.binaryPath = path
                self.isUsingNativeEngine = false
                return
            }
        }
        self.isUsingNativeEngine = true
        self.binaryPath = "Apple CoreAudio / AVFoundation (Native)"
    }
    
    // MARK: - Native CoreAudio HAL Helpers
    static func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var devID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devID) == noErr {
            return devID
        }
        return nil
    }
    
    static func audioDeviceID(for uid: String) -> AudioDeviceID? {
        var propSize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize) == noErr else { return nil }
        let count = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize, &deviceIDs) == noErr else { return nil }
        
        for devID in deviceIDs {
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var unmanagedUID: Unmanaged<CFString>?
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            if AudioObjectGetPropertyData(devID, &uidAddr, 0, nil, &size, &unmanagedUID) == noErr,
               let cf = unmanagedUID?.takeRetainedValue() as String?,
               cf == uid {
                return devID
            }
        }
        return nil
    }
    
    static func nominalSampleRate(for deviceID: AudioDeviceID) -> Int? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate) == noErr, rate > 0 {
            return Int(rate)
        }
        return nil
    }
    
    nonisolated static func setHogMode(for deviceID: AudioDeviceID, enable: Bool) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyHogMode,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = enable ? getpid() : -1
        let size = UInt32(MemoryLayout<pid_t>.size)
        _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &pid)
    }
    
    static func detectAudioDevicesViaCoreAudio() -> [AudioDeviceInfo] {
        var propSize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize) == noErr, propSize > 0 else {
            return [
                AudioDeviceInfo(id: "auto", name: "Default System Device", driver: "CoreAudio", isExclusiveCapable: false)
            ]
        }
        
        let count = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize, &deviceIDs) == noErr else {
            return [
                AudioDeviceInfo(id: "auto", name: "Default System Device", driver: "CoreAudio", isExclusiveCapable: false)
            ]
        }
        
        var devices: [AudioDeviceInfo] = [
            AudioDeviceInfo(id: "auto", name: "Default System Device", driver: "auto", isExclusiveCapable: false)
        ]
        
        for devID in deviceIDs {
            // Check if device has output streams
            var streamSize: UInt32 = 0
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyDataSize(devID, &streamAddr, 0, nil, &streamSize) == noErr, streamSize > 0 else { continue }
            
            // Get Device Name
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var unmanagedName: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let nameStatus = AudioObjectGetPropertyData(devID, &nameAddr, 0, nil, &nameSize, &unmanagedName)
            let devName = (nameStatus == noErr && unmanagedName != nil) ? (unmanagedName!.takeRetainedValue() as String) : "Audio Device"
            
            // Get Device UID
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var unmanagedUID: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(devID, &uidAddr, 0, nil, &uidSize, &unmanagedUID) == noErr,
                  let devUID = unmanagedUID?.takeRetainedValue() as String? else { continue }
            
            // Check Transport Type
            var transportType: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            var transportAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectGetPropertyData(devID, &transportAddr, 0, nil, &transportSize, &transportType)
            
            let isUSB = (transportType == kAudioDeviceTransportTypeUSB)
            let isBuiltIn = devUID.contains("BuiltInSpeakerDevice")
            let isExclusive = isUSB || (!isBuiltIn && !devUID.contains("BuiltIn"))
            
            devices.append(AudioDeviceInfo(
                id: devUID,
                name: devName,
                driver: "CoreAudio",
                isExclusiveCapable: isExclusive
            ))
        }
        
        return devices
    }
    
    // MARK: - Audio Device Detection & Resolution
    func detectAudioDevices() {
        if isUsingNativeEngine || Self.isSandboxed || !FileManager.default.fileExists(atPath: binaryPath) {
            let devices = Self.detectAudioDevicesViaCoreAudio()
            self.availableDevices = devices
            resolveActiveDevice(from: devices)
            applyNativeDeviceRouting()
            return
        }
        guard FileManager.default.fileExists(atPath: binaryPath) else { return }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["--audio-device=help"]
        
        let pipe = Pipe()
        proc.standardOutput = pipe
        
        do {
            try proc.run()
            proc.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var devices: [AudioDeviceInfo] = [
                    AudioDeviceInfo(id: "auto", name: "Default System Device", driver: "auto", isExclusiveCapable: false)
                ]
                
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("'") else { continue }
                    
                    if let endQuote = trimmed.dropFirst().firstIndex(of: "'") {
                        let id = String(trimmed[trimmed.index(after: trimmed.startIndex)..<endQuote])
                        guard id != "auto" else { continue }
                        
                        var name = id
                        if let openParen = trimmed.firstIndex(of: "("),
                           let closeParen = trimmed.lastIndex(of: ")"),
                           openParen < closeParen {
                            name = String(trimmed[trimmed.index(after: openParen)..<closeParen])
                        }
                        
                        let isCoreAudio = id.hasPrefix("coreaudio/")
                        let isAVFoundation = id.hasPrefix("avfoundation/")
                        let driver = isCoreAudio ? "coreaudio" : (isAVFoundation ? "avfoundation" : "other")
                        let isExclusive = isCoreAudio && !id.contains("BuiltInSpeakerDevice")
                        
                        if !devices.contains(where: { $0.id == id }) {
                            devices.append(AudioDeviceInfo(
                                id: id,
                                name: name,
                                driver: driver,
                                isExclusiveCapable: isExclusive
                            ))
                        }
                    }
                }
                
                self.availableDevices = devices
                resolveActiveDevice(from: devices)
            }
        } catch {
            print("Error detecting audio devices: \(error)")
        }
    }
    
    private func resolveActiveDevice(from devices: [AudioDeviceInfo]) {
        // 1. If user previously selected a specific device ID that is currently connected, respect it!
        if let savedId = UserDefaults.standard.string(forKey: Self.selectedDeviceKey),
           savedId != "auto",
           let exactMatch = devices.first(where: { $0.id == savedId }) {
            self.currentDevice = exactMatch.id
            self.preferredDeviceName = exactMatch.name
            self.isDeviceConnected = true
            self.deviceWarning = nil
            return
        }
        
        // 2. If user had a preferred device name (e.g. "HiBy FC1") and it reconnected:
        if !preferredDeviceName.isEmpty {
            if let nameMatch = devices.first(where: {
                $0.id.hasPrefix("coreaudio/") &&
                ($0.name.localizedCaseInsensitiveContains(preferredDeviceName) ||
                 preferredDeviceName.localizedCaseInsensitiveContains($0.name))
            }) ?? devices.first(where: {
                $0.name.localizedCaseInsensitiveContains(preferredDeviceName) ||
                preferredDeviceName.localizedCaseInsensitiveContains($0.name)
            }) {
                self.currentDevice = nameMatch.id
                self.preferredDeviceName = nameMatch.name
                self.isDeviceConnected = true
                self.deviceWarning = nil
                UserDefaults.standard.set(nameMatch.id, forKey: Self.selectedDeviceKey)
                return
            }
        }
        
        // 3. Auto-detect if an external USB DAC is connected (prefer CoreAudio driver)
        let isDAC = { (dev: AudioDeviceInfo) -> Bool in
            let lower = dev.name.lowercased()
            let idLower = dev.id.lowercased()
            return lower.contains("dac") ||
                   lower.contains("hiby") ||
                   lower.contains("fc1") ||
                   lower.contains("fiio") ||
                   lower.contains("ifi") ||
                   lower.contains("dragonfly") ||
                   lower.contains("qudelix") ||
                   lower.contains("topping") ||
                   lower.contains("smsl") ||
                   lower.contains("schiit") ||
                   lower.contains("moondrop") ||
                   idLower.contains("appleusbaudioengine")
        }
        
        if let dac = devices.first(where: { $0.id.hasPrefix("coreaudio/") && isDAC($0) }) ??
                     devices.first(where: { isDAC($0) }) {
            self.currentDevice = dac.id
            self.preferredDeviceName = dac.name
            self.isExclusive = true
            self.changePhysicalFormat = true
            self.isDeviceConnected = true
            self.deviceWarning = nil
            UserDefaults.standard.set(dac.id, forKey: Self.selectedDeviceKey)
            UserDefaults.standard.set(dac.name, forKey: Self.selectedDeviceNameKey)
            UserDefaults.standard.set(true, forKey: Self.exclusiveModeKey)
            UserDefaults.standard.set(true, forKey: Self.physicalFormatKey)
            return
        }
        
        // 4. Default to system output in shared mode if no DAC is selected
        if currentDevice.isEmpty || !devices.contains(where: { $0.id == currentDevice }) {
            self.currentDevice = "auto"
            self.isExclusive = false
            self.isDeviceConnected = true
            self.deviceWarning = nil
        }
    }
    
    // MARK: - Process Management
    func start() {
        if isUsingNativeEngine || Self.isSandboxed || !FileManager.default.fileExists(atPath: binaryPath) {
            setupNativeEngine()
            return
        }
        
        guard process == nil || !(process?.isRunning ?? false) else { return }
        
        Self.killStaleMpvProcesses()
        try? FileManager.default.removeItem(atPath: socketPath)
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        
        var args = [
            "--idle=yes",
            "--input-ipc-server=\(socketPath)",
            "--no-video",
            "--keep-open=always",
            "--volume-max=100",
            "--audio-samplerate=0"
        ]
        
        // Only force device if it is ACTUALLY present right now in the detected list
        let effectiveDevice = (isDeviceConnected && currentDevice != "auto") ? currentDevice : "auto"
        if effectiveDevice != "auto" {
            args.append("--audio-device=\(effectiveDevice)")
        } else {
            args.append("--audio-device=auto")
        }
        
        if isExclusive && (effectiveDevice.hasPrefix("coreaudio/") || effectiveDevice == "auto") {
            args.append("--audio-exclusive=yes")
        }
        if changePhysicalFormat && (effectiveDevice.hasPrefix("coreaudio/") || effectiveDevice == "auto") {
            args.append("--coreaudio-change-physical-format=yes")
        }
        if isGapless {
            args.append("--gapless-audio=yes")
        }
        
        proc.arguments = args
        
        do {
            try proc.run()
            self.process = proc
            self.isRunning = true
            startPolling()
        } catch {
            print("mpv subprocess failed to launch: \(error.localizedDescription). Falling back to native AVPlayer engine.")
            self.isUsingNativeEngine = true
            setupNativeEngine()
        }
    }
    
    private func setupNativeEngine() {
        self.isRunning = true
        self.binaryPath = "Apple CoreAudio / AVFoundation (Native)"
        if nativePlayer == nil {
            nativePlayer = AVPlayer()
            nativePlayer?.automaticallyWaitsToMinimizeStalling = true
            nativePlayer?.volume = Float(volume / 100.0)
        }
        applyNativeDeviceRouting()
    }
    
    private func applyNativeDeviceRouting() {
        guard isUsingNativeEngine else { return }
        
        let targetUID: String? = (currentDevice != "auto" && isDeviceConnected) ? currentDevice : nil
        nativePlayer?.audioOutputDeviceUniqueID = targetUID
        
        if let uid = targetUID, let devID = Self.audioDeviceID(for: uid) {
            if let rate = Self.nominalSampleRate(for: devID) {
                self.audioSampleRate = rate
            }
            if isExclusive {
                Self.setHogMode(for: devID, enable: true)
                hoggedDeviceID = devID
            } else if hoggedDeviceID == devID {
                Self.setHogMode(for: devID, enable: false)
                hoggedDeviceID = nil
            }
        } else {
            if let hogged = hoggedDeviceID {
                Self.setHogMode(for: hogged, enable: false)
                hoggedDeviceID = nil
            }
            if let defaultID = Self.defaultOutputDeviceID(), let rate = Self.nominalSampleRate(for: defaultID) {
                self.audioSampleRate = rate
            }
        }
    }
    
    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        
        if isUsingNativeEngine {
            nativePlayer?.pause()
            cleanupNativeObservers()
            if let hogged = hoggedDeviceID {
                Self.setHogMode(for: hogged, enable: false)
                hoggedDeviceID = nil
            }
            self.isRunning = false
            self.isPaused = true
            self.currentTime = 0.0
            self.duration = 0.0
            self.objectWillChange.send()
            return
        }
        
        if let proc = process, proc.isRunning {
            let pid = proc.processIdentifier
            sendCommand(["quit"])
            proc.terminate()
            if kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
            }
            proc.waitUntilExit()
        }
        
        // Kill any lingering or orphaned mpv processes completely
        Self.killStaleMpvProcesses()
        
        process = nil
        self.isRunning = false
        try? FileManager.default.removeItem(atPath: socketPath)
    }
    
    func restart() {
        if isUsingNativeEngine {
            applyNativeDeviceRouting()
            return
        }
        stop()
        // Wait 400ms for macOS coreaudiod to completely release exclusive hog mode lock
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms
            self.detectAudioDevices()
            self.start()
        }
    }
    
    // MARK: - Playback Commands
    func play(url: String) {
        if isUsingNativeEngine {
            playNative(url: url)
            return
        }
        
        // Ensure process and socket are ready before sending loadfile
        if !isRunning || !FileManager.default.fileExists(atPath: socketPath) {
            start()
            if isUsingNativeEngine {
                playNative(url: url)
                return
            }
            Task {
                for _ in 0..<25 {
                    if FileManager.default.fileExists(atPath: self.socketPath) {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
                }
                if !FileManager.default.fileExists(atPath: self.socketPath) {
                    print("Socket failed to open. Falling back to native player.")
                    self.isUsingNativeEngine = true
                    self.playNative(url: url)
                    return
                }
                self.isPaused = false
                self.isAwaitingPlayback = true
                self.objectWillChange.send()
                self.sendCommand(["loadfile", url, "replace"])
                self.sendCommand(["set_property", "pause", false])
                self.schedulePlaybackTimeoutCheck(for: url)
            }
            return
        }
        
        hasHandledEOF = false
        isAwaitingPlayback = true
        self.isPaused = false
        self.objectWillChange.send()
        
        sendCommand(["loadfile", url, "replace"])
        sendCommand(["set_property", "pause", false])
        schedulePlaybackTimeoutCheck(for: url)
    }
    
    private func playNative(url: String) {
        setupNativeEngine()
        cleanupNativeObservers()
        
        playbackStartTimer?.cancel()
        playbackStartTimer = nil
        hasHandledEOF = false
        isAwaitingPlayback = true
        
        let streamURL: URL
        if url.hasPrefix("/") {
            streamURL = URL(fileURLWithPath: url)
        } else if let parsed = URL(string: url) {
            streamURL = parsed
        } else {
            onPlaybackError?(nil)
            return
        }
        
        let item = AVPlayerItem(url: streamURL)
        
        nativeEndObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onTrackFinished?()
            }
        }
        
        nativeErrorObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notif in
            let error = notif.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in
                self?.isAwaitingPlayback = false
                self?.onPlaybackError?(error)
            }
        }
        
        nativeItemStatusObserver = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .readyToPlay {
                    self.isPaused = false
                    self.isAwaitingPlayback = false
                    let dur = item.duration.seconds
                    if !dur.isNaN && dur > 0 {
                        self.duration = dur
                    }
                    self.objectWillChange.send()
                } else if status == .failed {
                    self.isAwaitingPlayback = false
                    self.onPlaybackError?(item.error)
                }
            }
        
        if nativePlayer == nil {
            nativePlayer = AVPlayer(playerItem: item)
        } else {
            nativePlayer?.replaceCurrentItem(with: item)
        }
        applyNativeDeviceRouting()
        
        nativePlayer?.automaticallyWaitsToMinimizeStalling = true
        nativePlayer?.volume = Float(volume / 100.0)
        nativePlayer?.play()
        
        self.isPaused = false
        self.isRunning = true
        self.objectWillChange.send()
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        nativeTimeObserverToken = nativePlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let s = time.seconds
                if !s.isNaN && s >= 0 {
                    self.currentTime = s
                }
                if let curItem = self.nativePlayer?.currentItem {
                    let d = curItem.duration.seconds
                    if !d.isNaN && d > 0 {
                        self.duration = d
                    }
                }
            }
        }
    }
    
    private func schedulePlaybackTimeoutCheck(for url: String) {
        playbackStartTimer?.cancel()
        guard url.hasPrefix("http://") || url.hasPrefix("https://") else { return }
        playbackStartTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds
            guard let self = self, !Task.isCancelled else { return }
            if self.isAwaitingPlayback && self.currentTime == 0.0 && self.duration == 0.0 {
                self.isAwaitingPlayback = false
                self.onPlaybackError?(nil)
            }
        }
    }
    
    func togglePause() {
        let targetState = !isPaused
        self.isPaused = targetState
        self.objectWillChange.send()
        
        if isUsingNativeEngine {
            if targetState {
                nativePlayer?.pause()
            } else {
                nativePlayer?.play()
            }
            return
        }
        
        sendCommand(["set_property", "pause", targetState])
    }
    
    func resume() {
        self.isPaused = false
        self.objectWillChange.send()
        if isUsingNativeEngine {
            nativePlayer?.play()
            return
        }
        sendCommand(["set_property", "pause", false])
    }
    
    func pause() {
        self.isPaused = true
        self.objectWillChange.send()
        if isUsingNativeEngine {
            nativePlayer?.pause()
            return
        }
        sendCommand(["set_property", "pause", true])
    }
    
    func seek(to seconds: Double) {
        currentTime = seconds
        self.objectWillChange.send()
        if isUsingNativeEngine {
            nativePlayer?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
            return
        }
        sendCommand(["seek", seconds, "absolute"])
    }
    
    func setVolume(_ newVolume: Double) {
        let clamped = max(0.0, min(100.0, newVolume))
        self.volume = clamped
        self.objectWillChange.send()
        if isUsingNativeEngine {
            nativePlayer?.volume = Float(clamped / 100.0)
            return
        }
        sendCommand(["set_property", "volume", clamped])
    }
    
    func setDevice(_ deviceId: String) {
        self.currentDevice = deviceId
        if let dev = availableDevices.first(where: { $0.id == deviceId }) {
            self.preferredDeviceName = dev.name
            UserDefaults.standard.set(dev.name, forKey: Self.selectedDeviceNameKey)
            if dev.isExclusiveCapable {
                self.isExclusive = true
                self.changePhysicalFormat = true
                UserDefaults.standard.set(true, forKey: Self.exclusiveModeKey)
                UserDefaults.standard.set(true, forKey: Self.physicalFormatKey)
            } else if dev.id.contains("BuiltInSpeakerDevice") || dev.id == "auto" {
                self.isExclusive = false
                UserDefaults.standard.set(false, forKey: Self.exclusiveModeKey)
            }
        }
        UserDefaults.standard.set(deviceId, forKey: Self.selectedDeviceKey)
        self.isDeviceConnected = true
        self.deviceWarning = nil
        self.objectWillChange.send()
        
        restart()
    }
    
    func toggleExclusive() {
        isExclusive.toggle()
        UserDefaults.standard.set(isExclusive, forKey: Self.exclusiveModeKey)
        self.objectWillChange.send()
        restart()
    }
    
    func togglePhysicalFormat() {
        changePhysicalFormat.toggle()
        UserDefaults.standard.set(changePhysicalFormat, forKey: Self.physicalFormatKey)
        self.objectWillChange.send()
        restart()
    }
    
    func toggleGapless() {
        isGapless.toggle()
        UserDefaults.standard.set(isGapless, forKey: Self.gaplessKey)
        self.objectWillChange.send()
    }
    
    // MARK: - Native IPC Communication
    func sendCommand(_ args: [Any]) {
        guard FileManager.default.fileExists(atPath: socketPath) else { return }
        DispatchQueue.global(qos: .userInteractive).async { [socketPath] in
            _ = SocketClient.send(socketPath: socketPath, jsonObject: ["command": args], timeoutMs: 150)
        }
    }
    
    private func queryProperty(_ prop: String) async -> Any? {
        guard FileManager.default.fileExists(atPath: socketPath) else { return nil }
        let res = await SocketClient.sendAsync(socketPath: socketPath, jsonObject: ["command": ["get_property", prop]], timeoutMs: 150)
        if let error = res?["error"] as? String, error == "success" {
            return res?["data"]
        }
        return nil
    }
    
    // MARK: - Playback State Polling
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updatePlaybackState()
            }
        }
    }
    
    private func updatePlaybackState() async {
        guard isRunning else { return }
        
        var changed = false
        
        if let time = await queryProperty("time-pos") as? Double {
            if abs(self.currentTime - time) > 0.1 {
                self.currentTime = time
                changed = true
            }
            if time > 0.5 && self.isAwaitingPlayback {
                self.isAwaitingPlayback = false
                self.playbackStartTimer?.cancel()
            }
        }
        if let dur = await queryProperty("duration") as? Double {
            if abs(self.duration - dur) > 0.5 {
                self.duration = dur
                changed = true
            }
            if dur > 0.5 && self.isAwaitingPlayback {
                self.isAwaitingPlayback = false
                self.playbackStartTimer?.cancel()
            }
        }
        if let eof = await queryProperty("eof-reached") as? Bool {
            if eof && !self.hasHandledEOF && !self.isPaused {
                if self.duration > 0 && self.currentTime > 1.0 {
                    self.hasHandledEOF = true
                    self.onTrackFinished?()
                } else if self.isAwaitingPlayback {
                    self.hasHandledEOF = true
                    self.isAwaitingPlayback = false
                    self.playbackStartTimer?.cancel()
                    self.onPlaybackError?(nil)
                }
            } else if !eof {
                self.hasHandledEOF = false
            }
        }
        if let paused = await queryProperty("pause") as? Bool {
            if self.isPaused != paused {
                self.isPaused = paused
                changed = true
            }
        }
        if let vol = await queryProperty("volume") as? Double {
            if abs(self.volume - vol) > 0.5 {
                self.volume = vol
                changed = true
            }
        }
        if let params = await queryProperty("audio-params") as? [String: Any] {
            if let rate = params["samplerate"] as? Int, self.audioSampleRate != rate {
                self.audioSampleRate = rate
                changed = true
            }
            if let format = params["format"] as? String, self.audioFormat != format {
                self.audioFormat = format
                changed = true
            }
            if let channels = params["channels"] as? String, self.audioChannels != channels {
                self.audioChannels = channels
                changed = true
            }
        }
        
        if changed {
            self.objectWillChange.send()
        }
    }
}
#endif