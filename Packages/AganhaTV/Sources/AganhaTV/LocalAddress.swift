import Foundation

/// Endereço do aparelho na rede Wi-Fi (para digitar na TV).
public enum LocalAddress {
    /// IPv4 da interface Wi-Fi (`en0`) ou, na falta, da primeira interface ativa não-loopback.
    public static func ipv4() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var fallback: String?
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
                  (interface.ifa_flags & UInt32(IFF_UP)) != 0, (interface.ifa_flags & UInt32(IFF_LOOPBACK)) == 0
            else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            let address = String(cString: host)
            if String(cString: interface.ifa_name) == "en0" { return address }
            fallback = fallback ?? address
        }
        return fallback
    }
}
