//
//  IOSAudioEngine.swift
//  mpvg
//
//  Native iOS audio engine utilizing AVPlayer and AVAudioSession.
//  Optimized for bit-perfect audiophile playback with external USB DACs (e.g. HiBy FC1),
//  background audio playback, and dynamic route change detection.
//

#if os(iOS)
import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class IOSAudioEngine: ObservableObject {
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var itemStatusObserver: AnyCancellable?
    private var endObserverToken: Any?
    var onTrackFinished: (() -> Void)?
    
    @Published var isRunning = true
    @Published var isPaused = true
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var volume: Double = 100.0
    
    @Published var currentDevice: String = "iPhone Speaker"
    @Published var preferredDeviceName: String = ""
    @Published var availableDevices: [AudioDeviceInfo] = []
    @Published var isDeviceConnected: Bool = true
    @Published var deviceWarning: String? = nil
    
    @Published var isExclusive: Bool = false // Represents Bit-Perfect Hi-Res DAC mode on iOS
    @Published var changePhysicalFormat: Bool = true
    @Published var isGapless: Bool = true
    
    @Published var audioSampleRate: Int? = nil
    @Published var audioFormat: String? = "FLAC"
    @Published var audioChannels: String? = "Stereo"
    @Published var binaryPath: String = "iOS CoreAudio / AVFoundation (Native)"
    
    init() {
        setupAudioSession()
        setupRouteChangeListener()
        setupInterruptionListener()
        detectCurrentRoute()
    }
    
    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        if let token = endObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    // MARK: - Audio Session Configuration
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            // Request high sample rate for audiophile USB DACs
            try session.setPreferredSampleRate(96000.0)
            try session.setActive(true)
        } catch {
            print("Error configuring AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Route & DAC Detection
    private func setupRouteChangeListener() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.detectCurrentRoute()
        }
    }
    
    private func setupInterruptionListener() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let userInfo = notif.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            switch type {
            case .began:
                self?.pause()
            case .ended:
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.resume()
                    }
                }
            @unknown default:
                break
            }
        }
    }
    
    func detectCurrentRoute() {
        let session = AVAudioSession.sharedInstance()
        let currentOutputs = session.currentRoute.outputs
        
        var detected: [AudioDeviceInfo] = []
        var hasUsbDAC = false
        var activeName = "Speaker"
        
        for out in currentOutputs {
            activeName = out.portName
            let isUSB = out.portType == .usbAudio
            if isUSB {
                hasUsbDAC = true
            }
            detected.append(AudioDeviceInfo(
                id: out.uid,
                name: out.portName,
                driver: isUSB ? "USB DAC" : "iOS CoreAudio",
                isExclusiveCapable: isUSB
            ))
        }
        
        self.availableDevices = detected
        self.currentDevice = activeName
        self.isExclusive = hasUsbDAC
        self.audioSampleRate = Int(session.sampleRate)
        
        if hasUsbDAC {
            self.preferredDeviceName = activeName
            self.isDeviceConnected = true
            self.deviceWarning = nil
        } else if !preferredDeviceName.isEmpty && preferredDeviceName.localizedCaseInsensitiveContains("HiBy") {
            self.isDeviceConnected = false
            self.deviceWarning = "\(preferredDeviceName) disconnected. Using device speaker."
        } else {
            self.isDeviceConnected = true
            self.deviceWarning = nil
        }
        
        self.objectWillChange.send()
    }
    
    // MARK: - Playback Control
    func play(url: String) {
        let streamURL: URL
        if url.hasPrefix("/") {
            streamURL = URL(fileURLWithPath: url)
        } else if let parsed = URL(string: url) {
            streamURL = parsed
        } else {
            return
        }
        
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        if let token = endObserverToken {
            NotificationCenter.default.removeObserver(token)
            endObserverToken = nil
        }
        
        let item = AVPlayerItem(url: streamURL)
        endObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onTrackFinished?()
        }
        
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }
        
        player?.automaticallyWaitsToMinimizeStalling = true
        player?.preventsDisplaySleepDuringVideoPlayback = false
        player?.volume = Float(volume / 100.0)
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error activating AVAudioSession on play: \(error)")
        }
        
        player?.play()
        self.isPaused = false
        self.objectWillChange.send()
        
        // Track time updates
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            if let curItem = self.player?.currentItem {
                let d = curItem.duration.seconds
                if !d.isNaN && d > 0 {
                    self.duration = d
                }
            }
        }
    }
    
    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }
    
    func resume() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
        player?.play()
        self.isPaused = false
        self.objectWillChange.send()
    }
    
    func pause() {
        player?.pause()
        self.isPaused = true
        self.objectWillChange.send()
    }
    
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        self.currentTime = seconds
        self.objectWillChange.send()
    }
    
    func setVolume(_ newVolume: Double) {
        let clamped = max(0.0, min(100.0, newVolume))
        self.volume = clamped
        self.player?.volume = Float(clamped / 100.0)
        self.objectWillChange.send()
    }
    
    func setDevice(_ deviceId: String) {
        // iOS routing is managed via AVAudioSession / Control Center / AVRoutePickerView
        self.detectCurrentRoute()
    }
    
    func toggleExclusive() {
        // On iOS, toggle high sample rate request
        isExclusive.toggle()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setPreferredSampleRate(isExclusive ? 96000.0 : 44100.0)
            self.audioSampleRate = Int(session.sampleRate)
        } catch {
            print("Error toggling sample rate: \(error)")
        }
        self.objectWillChange.send()
    }
    
    func togglePhysicalFormat() {
        changePhysicalFormat.toggle()
        self.objectWillChange.send()
    }
    
    func toggleGapless() {
        isGapless.toggle()
        self.objectWillChange.send()
    }
    
    func start() {
        setupAudioSession()
    }
    
    func stop() {
        player?.pause()
        player = nil
        isPaused = true
        self.objectWillChange.send()
    }
    
    func restart() {
        stop()
        setupAudioSession()
    }
}
#endif
