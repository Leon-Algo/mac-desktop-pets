import Foundation

/// 开机自启纯逻辑：注册表值名与命令行构造（跨平台可测）。
/// Windows 实际读写见同文件下方 `RegistryAutostart`（仅 Windows 参与编译）。
enum AutostartPolicy {
    /// HKCU Run 键中的值名。
    static let valueName = "DesktopPets"

    /// 统一加引号：含空格路径在 Run 键中必须带引号才能正确解析。
    static func command(executablePath: String) -> String {
        "\"" + executablePath.trimmingCharacters(in: .whitespacesAndNewlines) + "\""
    }
}

#if os(Windows)
import WinSDK

/// String → NUL 结尾 UTF-16 数组（Windows API 宽字符串传参通用工具）。
func wideString(_ string: String) -> [WCHAR] {
    Array(string.utf16) + [0]
}

/// HKCU\...\CurrentVersion\Run 读写。每次写入即生效，无需管理员权限。
enum RegistryAutostart {
    private static let runKeyPath = "Software\\Microsoft\\Windows\\CurrentVersion\\Run"

    /// 打开/关闭开机自启。`executablePath` 传未加引号的 exe 绝对路径。
    static func setEnabled(_ enabled: Bool, executablePath: String) -> Bool {
        let subKey = wideString(runKeyPath)
        return subKey.withUnsafeBufferPointer { subKeyBuffer in
            var key: HKEY? = nil
            let status = RegCreateKeyExW(
                HKEY_CURRENT_USER,
                subKeyBuffer.baseAddress,
                0,
                nil,
                DWORD(REG_OPTION_NON_VOLATILE),
                DWORD(KEY_QUERY_VALUE | KEY_SET_VALUE),
                nil,
                &key,
                nil
            )
            guard status == ERROR_SUCCESS, let opened = key else { return false }
            defer { RegCloseKey(opened) }

            let name = wideString(AutostartPolicy.valueName)
            if !enabled {
                return name.withUnsafeBufferPointer { nameBuffer in
                    RegDeleteValueW(opened, nameBuffer.baseAddress) == ERROR_SUCCESS
                }
            }

            let value = wideString(AutostartPolicy.command(executablePath: executablePath))
            return name.withUnsafeBufferPointer { nameBuffer in
                value.withUnsafeBufferPointer { valueBuffer in
                    // RegSetValueExW 的 lpData 是 UnsafeRawPointer?；
                    // [WCHAR] 缓冲按字节 reinterpret 传入。
                    let bytes = valueBuffer.baseAddress.map {
                        UnsafeRawPointer($0).assumingMemoryBound(to: BYTE.self)
                    }
                    return RegSetValueExW(
                        opened,
                        nameBuffer.baseAddress,
                        0,
                        UINT(REG_SZ),
                        bytes,
                        DWORD(valueBuffer.count * MemoryLayout<WCHAR>.size)
                    ) == ERROR_SUCCESS
                }
            }
        }
    }

    /// 当前是否已启用开机自启（Run 键存在该值即视为启用）。
    static func isEnabled() -> Bool {
        let subKey = wideString(runKeyPath)
        let name = wideString(AutostartPolicy.valueName)
        return subKey.withUnsafeBufferPointer { subKeyBuffer in
            var key: HKEY? = nil
            let status = RegOpenKeyExW(
                HKEY_CURRENT_USER,
                subKeyBuffer.baseAddress,
                0,
                DWORD(KEY_QUERY_VALUE),
                &key
            )
            guard status == ERROR_SUCCESS, let opened = key else { return false }
            defer { RegCloseKey(opened) }
            return name.withUnsafeBufferPointer { nameBuffer in
                RegQueryValueExW(opened, nameBuffer.baseAddress, nil, nil, nil, nil) == ERROR_SUCCESS
            }
        }
    }
}

/// HKCU 下任意子键的 REG_SZ 读写（会话状态持久化用）。
/// 与 RegistryAutostart 同模式：每次读写独立开闭键，无需常驻句柄。
enum RegistryStrings {
    /// 写入 REG_SZ 值（键不存在则创建）。失败返回 false。
    static func set(subKeyPath: String, valueName: String, string: String) -> Bool {
        let subKey = wideString(subKeyPath)
        return subKey.withUnsafeBufferPointer { subKeyBuffer in
            var key: HKEY? = nil
            let status = RegCreateKeyExW(
                HKEY_CURRENT_USER, subKeyBuffer.baseAddress, 0, nil,
                DWORD(REG_OPTION_NON_VOLATILE),
                DWORD(KEY_SET_VALUE), nil, &key, nil
            )
            guard status == ERROR_SUCCESS, let opened = key else { return false }
            defer { RegCloseKey(opened) }
            let name = wideString(valueName)
            let value = wideString(string)
            return name.withUnsafeBufferPointer { nameBuffer in
                value.withUnsafeBufferPointer { valueBuffer in
                    let bytes = valueBuffer.baseAddress.map {
                        UnsafeRawPointer($0).assumingMemoryBound(to: BYTE.self)
                    }
                    return RegSetValueExW(
                        opened, nameBuffer.baseAddress, 0, UINT(REG_SZ),
                        bytes, DWORD(valueBuffer.count * MemoryLayout<WCHAR>.size)
                    ) == ERROR_SUCCESS
                }
            }
        }
    }

    /// 读取 REG_SZ 值。键/值不存在或非字符串返回 nil。
    static func get(subKeyPath: String, valueName: String) -> String? {
        let subKey = wideString(subKeyPath)
        return subKey.withUnsafeBufferPointer { subKeyBuffer in
            var key: HKEY? = nil
            let status = RegOpenKeyExW(
                HKEY_CURRENT_USER, subKeyBuffer.baseAddress, 0,
                DWORD(KEY_QUERY_VALUE), &key
            )
            guard status == ERROR_SUCCESS, let opened = key else { return nil }
            defer { RegCloseKey(opened) }
            let name = wideString(valueName)
            return name.withUnsafeBufferPointer { nameBuffer -> String? in
                // 第一遍取类型与字节数。
                var type: DWORD = 0
                var bytes: DWORD = 0
                let query = RegQueryValueExW(
                    opened, nameBuffer.baseAddress, nil, &type, nil, &bytes
                )
                guard query == ERROR_SUCCESS, type == DWORD(REG_SZ), bytes > 0 else { return nil }
                var buffer = [WCHAR](repeating: 0, count: Int(bytes) / MemoryLayout<WCHAR>.size + 1)
                var actual = bytes
                let read = RegQueryValueExW(
                    opened, nameBuffer.baseAddress, nil, nil,
                    &buffer, &actual
                )
                guard read == ERROR_SUCCESS else { return nil }
                let units = buffer.prefix(Int(actual) / MemoryLayout<WCHAR>.size)
                return String(decoding: units.prefix(while: { $0 != 0 }), as: UTF16.self)
            }
        }
    }

    /// 删除值（键不必预存在）。值不存在也返回 true（幂等）。
    static func delete(subKeyPath: String, valueName: String) -> Bool {
        let subKey = wideString(subKeyPath)
        return subKey.withUnsafeBufferPointer { subKeyBuffer in
            var key: HKEY? = nil
            let status = RegOpenKeyExW(
                HKEY_CURRENT_USER, subKeyBuffer.baseAddress, 0,
                DWORD(KEY_SET_VALUE), &key
            )
            guard status == ERROR_SUCCESS, let opened = key else {
                // 键不存在 = 无状态可删，视为成功。
                return status == ERROR_FILE_NOT_FOUND
            }
            defer { RegCloseKey(opened) }
            let name = wideString(valueName)
            let result = name.withUnsafeBufferPointer { nameBuffer in
                RegDeleteValueW(opened, nameBuffer.baseAddress)
            }
            return result == ERROR_SUCCESS || result == ERROR_FILE_NOT_FOUND
        }
    }
}
#endif
