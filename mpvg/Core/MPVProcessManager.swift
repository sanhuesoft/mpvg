//
//  MPVProcessManager.swift
//  mpvg
//
//  Manages the mpv player subprocess with CoreAudio exclusive mode
//  and native POSIX socket IPC communication.
//

import Foundation
import Combine

@MainActor
final class MPVProcessManager: ObservableObject {
    private var process: Process?
    let socketPath = "/tmp/mpv_player.sock"
    private var pollTimer: Timer?
    
    private static let selectedDeviceKey = "MPVSelectedAudioDevice"
    private static let exclusiveModeKey = "MPVExclusiveMode"
    private static let physicalFormatKey = "MPVPhysicalFormat"
    private static let gaplessKey = "MPVGapless"
    
    @Published var isRunning = false
    @Published var currentDevice: String = "auto"
    @Published var availableDevices: [AudioDeviceInfo] = []
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
    
    init() {
        if let savedDevice = UserDefaults.standard.string(forKey: Self.selectedDeviceKey) {
            self.currentDevice = savedDevice
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
        detectAudioDevices()
    }
    
    deinit {
        pollTimer?.invalidate()
        process?.terminate()
        try? FileManager.default.removeItem(atPath: socketPath)
    }
    
    // MARK: - Binary Location
    func findMpvBinary() {
        let candidates = [
            "/opt/homebrew/bin/mpv",
            "/usr/local/bin/mpv",
            "/usr/bin/mpv"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                self.binaryPath = path
                return
            }
        }
    }
    
    // MARK: - Audio Device Detection
    func detectAudioDevices() {
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
                    AudioDeviceInfo(id: "auto", name: "Dispositivo Automático (Sistema)", driver: "auto", isExclusiveCapable: false)
                ]
                
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("'") else { continue }
                    
                    if let endQuote = trimmed.dropFirst().firstIndex(of: "'") {
                        let id = String(trimmed[trimmed.index(after: trimmed.startIndex)..<endQuote])
                        var name = id
                        
                        if let openParen = trimmed.firstIndex(of: "("),
                           let closeParen = trimmed.lastIndex(of: ")"),
                           openParen < closeParen {
                            name = String(trimmed[trimmed.index(after: openParen)..<closeParen])
                        }
                        
                        let isCoreAudio = id.hasPrefix("coreaudio/")
                        let isExclusive = isCoreAudio && id != "coreaudio/BuiltInSpeakerDevice"
                        
                        // Avoid duplicates
                        if !devices.contains(where: { $0.id == id }) {
                            devices.append(AudioDeviceInfo(
                                id: id,
                                name: name,
                                driver: isCoreAudio ? "coreaudio" : "avfoundation",
                                isExclusiveCapable: isExclusive
                            ))
                        }
                    }
                }
                
                self.availableDevices = devices
                
                // If saved device is in list, keep it. Otherwise pick default.
                if let saved = UserDefaults.standard.string(forKey: Self.selectedDeviceKey),
                   devices.contains(where: { $0.id == saved }) {
                    self.currentDevice = saved
                } else if self.currentDevice == "auto",
                          let firstCoreAudio = devices.first(where: { $0.id.hasPrefix("coreaudio/") && $0.id != "coreaudio/BuiltInSpeakerDevice" }) {
                    self.currentDevice = firstCoreAudio.id
                    UserDefaults.standard.set(firstCoreAudio.id, forKey: Self.selectedDeviceKey)
                }
            }
        } catch {
            print("Error detectando dispositivos de audio: \(error)")
        }
    }
    
    // MARK: - Process Management
    func start() {
        guard process == nil || !(process?.isRunning ?? false) else { return }
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            print("mpv no encontrado en \(binaryPath)")
            return
        }
        
        try? FileManager.default.removeItem(atPath: socketPath)
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        
        var args = [
            "--idle=yes",
            "--input-ipc-server=\(socketPath)",
            "--no-video",
            "--keep-open=always",
            "--volume-max=100"
        ]
        
        if currentDevice != "auto" {
            args.append("--audio-device=\(currentDevice)")
        }
        if isExclusive {
            args.append("--audio-exclusive=yes")
        }
        if changePhysicalFormat {
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
            print("Error iniciando mpv: \(error.localizedDescription)")
            self.isRunning = false
        }
    }
    
    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        process?.terminate()
        process = nil
        self.isRunning = false
        try? FileManager.default.removeItem(atPath: socketPath)
    }
    
    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.start()
        }
    }
    
    // MARK: - Playback Commands
    func play(url: String) {
        if !isRunning {
            start()
        }
        self.isPaused = false
        self.objectWillChange.send()
        
        sendCommand(["loadfile", url, "replace"])
        sendCommand(["set_property", "pause", false])
    }
    
    func togglePause() {
        let targetState = !isPaused
        self.isPaused = targetState
        self.objectWillChange.send()
        
        sendCommand(["set_property", "pause", targetState])
    }
    
    func resume() {
        self.isPaused = false
        self.objectWillChange.send()
        sendCommand(["set_property", "pause", false])
    }
    
    func pause() {
        self.isPaused = true
        self.objectWillChange.send()
        sendCommand(["set_property", "pause", true])
    }
    
    func seek(to seconds: Double) {
        currentTime = seconds
        self.objectWillChange.send()
        sendCommand(["seek", seconds, "absolute"])
    }
    
    func setVolume(_ newVolume: Double) {
        let clamped = max(0.0, min(100.0, newVolume))
        self.volume = clamped
        self.objectWillChange.send()
        sendCommand(["set_property", "volume", clamped])
    }
    
    func setDevice(_ deviceId: String) {
        self.currentDevice = deviceId
        UserDefaults.standard.set(deviceId, forKey: Self.selectedDeviceKey)
        self.objectWillChange.send()
        
        if isRunning {
            sendCommand(["set_property", "audio-device", deviceId])
            // If exclusive mode is enabled, restarting mpv guarantees clean CoreAudio Hog Mode attachment
            if isExclusive {
                restart()
            }
        }
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
        }
        if let dur = await queryProperty("duration") as? Double {
            if abs(self.duration - dur) > 0.5 {
                self.duration = dur
                changed = true
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