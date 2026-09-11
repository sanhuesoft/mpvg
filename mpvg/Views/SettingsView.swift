//
//  SettingsView.swift
//  mpvg
//
//  Settings view for Navidrome server credentials and platform-specific audio engine configuration.
//  Adheres to native macOS HIG (Sequoia/Sonoma Inset Grouped layout) and modern iOS guidelines.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appAccentColor") private var appAccentColor: String = "terracotta"
    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var autoConnect: Bool = true
    @State private var preloadQueueCount: Int = 5
    @State private var selectedDeviceId: String = ""
    @State private var isRestartingEngine: Bool = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                #if os(macOS)
                // macOS Native Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Settings"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    Text(LocalizedStringKey("Configure your Navidrome server connection and audiophile CoreAudio playback."))
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textTertiary)
                }
                .padding(.top, 4)
                
                // Section 1: Server Configuration (macOS Form Style)
                macOSServerCard
                
                // Section 2: Appearance & Theme
                macOSThemeSection
                
                // Section 3: Audio Engine (macOS Form Style)
                macOSAudioSection
                
                // Section 4: Playback & Audio Cache (macOS Form Style)
                macOSCacheSection
                #else
                // iOS Form Card
                iOSServerCard
                iOSThemeSection
                iOSTabBarSection
                iOSAudioSection
                iOSCacheSection
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 60)
        }
        .scrollDismissesKeyboard(.interactively)
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: { hideKeyboard() }) {
                    Text(LocalizedStringKey("Done"))
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ColorTheme.terracotta)
            }
        }
        #endif
        .background(ColorTheme.windowBackground)
        .onAppear {
            serverURL = viewModel.serverConfig.urlString
            username = viewModel.serverConfig.username
            password = viewModel.serverConfig.password
            autoConnect = viewModel.serverConfig.autoConnect
            preloadQueueCount = viewModel.serverConfig.preloadQueueCount
            selectedDeviceId = viewModel.mpv.currentDevice
        }
        .onChange(of: viewModel.mpv.currentDevice) { newDev in
            selectedDeviceId = newDev
        }
    }
    
    // MARK: - macOS Native Server Card
    #if os(macOS)
    private var macOSServerCard: some View {
        settingsCard(title: "Navidrome Server", icon: "server.rack", iconColor: ColorTheme.terracotta) {
            VStack(spacing: 0) {
                // Row 1: Server URL
                macOSFormRow(label: "Server URL", subtitle: "URL to your Navidrome instance") {
                    TextField("https://music.example.com", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 320)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 2: Username
                macOSFormRow(label: "Username", subtitle: "Subsonic API user") {
                    TextField("username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 320)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 3: Password
                macOSFormRow(label: "Password", subtitle: "Authentication token or password") {
                    SecureField("••••••••", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 4: Auto-Connect Toggle
                macOSFormRow(label: "Auto-Connect", subtitle: "Connect automatically when mpvg launches") {
                    Toggle("", isOn: $autoConnect)
                        .toggleStyle(.switch)
                        .tint(ColorTheme.terracotta)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 5: Status & Action Buttons
                HStack(alignment: .center, spacing: 14) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.amber)
                            .frame(width: 8, height: 8)
                        Text(LocalizedStringKey(viewModel.connectionStatusMessage))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { viewModel.loadSampleCatalog() }) {
                        Text(LocalizedStringKey("Load Demo"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: saveAndTestConnection) {
                        HStack(spacing: 6) {
                            if viewModel.isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                            }
                            Text(LocalizedStringKey("Save & Test Connection"))
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTheme.terracotta)
                    .disabled(viewModel.isTestingConnection)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - macOS Appearance Card
    private var macOSThemeSection: some View {
        settingsCard(title: "Appearance", icon: "paintpalette.fill", iconColor: ColorTheme.accent) {
            VStack(spacing: 0) {
                // Row 1: Light / Dark Mode
                macOSFormRow(label: "Theme", subtitle: "Choose between automatic system mode, or forced light/dark theme") {
                    Picker("", selection: $appTheme) {
                        Text(LocalizedStringKey("System (Automatic)")).tag("system")
                        Text(LocalizedStringKey("Light")).tag("light")
                        Text(LocalizedStringKey("Dark")).tag("dark")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 190)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 2: Accent Color Palette Swatches
                macOSFormRow(label: "Accent Color", subtitle: "Select your accent color for buttons and highlights") {
                    HStack(spacing: 9) {
                        ForEach(PrimaryAccent.allCases) { accent in
                            let isSelected = (appAccentColor == accent.rawValue)
                            Button(action: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    appAccentColor = accent.rawValue
                                    viewModel.setAccentColor(accent)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 22, height: 22)
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .heavy))
                                            .foregroundColor(.white)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? ColorTheme.textPrimary.opacity(0.45) : Color.clear, lineWidth: 2)
                                        .padding(-3)
                                )
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .pointingHandOnHover()
                            .help(accent.displayName)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - macOS Native Audio Engine Card
    private var macOSAudioSection: some View {
        settingsCard(title: "Audio Engine & Exclusive Mode", icon: "waveform.circle.fill", iconColor: ColorTheme.sageGreen) {
            VStack(spacing: 0) {
                // Row 1: Output Device Picker
                macOSFormRow(label: "Output Device", subtitle: "Select physical DAC or CoreAudio endpoint") {
                    HStack(spacing: 8) {
                        Picker("", selection: $selectedDeviceId) {
                            ForEach(viewModel.mpv.availableDevices) { dev in
                                Text(dev.displayName).tag(dev.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 280)
                        .onChange(of: selectedDeviceId) { newId in
                            if !newId.isEmpty && newId != viewModel.mpv.currentDevice {
                                viewModel.mpv.setDevice(newId)
                            }
                        }
                    }
                }
                
                // Active Device Confirmation Strip
                if let activeDev = viewModel.mpv.availableDevices.first(where: { $0.id == viewModel.mpv.currentDevice }) {
                    HStack(spacing: 8) {
                        Circle().fill(ColorTheme.sageGreen).frame(width: 6, height: 6)
                        Text(LocalizedStringKey("Active: \(activeDev.displayName)"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ColorTheme.sageGreen)
                        
                        if activeDev.isExclusiveCapable {
                            Text(LocalizedStringKey("• Supports Direct Hardware Hog Mode"))
                                .font(.system(size: 11))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ColorTheme.sageGreenBg.opacity(0.4))
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 2: CoreAudio Exclusive Mode
                macOSFormRow(
                    label: "CoreAudio Exclusive Mode",
                    subtitle: "Takes exclusive direct hardware control of the connected DAC, bypassing macOS system mixer and alerts (--audio-exclusive=yes)."
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.mpv.isExclusive },
                        set: { _ in viewModel.mpv.toggleExclusive() }
                    ))
                    .toggleStyle(.switch)
                    .tint(ColorTheme.terracotta)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 3: Bit-Perfect Sample Rate Switching
                macOSFormRow(
                    label: "Bit-Perfect Sample Rate",
                    subtitle: "Matches DAC hardware sample rate dynamically to source track (44.1kHz, 96kHz, 192kHz) without resampling."
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.mpv.changePhysicalFormat },
                        set: { _ in viewModel.mpv.togglePhysicalFormat() }
                    ))
                    .toggleStyle(.switch)
                    .tint(ColorTheme.terracotta)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 4: Gapless Playback
                macOSFormRow(
                    label: "Gapless Playback",
                    subtitle: "Seamless transition between consecutive tracks for live and continuous albums."
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.mpv.isGapless },
                        set: { _ in viewModel.mpv.toggleGapless() }
                    ))
                    .toggleStyle(.switch)
                    .tint(ColorTheme.terracotta)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 5: Process Control & Status
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.mpv.binaryPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(ColorTheme.textSecondary)
                        Text("IPC Socket: /tmp/mpv_player.sock")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isRestartingEngine = true
                        viewModel.mpv.restart()
                        viewModel.showToast(String(localized: "Motor mpv reiniciado y modo exclusivo liberado"))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            isRestartingEngine = false
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(isRestartingEngine ? 360 : 0))
                                .animation(isRestartingEngine ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRestartingEngine)
                            Text(LocalizedStringKey("Restart Engine"))
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRestartingEngine)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - macOS Form Row Helper
    private func macOSFormRow<Content: View>(
        label: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(label))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                if let sub = subtitle {
                    Text(LocalizedStringKey(sub))
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
    
    // MARK: - macOS Playback & Audio Cache Card
    private var macOSCacheSection: some View {
        settingsCard(title: "Playback & Audio Cache", icon: "arrow.down.circle.fill", iconColor: ColorTheme.terracotta) {
            VStack(spacing: 0) {
                // Row 1: Queue Preload Count
                macOSFormRow(label: "Queue Preload", subtitle: "Preload upcoming tracks in queue for instant start") {
                    Picker("", selection: $preloadQueueCount) {
                        Text("Disabled").tag(0)
                        Text("1 track").tag(1)
                        Text("3 tracks").tag(3)
                        Text("5 tracks (Default)").tag(5)
                        Text("10 tracks").tag(10)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)
                    .onChange(of: preloadQueueCount) { newVal in
                        viewModel.serverConfig.preloadQueueCount = newVal
                    }
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 2: Audio Cache Size & Clear Action
                macOSFormRow(label: "Audio Cache", subtitle: "Local audio downloaded for seamless playback") {
                    HStack(spacing: 12) {
                        Text(viewModel.formattedAudioCacheSize)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Button(role: .destructive, action: {
                            viewModel.clearAudioCache()
                        }) {
                            Text(LocalizedStringKey("Clear Cache"))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .pointingHandOnHover()
                    }
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 3: Artwork Cache Size & Clear Action
                macOSFormRow(label: "Artwork Cache", subtitle: "Album covers and artist portraits stored locally") {
                    HStack(spacing: 12) {
                        Text(viewModel.formattedArtworkCacheSize)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Button(role: .destructive, action: {
                            viewModel.clearArtworkCache()
                        }) {
                            Text(LocalizedStringKey("Clear Cache"))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .pointingHandOnHover()
                    }
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                // Row 4: Library Sync
                macOSFormRow(label: "Library Sync", subtitle: "Rescan server folders and refresh local catalog") {
                    Button(action: {
                        Task {
                            await viewModel.syncLibrary()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .rotationEffect(.degrees(viewModel.isSyncingLibrary ? 360 : 0))
                                .animation(viewModel.isSyncingLibrary ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: viewModel.isSyncingLibrary)
                            Text(viewModel.isSyncingLibrary ? "Syncing..." : "Sync Library Now")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTheme.terracotta)
                    .disabled(viewModel.isSyncingLibrary)
                    .pointingHandOnHover()
                }
            }
        }
    }
    #endif
    
    // MARK: - iOS Server Card
    #if os(iOS)
    private var iOSServerCard: some View {
        settingsCard(title: "Navidrome Server", icon: "server.rack", iconColor: ColorTheme.terracotta) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Server URL"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    TextField("https://music.example.com", text: $serverURL)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .padding(10)
                        .background(ColorTheme.inputBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ColorTheme.inputBorder, lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .submitLabel(.next)
                }
                
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Username"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        TextField("username", text: $username)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(ColorTheme.inputBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ColorTheme.inputBorder, lineWidth: 1)
                            )
                            .cornerRadius(8)
                            .submitLabel(.next)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Password"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        SecureField("••••••••", text: $password)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(ColorTheme.inputBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ColorTheme.inputBorder, lineWidth: 1)
                            )
                            .cornerRadius(8)
                            .submitLabel(.done)
                            .onSubmit {
                                hideKeyboard()
                                saveAndTestConnection()
                            }
                    }
                }
                
                Toggle(isOn: $autoConnect) {
                    Text(LocalizedStringKey("Auto-Connect"))
                }
                .platformCheckbox()
                .font(.system(size: 13))
                .foregroundColor(ColorTheme.textSecondary)
                
                Divider()
                    .background(ColorTheme.cardBorder)
                
                // Status & Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.amber)
                            .frame(width: 8, height: 8)
                        Text(LocalizedStringKey(viewModel.connectionStatusMessage))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.textSecondary)
                        
                        Spacer()
                    }
                    
                    Button(action: saveAndTestConnection) {
                        HStack(spacing: 8) {
                            if viewModel.isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                            }
                            Text(LocalizedStringKey("Save & Test Connection"))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .background(ColorTheme.terracotta)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isTestingConnection)
                    
                    Button(action: { viewModel.loadSampleCatalog() }) {
                        Text(LocalizedStringKey("Load Demo"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ColorTheme.terracotta)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(ColorTheme.terracottaLight.opacity(0.4))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - iOS Appearance Card
    private var iOSThemeSection: some View {
        settingsCard(title: "Appearance", icon: "paintpalette.fill", iconColor: ColorTheme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("Theme"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ColorTheme.textPrimary)
                    Text(LocalizedStringKey("Adapts automatically to system dark mode or allows manual override"))
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    Picker("", selection: $appTheme) {
                        Text(LocalizedStringKey("System")).tag("system")
                        Text(LocalizedStringKey("Light")).tag("light")
                        Text(LocalizedStringKey("Dark")).tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("Accent Color"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ColorTheme.textPrimary)
                    Text(LocalizedStringKey("Select your accent color for buttons and highlights"))
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(PrimaryAccent.allCases) { accent in
                                let isSelected = (appAccentColor == accent.rawValue)
                                Button(action: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        appAccentColor = accent.rawValue
                                        viewModel.setAccentColor(accent)
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(accent.color)
                                                .frame(width: 32, height: 32)
                                            
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(isSelected ? ColorTheme.textPrimary.opacity(0.45) : Color.clear, lineWidth: 2)
                                                .padding(-2)
                                        )
                                        
                                        Text(accent.displayName)
                                            .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                            .foregroundColor(isSelected ? ColorTheme.textPrimary : ColorTheme.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - iOS Native Audio Section
    private var iOSAudioSection: some View {
        settingsCard(title: "Audio Engine & Exclusive Mode", icon: "waveform.circle.fill", iconColor: ColorTheme.terracotta) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Output Device"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.mpv.isExclusive ? "bolt.fill" : "speaker.wave.2.fill")
                                .foregroundColor(viewModel.mpv.isExclusive ? ColorTheme.terracotta : ColorTheme.textPrimary)
                            Text(viewModel.mpv.currentDevice)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(ColorTheme.textPrimary)
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.mpv.isExclusive {
                        Text(LocalizedStringKey("EXCLUSIVE"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(ColorTheme.terracotta)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTheme.terracottaLight)
                            .cornerRadius(6)
                    }
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ColorTheme.sageGreen)
                            .font(.system(size: 13))
                        Text(LocalizedStringKey("Native CoreAudio Bit-Perfect Output"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ColorTheme.textPrimary)
                    }
                    
                    Text(LocalizedStringKey("Automatically requests high sample rate (up to 96kHz) when a USB DAC like HiBy FC1 is connected."))
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - iOS Playback & Audio Cache Card
    private var iOSCacheSection: some View {
        settingsCard(title: "Playback & Audio Cache", icon: "arrow.down.circle.fill", iconColor: ColorTheme.terracotta) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Queue Preload"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTheme.textPrimary)
                        Text(LocalizedStringKey("Upcoming tracks to preload in background"))
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    Spacer()
                    Picker("", selection: $preloadQueueCount) {
                        Text("0").tag(0)
                        Text("1").tag(1)
                        Text("3").tag(3)
                        Text("5").tag(5)
                        Text("10").tag(10)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: preloadQueueCount) { newVal in
                        viewModel.serverConfig.preloadQueueCount = newVal
                    }
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Audio Cache"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTheme.textPrimary)
                        Text(viewModel.formattedAudioCacheSize)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    Spacer()
                    Button(role: .destructive, action: {
                        viewModel.clearAudioCache()
                    }) {
                        Text(LocalizedStringKey("Clear Cache"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Artwork Cache"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTheme.textPrimary)
                        Text(viewModel.formattedArtworkCacheSize)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    Spacer()
                    Button(role: .destructive, action: {
                        viewModel.clearArtworkCache()
                    }) {
                        Text(LocalizedStringKey("Clear Cache"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider().background(ColorTheme.cardBorder)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Library Sync"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTheme.textPrimary)
                        Text(LocalizedStringKey("Rescan server and refresh catalog"))
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    Spacer()
                    Button(action: {
                        Task {
                            await viewModel.syncLibrary()
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .rotationEffect(.degrees(viewModel.isSyncingLibrary ? 360 : 0))
                                .animation(viewModel.isSyncingLibrary ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: viewModel.isSyncingLibrary)
                            Text(viewModel.isSyncingLibrary ? "Syncing..." : "Sync Now")
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTheme.terracotta)
                    .disabled(viewModel.isSyncingLibrary)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - iOS Tab Bar Style Card
    private var iOSTabBarSection: some View {
        settingsCard(title: "Interface", icon: "dock.rectangle", iconColor: ColorTheme.terracotta) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Tab Bar Style"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTheme.textPrimary)
                        Text(LocalizedStringKey("Choose whether to display labels below icons"))
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    Spacer()
                    Picker("", selection: $viewModel.tabBarShowsLabels) {
                        Text(LocalizedStringKey("Icons and Text")).tag(true)
                        Text(LocalizedStringKey("Icons Only")).tag(false)
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(16)
        }
    }
    #endif
    
    // MARK: - Shared Helpers
    private func saveAndTestConnection() {
        viewModel.serverConfig.urlString = serverURL
        viewModel.serverConfig.username = username
        viewModel.serverConfig.password = password
        viewModel.serverConfig.autoConnect = autoConnect
        viewModel.serverConfig.preloadQueueCount = preloadQueueCount
        
        Task {
            await viewModel.testConnection()
        }
    }
    
    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        iconColor: Color = ColorTheme.terracotta,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(LocalizedStringKey(title))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ColorTheme.cardBackground)
            
            Divider().background(ColorTheme.cardBorder)
            
            // Content Body
            content()
                .background(ColorTheme.cardBackground)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ColorTheme.cardBorder, lineWidth: 1.2)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }
}
