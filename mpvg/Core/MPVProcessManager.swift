//
//  MPVProcessManager.swift
//  mpvg
//
//  Created by Fabián Sanhueza on 30-08-26.
//


import Foundation

@MainActor
final class MPVProcessManager: ObservableObject {
    private var process: Process?
    let socketPath = "/tmp/mpv_player.sock"
    
    @Published var isRunning = false
    @Published var currentDevice: String = "coreaudio/AppleUSBAudioEngine:HiBy:HiBy FC1:0:1"
    
    func start() {
        guard process == nil || !(process?.isRunning ?? false) else { return }
        
        // Limpiar socket anterior si quedó colgado
        try? FileManager.default.removeItem(atPath: socketPath)
        
        let proc = Process()
        // Ruta estándar de Homebrew en Apple Silicon (usa /usr/local/bin/mpv si estás en Intel)
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mpv")
        
        proc.arguments = [
            "--idle",
            "--input-ipc-server=\(socketPath)",
            "--audio-device=\(currentDevice)",
            "--audio-exclusive=yes",
            "--coreaudio-change-physical-format=yes",
            "--no-video",
            "--gapless-audio=yes"
        ]
        
        do {
            try proc.run()
            self.process = proc
            self.isRunning = true
        } catch {
            print("Error al iniciar mpv: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        process?.terminate()
        process = nil
        self.isRunning = false
        try? FileManager.default.removeItem(atPath: socketPath)
    }
    
    func sendCommand(_ args: [Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["command": args]),
              let payload = String(data: data, encoding: .utf8) else { return }
        
        // Envío directo al socket UNIX mediante netcat (o cliente POSIX)
        let client = Process()
        client.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        client.arguments = ["-U", socketPath]
        
        let pipe = Pipe()
        client.standardInput = pipe
        
        do {
            try client.run()
            if let cmdData = "\(payload)\n".data(using: .utf8) {
                pipe.fileHandleForWriting.write(cmdData)
                try pipe.fileHandleForWriting.close()
            }
        } catch {
            print("Error enviando comando a mpv: \(error)")
        }
    }
}