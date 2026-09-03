//
//  SettingsView.swift
//  mpvg
//
//  Settings view for Navidrome server credentials and platform-specific audio engine configuration.
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
            VStack(alignment: .leading, spacing: 20) {
                #if os(macOS)
                // macOS Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    Text("Navidrome Server & Audiophile Audio Engine Setup")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textTertiary)
                }
                .padding(.bottom, 6)
                #endif
                
                // Section 1: Navidrome Server Configuration
                settingsCard(title: "Navidrome Server", icon: "server.rack") {
                    VStack(alignment: .leading, spacing: 14) {
                        // Server URL
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server URL")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTheme.textSecondary)
                            
                            TextField("https://music.example.com", text: $serverURL)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                #endif
                                .padding(10)
                                .background(ColorTheme.inputBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(ColorTheme.inputBorder, lineWidth: 1)
                                )
                                .cornerRadius(8)
                        }
                        
                        // Credentials
                        #if os(macOS)
                        HStack(spacing: 16) {
                            credentialInputs
                        }
                        #else
                        VStack(spacing: 12) {
                            credentialInputs
                        }
                        #endif
                        
                        Toggle("Connect automatically at launch", isOn: $autoConnect)
                            .platformCheckbox()
                            .font(.system(size: 13))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Divider()
                            .background(ColorTheme.cardBorder)
                        
                        // Connection Status & Action Buttons
                        #if os(macOS)
                        macOSActionButtons
                        #else
                        iOSActionButtons
                        #endif
                    }
                }
                
                // Section 2: Audio Engine Setup
                #if os(macOS)
                macOSAudioSection
                #else
                iOSAudioSection
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 60)
        }
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
    
    // MARK: - Subviews & Credentials
    private var credentialInputs: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text("Username")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ColorTheme.textSecondary)
                
                TextField("username", text: $username)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .padding(10)
                    .background(ColorTheme.inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorTheme.inputBorder, lineWidth: 1)
                    )
                    .cornerRadius(8)
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
            }
        }
    }
    
    // MARK: - iOS Action Buttons (Stacked, Clean & Adaptive)
    private var iOSActionButtons: some View {
        VStack(spacing: 12) {
            // Status Indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.amber)
                    .frame(width: 8, height: 8)
                Text(viewModel.connectionStatusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.textSecondary)
                
                Spacer()
            }
            
            // Primary Save Button
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
            
            // Secondary Demo Catalog Button
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
    
    // MARK: - macOS Action Buttons
    private var macOSActionButtons: some View {
        HStack(spacing: 12) {
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
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(ColorTheme.terracotta)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isTestingConnection)
            
            Button(action: { viewModel.loadSampleCatalog() }) {
                Text("Load Demo Catalog")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ColorTheme.terracotta)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(ColorTheme.terracottaLight.opacity(0.4))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.amber)
                    .frame(width: 8, height: 8)
                Text(viewModel.connectionStatusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.textSecondary)
            }
        }
    }
    
    // MARK: - iOS Native Audio Section
    private var iOSAudioSection: some View {
        settingsCard(title: "Audio & Output", icon: "waveform.circle.fill") {
            VStack(alignment: .leading, spacing: 14) {
                // Active Output Route
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
                
                Divider()
                    .background(ColorTheme.cardBorder)
                
                // Hi-Res Capabilities
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
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ColorTheme.sageGreen)
                            .font(.system(size: 13))
                        Text("Background Audio Playback")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ColorTheme.textPrimary)
                    }
                    
                    Text("Continuous playback with lock screen controls and system media key support.")
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }
        }
    }
    
    // MARK: - macOS MPV & Exclusive Audio Section
    #if os(macOS)
    private var macOSAudioSection: some View {
        settingsCard(title: "Audio Engine & Exclusive Mode", icon: "waveform.circle.fill") {
            VStack(alignment: .leading, spacing: 14) {
                // Binary path
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Engine / Binary Path")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ColorTheme.textSecondary)
                        Text(viewModel.mpv.binaryPath)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(ColorTheme.textPrimary)
                    }
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ColorTheme.sageGreen)
                        Text("Ready")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ColorTheme.sageGreen)
                    }
                }
                
                Divider()
                    .background(ColorTheme.cardBorder)
                
                // Device picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio Output Device")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    Picker("", selection: $selectedDeviceId) {
                        ForEach(viewModel.mpv.availableDevices) { dev in
                            Text(dev.displayName).tag(dev.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 380)
                    .onChange(of: selectedDeviceId) { newId in
                        if !newId.isEmpty && newId != viewModel.mpv.currentDevice {
                            viewModel.mpv.setDevice(newId)
                        }
                    }
                    
                    // Active Device Confirmation Banner
                    if let activeDev = viewModel.mpv.availableDevices.first(where: { $0.id == viewModel.mpv.currentDevice }) {
                        HStack(spacing: 6) {
                            Circle().fill(ColorTheme.sageGreen).frame(width: 6, height: 6)
                            Text("Active: \(activeDev.displayName)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ColorTheme.sageGreen)
                            
                            if activeDev.isExclusiveCapable {
                                Text("• Supports CoreAudio Exclusive Hog Mode")
                                    .font(.system(size: 10))
                                    .foregroundColor(ColorTheme.textTertiary)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                
                Divider()
                    .background(ColorTheme.cardBorder)
                
                // Audio switches
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { viewModel.mpv.isExclusive },
                        set: { _ in viewModel.mpv.toggleExclusive() }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("CoreAudio Exclusive Mode (--audio-exclusive=yes)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(ColorTheme.textPrimary)
                                
                                Text("Audiophile Hog Mode")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(ColorTheme.terracotta)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(ColorTheme.terracottaLight.opacity(0.5))
                                    .cornerRadius(4)
                            }
                            Text("Takes exclusive direct hardware control of the connected DAC, bypassing macOS system mixer and alerts.")
                                .font(.system(size: 11))
                                .foregroundColor(ColorTheme.textSecondary)
                        }
                    }
                    .platformCheckbox()
                    
                    Toggle(isOn: Binding(
                        get: { viewModel.mpv.changePhysicalFormat },
                        set: { _ in viewModel.mpv.togglePhysicalFormat() }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bit-Perfect Sample Rate Switching (--coreaudio-change-physical-format=yes)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ColorTheme.textPrimary)
                            Text("Matches hardware sample rate dynamically to source track (e.g., 44.1kHz, 96kHz, 192kHz) without resampling.")
                                .font(.system(size: 11))
                                .foregroundColor(ColorTheme.textSecondary)
                        }
                    }
                    .platformCheckbox()
                    
                    Toggle(isOn: Binding(
                        get: { viewModel.mpv.isGapless },
                        set: { _ in viewModel.mpv.toggleGapless() }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gapless Audio Playback (--gapless-audio=yes)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ColorTheme.textPrimary)
                            Text("Seamless transition between consecutive tracks for live and continuous albums.")
                                .font(.system(size: 11))
                                .foregroundColor(ColorTheme.textSecondary)
                        }
                    }
                    .platformCheckbox()
                }
                
                Divider()
                    .background(ColorTheme.cardBorder)
                
                HStack {
                    Button(action: {
                        viewModel.mpv.restart()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Restart Audio Engine")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(ColorTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ColorTheme.cardBorder.opacity(0.5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    if viewModel.mpv.isRunning {
                        HStack(spacing: 5) {
                            Circle().fill(ColorTheme.sageGreen).frame(width: 7, height: 7)
                            Text("Engine Active (/tmp/mpv_player.sock)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(ColorTheme.sageGreen)
                        }
                    }
                }
            }
        }
    }
    #endif
    
    private func saveAndTestConnection() {
        viewModel.serverConfig.urlString = serverURL
        viewModel.serverConfig.username = username
        viewModel.serverConfig.password = password
        viewModel.serverConfig.autoConnect = autoConnect
        
        Task {
            await viewModel.testConnection()
        }
    }
    
    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.terracotta)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
            }
            
            content()
        }
        .padding(16)
        .background(ColorTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ColorTheme.cardBorder, lineWidth: 1.2)
        )
        .cornerRadius(14)
    }
}
