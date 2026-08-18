# Release-Readiness 路线图（剩余待办方案）

日期：2026-08-09
状态：规划（plan）｜ 基于 `docs/verification/final-acceptance.md`（2026-08-03，功能验收全 PASS）
背景：自定义人物档案特性已合并回 `main`（fbdc419），122/122 测试 + ASan + 严格并发 Release 全绿。
本方案整理"从功能完成到可发布/可交付"的剩余待办，按 P0→P3 排序，每项含范围、排除项、验收方式、是否阻塞发布。

---

## 现状基线（已完成，勿重复）

- 功能验收：`final-acceptance.md` 矩阵全 PASS（roster / 渲染 / 行为 / 窗口 / 动作中心 / 交互 / 稳定性 / 并发 / 隐私）。
- 测试：122/122 单测、122/122 ASan、严格并发 Release 通过。
- 开源脚手架：`LICENSE`（MIT + 真人照片条款）、`README`、`CONTRIBUTING`、GitHub Actions CI 已就位。
- 真人照片：已获本人书面授权，边界写入 `LICENSE`。

> 唯一明确"未执行"的验收项：**Public distribution（Developer ID 签名 + 公证）**——见下方 P0-1。

---

## P0 — 发布硬门槛（不完成不可对外分发）

### P0-1 开发者证书与公证（Developer ID + Notarization）
- 现象：`final-acceptance.md` 标注 "The machine has no Developer ID identity… ad-hoc signed for local use"。
- 影响：当前 `build/DesktopPets.app` 为 ad-hoc 签名，用户安装会触发 Gatekeeper 拦截，无法对外分发。
- 范围：
  1. 申请/配置 Apple Developer ID Application 证书（需开发者账号）。
  2. `codesign --options runtime --entitlements` 对 app 签名。
  3. `notarytool submit` 公证 + `stapler staple`。
  4. 新增 CI 或脚本 `Scripts/notarize.sh` 固化流程。
- 排除项：不涉及任何功能代码改动。
- 验收：`spctl -a -vv build/DesktopPets.app` 返回 `accepted`；公证状态 `stapled`。
- 阻塞发布：**是**。
- 前置：需用户提供开发者账号 / Apple 证书（本轮无凭据）。

### P0-2 发布产物与版本化
- 范围：
  1. 引入版本号（如 `CFBundleShortVersionString` 1.0.0 + build number），避免"无版本"发布。
  2. 打包脚本（DMG 或 zip）与校验和；产物命名含版本号。
- 验收：产物可安装、`codesign --verify --deep --strict` 通过、版本号正确。
- 阻塞发布：**是**（建议与 P0-1 同批完成）。

---

## P1 — 发布前必备（强烈建议，否则体验/安全打折扣）

### P1-1 实机冒烟与多环境验证
- 现象：`final-acceptance` 的实机项为 2026-08-03 单机结果；多屏 / 刘海 / Stage Manager / 长时运行本轮未复测。
- 范围：在 ≥2 台不同分辨率/多屏机器跑 `Scripts/smoke-test.sh` 自检（1/4/8 人、5 窗口、14 命令、`windowCount`/`petWindowCount`）；长时运行 ≥4h 观察 CPU/RSS 稳定性。
- 排除项：不改代码，仅记录。
- 验收：输出记录到 `docs/verification/`，矩阵对应项标记复测日期与机器。
- 阻塞发布：建议（对外分发前至少 1 台真实多屏复测）。

### P1-2 无障碍（VoiceOver / 全键盘导航）实测
- 现象：代码有 3 处 `accessibilityLabel`、快捷键 p/h/r/,/d/q；但 VoiceOver 与全键盘导航为文档声称、无实测。
- 范围：VoiceOver 朗读菜单/面板标题、Tab 焦点可达性、快捷键覆盖测试。
- 验收：新增/更新 `docs/verification/accessibility.md`，记录实测路径与通过项。
- 阻塞发布：否（MVP 可后补，但建议发布前过一遍）。

### P1-3 本地化骨架
- 现象：全部 UI 文案硬编码中文，无 `.lproj`、无 `NSLocalizedString`。
- 影响：当前无多语言需求则非阻塞；但为将来本地化铺路。
- 范围：引入 `NSLocalizedString` 包裹关键菜单/面板文案 + 中文 `.lproj`，行为零变化。
- 验收：`swift test` 仍全绿；文案可提取。
- 阻塞发布：否。

---

## P2 — 质量增强（不阻塞发布，但提升健壮性/可维护性）

### P2-1 长时运行压力与资源基线
- 范围：`final-acceptance` 已报 5–6% CPU / 54MB RSS；本轮补充 ≥4h 长时日志与 8 人满载基线。
- 验收：`docs/verification/resource-baseline.md` 记录数据曲线。

### P2-2 CI 落库与分支保护
- 范围：`.github/workflows/ci.yml` 已建；接入远端仓库后启用分支保护（main 仅 PR 合并 + 必须 CI 通过）。
- 验收：远端 PR 合并时 CI 门禁生效。

### P2-3 自动化冒烟纳入 CI（可选）
- 范围：若 `smoke-test.sh` 可在无头 CI 运行，纳入 CI 步骤；否则保留本地。

---

## P3 — 产品方向（后续迭代，与发布无关）

### P3-1 动画升级（骨骼动画评估）
- 现象：`ProceduralPetRenderer` 为程序化绘制（crawl/jump/turn…），非骨骼动画。
- 方向：评估引入骨骼/关键帧系统或 Spine 类方案，提升动作表现力。
- 验收：先出对比方案文档，不直接改代码。

### P3-2 动作与反馈扩展
- 范围：扩展 `PetActionCatalog` 动作、更丰富的反馈气泡/音效（当前 `callDad` 无音频）。
- 方向：产品需求驱动，先列需求清单。

### P3-3 多语言发布
- 范围：在 P1-3 本地化骨架之上，补充英文等 `lproj`。
- 前置：P1-3。

---

## 依赖关系

```
P0-1 (签名公证) ──┬──> P0-2 (版本化打包) ──> 可对外分发
                  └──> P1-1 (多屏复测，建议)
P1-3 (本地化骨架) ──> P3-3 (多语言)
P2-2 (CI 分支保护) ── 依赖远端仓库接入
```

## 推荐执行顺序（首个开发任务）

**P1-3 本地化骨架**——理由：
1. 纯开发、无需 Apple 证书/凭据（P0-1/P0-2 被凭据阻塞，只能等用户提供）。
2. 改动面小、可 TDD、行为零变化，风险低。
3. 为 P3-3 多语言铺路，长期价值明确。

> 若用户希望优先"能发布"，则首任务改为等待凭据后执行 **P0-1 签名公证**；但该任务无法在本轮凭据缺失下开始，故推荐先做 P1-3。

### 首个任务范围（P1-3）
- 文件：`Sources/DesktopPets/App/StatusMenuController.swift`、`CharacterSettingsWindowController.swift`、`AppController.swift`（含硬编码文案处）。
- 方法：`NSLocalizedString("key", comment:)` + 新建 `zh-Hans.lproj/Localizable.strings`。
- 排除：不改 UI 布局 / 行为 / 逻辑。
- TDD：文案可提取性 + 既有测试全绿；新增 1 项 Localizable 资源存在性测试。
- 优先级理由：可立即开工、低风险、为多语言铺路、不被凭据阻塞。
