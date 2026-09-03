//
//  SocketClient.swift
//  mpvg
//
//  Native POSIX UNIX domain socket client for ultra-fast, reliable IPC with mpv.
//  Configured with SO_NOSIGPIPE and strict timeouts to prevent debugger traps.
//

import Foundation
import Darwin

enum SocketClient {
    static func send(socketPath: String, jsonObject: [String: Any], timeoutMs: Int = 200) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: socketPath) else { return nil }
        
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject),
              var payload = String(data: data, encoding: .utf8) else {
            return nil
        }
        if !payload.hasSuffix("\n") {
            payload += "\n"
        }
        
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        // Prevent SIGPIPE when mpv restarts or closes socket
        var nosigpipe: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout<Int32>.size))
        
        // Timeout configuration
        var tv = timeval(tv_sec: 0, tv_usec: __darwin_suseconds_t(timeoutMs * 1000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = socketPath.withCString { strncpy(&addr.sun_path.0, $0, 103) }
        
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, len)
            }
        }
        guard connectRes == 0 else { return nil }
        
        guard let sendData = payload.data(using: .utf8) else { return nil }
        let bytesSent = sendData.withUnsafeBytes { ptr in
            Darwin.send(sock, ptr.baseAddress, sendData.count, 0)
        }
        guard bytesSent > 0 else { return nil }
        
        // Read response
        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = Darwin.recv(sock, &buffer, buffer.count - 1, 0)
        guard bytesRead > 0 else { return nil }
        
        let resData = Data(buffer[0..<bytesRead])
        if let json = try? JSONSerialization.jsonObject(with: resData) as? [String: Any] {
            return json
        }
        return nil
    }
    
    static func sendAsync(socketPath: String, jsonObject: [String: Any], timeoutMs: Int = 200) async -> [String: Any]? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                let res = send(socketPath: socketPath, jsonObject: jsonObject, timeoutMs: timeoutMs)
                continuation.resume(returning: res)
            }
        }
    }
}
