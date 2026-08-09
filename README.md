# DesktopPets

macOS 桌面宠物：一群会走动、会互动的桌面小精灵，常驻在菜单栏与桌面上。

- **平台**：macOS 13+（Swift 6 / SwiftPM / AppKit + Core Animation）
- **交互**：菜单栏 `🐾` 总台 + 桌面独立面板双控制入口
- **人物**：内置 12 个头像，支持导入本地照片裁剪为 512×512 头像，最多 8 个角色
- **渲染**：透明无激活边框窗口、形状感知点击穿透、确定性固定步长世界模拟

## 构建与测试

```bash
swift build -c release -Xswiftc -strict-concurrency=complete   # 严格并发 Release
swift test                                                      # 单元测试
swift test --sanitize=address                                   # 地址消毒器
```

> 注：若在嵌套沙箱环境中 `swift test` 报
> `sandbox-exec: sandbox_apply: Operation not permitted`，追加 SwiftPM 官方参数
> `--disable-sandbox` 即可（仅关闭 SwiftPM 自身的清单沙箱，不影响语义）。

## 目录结构

- `Sources/DesktopPets/App/` — 应用委托、窗口控制器、菜单栏
- `Sources/DesktopPets/Characters/` — 人物档案模型、roster 持久化
- `Sources/DesktopPets/Rendering/` — 程序化渲染与头像处理管线
- `Sources/DesktopPets/World/` — 确定性世界模拟与动作目录
- `Sources/DesktopPets/Platform/` — 窗口几何枚举、平台适配
- `Tests/` — 单元测试（含 ASan 覆盖）

## 数据与隐私

- 配置与头像持久化于 `~/Library/Application Support/DesktopPets/`
- 窗口几何仅通过 `CGWindowListCopyWindowInfo` 只读枚举，**不依赖**屏幕录制/辅助功能权限
- 头像导入本地标准化为 512×512 PNG，源文件受字节/像素上限约束

## 真人照片版权

`Sources/DesktopPets/Resources/Characters/Faces/` 下的四张人物照片**不属 MIT 许可**
范围，已获得照片本人的书面授权用于本应用，禁止在项目外复制/再分发。详见 `LICENSE`。

## 贡献

见 `CONTRIBUTING.md`。请确保所有改动附测试，并通过 `swift test --sanitize=address`
与严格并发 Release 构建。
