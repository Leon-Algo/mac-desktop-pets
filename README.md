# DesktopPets

macOS 桌面宠物：一群会走动、会互动的桌面小精灵，常驻在菜单栏与桌面上。

- **平台**：macOS 13+（Swift 6 / SwiftPM / AppKit + Core Animation）
- **交互**：菜单栏 `🐾` 总台 + 桌面独立面板双控制入口
- **人物**：内置 12 个头像，支持导入本地照片裁剪为 512×512 头像，最多 8 个角色
- **渲染**：透明无激活边框窗口、形状感知点击穿透、确定性固定步长世界模拟

![DesktopPets 效果预览](docs/assets/deskpet.png)

*动态效果：*

![deskpet1](docs/assets/deskpet1.gif)
![deskpet2](docs/assets/deskpet2.gif)

> 上图：桌面动态效果与人物设置界面。录屏见 [Releases](https://github.com/Leon-Algo/mac-desktop-pets/releases) 页面。

## 构建与测试

```bash
swift build -c release -Xswiftc -strict-concurrency=complete   # 严格并发 Release
swift test                                                      # 单元测试
swift test --sanitize=address                                   # 地址消毒器
```

> 注：若在嵌套沙箱环境中 `swift test` 报
> `sandbox-exec: sandbox_apply: Operation not permitted`，追加 SwiftPM 官方参数
> `--disable-sandbox` 即可（仅关闭 SwiftPM 自身的清单沙箱，不影响语义）。

## 安装

### 方式一：下载 DMG（推荐普通用户）
1. 到 [Releases](https://github.com/Leon-Algo/mac-desktop-pets/releases) 下载 `DesktopPets.dmg`
2. 打开 DMG，把 `DesktopPets.app` 拖入 `Applications`
3. 首次打开若被 Gatekeeper 拦截（提示「无法验证开发者」），任选一种解除方式：
   - 右键 `DesktopPets.app` → 「打开」；或
   - 终端执行 `sudo xattr -dr com.apple.quarantine /Applications/DesktopPets.app`

> 本项目采用**路线 B 免费分发**：未做 Developer ID 签名与公证，因此首次打开会出现上述提示，属正常行为，不影响使用。

### 方式二：源码编译（开发者）
本地编译的 app 不受 quarantine 隔离限制，无需解除：

```bash
git clone https://github.com/Leon-Algo/mac-desktop-pets.git
cd mac-desktop-pets
swift build -c release
swift run -c release
```

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
