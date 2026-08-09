# Contributing

欢迎参与 DesktopPets 的开发。请遵循以下约定：

## 工作流

1. 从 `main` 拉取最新，新建功能分支：`git checkout -b feat/<short-name>`。
2. 以 **TDD** 方式开发：先写失败测试 → 实现 → 转绿。
3. 提交信息遵循仓库既有风格（`feat:` / `fix:` / `docs:` / `refactor:`）。
4. 合并回 `main` 前必须通过下方全部验证。

## 必须通过的验证

```bash
swift test                                # 全量单测
swift test --sanitize=address             # 地址消毒器
swift build -c release -Xswiftc -strict-concurrency=complete   # 严格并发 Release
```

## 代码约定

- 目标 `macOS 13+`，Swift 6 严格并发；`@MainActor` 用于 UI 边界。
- 新功能必须附测试；涉及文件/权限的操作需考虑失败路径与安全（见头像导入上限）。
- 不引入外部依赖，除非在 Issue 中先达成共识。

## 真人照片

`Resources/Characters/Faces/` 下的真人照片已获本人授权，仅限本应用使用。
**不要**复制、上传、或将其作为开源素材再分发。
