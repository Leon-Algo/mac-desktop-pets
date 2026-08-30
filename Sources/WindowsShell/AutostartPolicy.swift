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
                    RegSetValueExW(
                        opened,
                        nameBuffer.baseAddress,
                        0,
                        UINT(REG_SZ),
                        valueBuffer.baseAddress?.assumingMemoryBound(to: BYTE.self),
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
#endif
