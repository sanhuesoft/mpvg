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
    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var autoConnect: Bool = true
    @State private var selectedDeviceId: String = ""
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                #if os(macOS)
                // macOS Native Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    Text("Configure your Navidrome server connection and audiophile CoreAudio playback.")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textTertiary)
                }
                .padding(.top, 4)
                
                // Section 1: Server Configuration (macOS Form Style)
                macOSServerCard
                
                // Section 2: Audio Engine (macOS Form Style)
                macOSAudioSection
                #else
                // iOS Form Card
                iOSServerCard
                iOSAudioSection
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
                Button("Done") {
                    hideKeyboard()
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
                        Text(viewModel.connectionStatusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { viewModel.loadSampleCatalog() }) {
                        Text("Load Demo")
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
                            Text("Save & Test Connection")
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
                        Text("Active: \(activeDev.displayName)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ColorTheme.sageGreen)
                        
                        if activeDev.isExclusiveCapable {
                            Text("• Supports Direct Hardware Hog Mode")
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
                    
                    Button(action: { viewModel.mpv.restart() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("Restart Engine")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
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
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                if let sub = subtitle {
                    Text(sub)
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
    #endif
    
    // MARK: - iOS Server Card
    #if os(iOS)
    private var iOSServerCard: some View {
        settingsCard(title: "Navidrome Server", icon: "server.rack", iconColor: ColorTheme.terracotta) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
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
                        Text("Username")
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
                        Text("Password")
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
                
                Toggle("Connect automatically at launch", isOn: $autoConnect)
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
                        Text(viewModel.connectionStatusMessage)
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
                            Text("Save Connection")
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
                        Text("Load Demo Catalog")
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
    
    // MARK: - iOS Native Audio Section
    private var iOSAudioSection: some View {
        settingsCard(title: "Audio & Output", icon: "waveform.circle.fill", iconColor: ColorTheme.terracotta) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Output Device")
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
                        Text("HI-RES DAC")
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
                        Text("Native CoreAudio Bit-Perfect Output")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ColorTheme.textPrimary)
                    }
                    
                    Text("Automatically requests high sample rate (up to 96kHz) when a USB DAC like HiBy FC1 is connected.")
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textSecondary)
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
                
                Text(title)
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
