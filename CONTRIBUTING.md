# 贡献指南

感谢你考虑为 Motto Music 做出贡献！🎉

我们欢迎任何形式的贡献，包括 Bug 反馈、新特性提案、代码改进、文档完善和 UI 设计建议。

## 📋 行为准则

参与本项目即表示你同意遵守我们的[行为准则](CODE_OF_CONDUCT.md)。请务必阅读并理解其内容。

## 🚀 如何贡献

### 报告 Bug

如果你发现了 Bug，请：

1. 在 [Issues](https://github.com/motto1/motto-music/issues) 中搜索，确认问题尚未被报告
2. 使用 Bug 报告模板创建新 Issue
3. 提供详细的复现步骤、期望行为和实际行为
4. 附上设备信息、系统版本、应用版本等环境信息
5. 如可能，提供截图、日志或错误堆栈信息

### 提出新功能

如果你有新功能建议，请：

1. 在 [Issues](https://github.com/motto1/motto-music/issues) 中搜索，确认功能尚未被提出
2. 使用功能请求模板创建新 Issue
3. 清晰描述功能的使用场景和预期收益
4. 如可能，提供 UI 设计稿或交互流程说明

### 提交代码

#### 前置准备

1. **Fork 本仓库**到你的 GitHub 账号
2. **克隆你的 Fork**到本地：
   ```bash
   git clone https://github.com/你的用户名/motto-music.git
   cd motto-music
   ```
3. **配置开发环境**：
   - 安装 Flutter >= 3.3（推荐使用最新 stable channel）
   - 运行 `flutter pub get` 安装依赖
   - 确认能成功运行：`flutter run -d <设备ID>`

#### 开发流程

1. **创建新分支**：
   ```bash
   git checkout -b feat/my-feature
   # 或
   git checkout -b fix/issue-123
   ```

2. **编写代码**：
   - 遵循项目现有的代码风格
   - 保持代码简洁、可读性强
   - 为复杂逻辑添加必要的注释
   - 确保新功能与现有架构一致

3. **提交前检查**：
   ```bash
   # 格式化代码
   flutter format .
   
   # 运行静态分析
   flutter analyze
   
   # 运行测试（如有）
   flutter test
   
   # 确认应用可正常构建和运行
   flutter run
   ```

4. **提交代码**：
   - 使用清晰的提交信息，遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范
   - 提交信息示例：
     ```
     feat(bilibili): 支持自定义下载目录
     fix(player): 修复锁屏界面进度条不更新的问题
     docs(readme): 更新安装说明
     refactor(cache): 优化 LRU 缓存清理逻辑
     ```

5. **推送到你的 Fork**：
   ```bash
   git push origin feat/my-feature
   ```

6. **创建 Pull Request**：
   - 前往原仓库的 [Pull Requests](https://github.com/motto1/motto-music/pulls) 页面
   - 点击 "New Pull Request"
   - 选择你的分支并填写 PR 模板
   - 确保 PR 标题清晰描述改动内容
   - 在描述中关联相关 Issue（如 `Fixes #123`）

#### PR 要求

提交 PR 前，请确认：

- [ ] 代码已通过 `flutter format` 格式化
- [ ] 代码已通过 `flutter analyze` 静态分析
- [ ] 已在至少一个平台上测试过改动
- [ ] 如添加新功能，已更新相关文档
- [ ] 如修复 Bug，已在 PR 描述中说明复现步骤和修复方案
- [ ] 提交信息遵循 Conventional Commits 规范
- [ ] 未包含敏感信息（API 密钥、个人隐私数据等）
- [ ] 未提交编译产物（build/ 目录等已被 .gitignore 排除）

## 💡 开发建议

### 代码风格

- **使用 Flutter 官方推荐的代码风格**
- **优先使用 Dart 3 的新特性**（如 Records、Pattern Matching）
- **保持函数和类的单一职责**
- **避免过度嵌套**，善用提前返回和辅助函数
- **使用有意义的变量和函数名**，避免缩写

### 架构原则

- **Service 层**：业务逻辑封装在 `lib/services/` 中，保持可测试性
- **Provider 模式**：状态管理使用 Provider，避免过度依赖全局状态
- **Drift 数据库**：数据持久化遵循现有 Drift 表结构设计
- **平台适配**：跨平台差异通过 `lib/platform/` 统一处理

### 测试

虽然当前测试覆盖率有限，但我们鼓励为新功能编写测试：

```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/services/bilibili_service_test.dart
```

## 📚 资源

- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 语言指南](https://dart.dev/guides)
- [项目技术栈说明](README.md#-技术栈)
- [项目结构说明](README.md#-项目结构速览)

## 🤝 社区

- **Discussions**：用于功能讨论、问题求助、分享经验
- **Issues**：用于 Bug 反馈和功能请求
- **Pull Requests**：用于代码贡献

## ❓ 需要帮助？

如果你在贡献过程中遇到任何问题，可以：

1. 在 [Discussions](https://github.com/motto1/motto-music/discussions) 中提问
2. 查看现有 Issues 中的相关讨论
3. 在 PR 中 @项目维护者 寻求帮助

---

再次感谢你的贡献！🎵 让我们一起让 Motto Music 变得更好！
