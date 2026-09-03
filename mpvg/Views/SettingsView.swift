//
//  SettingsView.swift
//  mpvg
//
//  Settings view for Navidrome server credentials and MPV audio engine configuration
//  with CoreAudio exclusive mode and bit-perfect playback options.
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
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configuración")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    Text("Servidor Navidrome y Motor de Audio Exclusivo MPV")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textTertiary)
                }
                .padding(.bottom, 6)
                
                // Section 1: Navidrome Server
                settingsCard(title: "Servidor Navidrome (API Subsonic)", icon: "server.rack") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URL del Servidor")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTheme.textSecondary)
                            
                            TextField("http://localhost:4533", text: $serverURL)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(ColorTheme.inputBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(ColorTheme.inputBorder, lineWidth: 1)
                                )
                                .cornerRadius(6)
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Usuario")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(ColorTheme.textSecondary)
                                
                                TextField("admin", text: $username)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(ColorTheme.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(ColorTheme.inputBorder, lineWidth: 1)
                                    )
                                    .cornerRadius(6)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Contraseña")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(ColorTheme.textSecondary)
                                
                                SecureField("••••••••", text: $password)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(ColorTheme.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(ColorTheme.inputBorder, lineWidth: 1)
                                    )
                                    .cornerRadius(6)
                            }
                        }
                        
                        Toggle("Conectar automáticamente al iniciar", isOn: $autoConnect)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Divider()
                            .background(ColorTheme.cardBorder)
                        
                        HStack(spacing: 12) {
                            Button(action: saveAndTestConnection) {
                                HStack(spacing: 6) {
                                    if viewModel.isTestingConnection {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "bolt.horizontal.fill")
                                    }
                                    Text("Guardar y Probar Conexión")
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
                                Text("Cargar Catálogo Demo")
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
                }
                
                // Section 2: MPV Audio Engine & Exclusive Mode
                settingsCard(title: "Motor de Audio MPV & Modo Exclusivo", icon: "waveform.circle.fill") {
                    VStack(alignment: .leading, spacing: 14) {
                        // Binary path
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ruta ejecutable mpv")
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
                                Text("Instalado")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(ColorTheme.sageGreen)
                            }
                        }
                        
                        Divider()
                            .background(ColorTheme.cardBorder)
                        
                        // Device picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dispositivo de Salida de Audio (CoreAudio)")
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
                                    Text("Activo: \(activeDev.displayName)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(ColorTheme.sageGreen)
                                    
                                    if activeDev.isExclusiveCapable {
                                        Text("• Compatible con Modo Exclusivo Hog")
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
                                        Text("Modo Exclusivo CoreAudio (--audio-exclusive=yes)")
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
                                    Text("Toma control exclusivo del DAC conectado, bloqueando sonidos del sistema y evitando el mezclador de macOS.")
                                        .font(.system(size: 11))
                                        .foregroundColor(ColorTheme.textSecondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                            
                            Toggle(isOn: Binding(
                                get: { viewModel.mpv.changePhysicalFormat },
                                set: { _ in viewModel.mpv.togglePhysicalFormat() }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cambio de Formato Físico Bit-Perfect (--coreaudio-change-physical-format=yes)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(ColorTheme.textPrimary)
                                    Text("Ajusta la frecuencia de muestreo del hardware al archivo fuente (ej. 44.1kHz, 96kHz, 192kHz) sin resampleo.")
                                        .font(.system(size: 11))
                                        .foregroundColor(ColorTheme.textSecondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                            
                            Toggle(isOn: Binding(
                                get: { viewModel.mpv.isGapless },
                                set: { _ in viewModel.mpv.toggleGapless() }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reproducción Gapless sin pausas (--gapless-audio=yes)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(ColorTheme.textPrimary)
                                    Text("Transición continua entre pistas de conciertos o álbumes continuos.")
                                        .font(.system(size: 11))
                                        .foregroundColor(ColorTheme.textSecondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                        
                        Divider()
                            .background(ColorTheme.cardBorder)
                        
                        HStack {
                            Button(action: {
                                viewModel.mpv.restart()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Reiniciar MPV")
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
                                    Text("mpv activo (socket /tmp/mpv_player.sock)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(ColorTheme.sageGreen)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 28)
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
        .padding(18)
        .background(ColorTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ColorTheme.cardBorder, lineWidth: 1.2)
        )
        .cornerRadius(14)
    }
}
