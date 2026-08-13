import Darwin
import Foundation

public enum ProcessArguments {
    /// Reads argv for `pid` via KERN_PROCARGS2. Returns [] if the process is gone or inaccessible.
    public static func arguments(for pid: Int32) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 0
        var result = sysctl(&mib, u_int(mib.count), nil, &size, nil, 0)
        guard result == 0, size > 4 else { return [] }

        var buffer = [UInt8](repeating: 0, count: size)
        result = buffer.withUnsafeMutableBufferPointer { ptr in
            sysctl(&mib, u_int(mib.count), ptr.baseAddress, &size, nil, 0)
        }
        guard result == 0, size > 4 else { return [] }

        let argc = buffer.prefix(4).withUnsafeBytes { $0.load(as: Int32.self) }
        guard argc > 0 else { return [] }

        var index = 4
        while index < buffer.count, buffer[index] != 0 {
            index += 1
        }
        while index < buffer.count, buffer[index] == 0 {
            index += 1
        }

        var args: [String] = []
        var current: [UInt8] = []
        while index < buffer.count, args.count < Int(argc) {
            let byte = buffer[index]
            if byte == 0 {
                if !current.isEmpty {
                    args.append(String(decoding: current, as: UTF8.self))
                    current.removeAll(keepingCapacity: true)
                }
            } else {
                current.append(byte)
            }
            index += 1
        }
        if !current.isEmpty, args.count < Int(argc) {
            args.append(String(decoding: current, as: UTF8.self))
        }
        return args
    }

    public static func userDataDir(from arguments: [String]) -> String? {
        value(named: "--user-data-dir", in: arguments)
    }

    public static func value(named flag: String, in arguments: [String]) -> String? {
        for (index, arg) in arguments.enumerated() {
            if arg == flag, index + 1 < arguments.count {
                return arguments[index + 1]
            }
            let prefix = flag + "="
            if arg.hasPrefix(prefix) {
                return String(arg.dropFirst(prefix.count))
            }
        }
        return nil
    }
}
