# Motto Music

Motto Music 是一款基于 Flutter 开发的 **Android 音乐播放器**，专为"本地收藏 + Bilibili 音源"使用场景设计。项目目标是提供稳定、可定制、开箱即用的音乐体验。

> **注意**：本项目目前仅适配 Android 平台，暂无其他平台支持计划。

---

## ✨ 特色能力

| 能力 | 说明 |
| --- | --- |
| 🎧 双源音频 | 支持本地音乐文件和 Bilibili 音源，统一管理与播放 |
| 🧠 智能歌词 | 自动解析 LRC/TTML 格式，内置歌词搜索、偏移调整与手动导入 |
| 🖼️ 现代播放器 | Apple Music 风格界面、动态封面、流畅动画与直观控制 |
| 🔒 锁屏控制 | 精美的锁屏界面，支持歌词滚动和全功能播放控制 |
| 📂 灵活存储 | 自定义 Bilibili 下载目录，默认 `Music/MottoMusic/Bilibili` |
| 🔁 智能下载 | 可调并发、仅 Wi-Fi 下载、LRU 缓存管理、断点续传 |
| 🧩 模块化架构 | Service 层设计，便于扩展和维护 |

---

## 🏗️ 技术栈

- **Flutter 3.3+ / Dart 3**：UI 渲染、状态管理与路由
- **Drift + sqlite3_flutter_libs**：本地数据库（歌曲、下载、设置等）
- **audio_service + just_audio**：音频播放与通知栏/锁屏控制
- **Dio / connectivity_plus / permission_handler**：网络请求、连接检测与权限管理
- **cached_network_image / flutter_cache_manager**：图片和音频缓存
- **自建 Service 模块**：`bilibili`、`lyrics`、`cache`、`player` 等模块化服务

---

## 📁 项目结构速览

```
lib/
├─ services/            # 业务服务（Bilibili、歌词、缓存、下载、播放器等）
├─ views/               # 页面（Settings、Library、Bilibili 相关等）
├─ widgets/             # 复用组件（歌词工具、播放器控件、对话框等）
├─ models/              # 数据模型（Drift 数据类、Lyrics、Download 事件等）
├─ database/            # Drift 定义及适配层
├─ platform/            # 桌面 & 移动平台增强能力
└─ utils/               # 通用工具（主题、解析、路径处理等）
```

---

## 🚀 快速开始

### 1. 环境要求

- Flutter >= 3.3（推荐使用最新 stable channel）
- Dart >= 3.3
- Android SDK（API 21+）
- Git（用于拉取/提交代码）

### 2. 克隆仓库

```bash
git clone https://github.com/motto1/motto-music.git
cd motto-music
flutter pub get
```

### 3. 运行 / 构建

```bash
# 连接 Android 设备或启动模拟器后运行
flutter run

# 构建 APK 安装包
flutter build apk --split-per-abi

# 构建 App Bundle（推荐用于发布）
flutter build appbundle
```

> **提示**：首次运行会在设备的 Music 目录创建 `MottoMusic` 文件夹，用于存储 Bilibili 下载内容。

---

## ⚙️ Bilibili 设置与下载管理

1. 进入 **设置 > Bilibili 设置**
2. 点击"下载目录"即可直接跳转到当前目录
   - 默认路径：`/storage/emulated/0/Music/MottoMusic/Bilibili`
3. 长按"下载目录"可选择新的保存路径
4. 支持的下载特性：
   - 可调并发数（默认 3，最大 5）
   - 仅 Wi-Fi 下载选项
   - 断点续传与自动重试
   - 失败恢复与任务管理

---

## 🛣️ Roadmap

- [ ] **Bilibili 功能增强**：多账号支持、播放历史同步、智能推荐
- [ ] **歌词体验优化**：逐字歌词支持、歌词翻译、更多歌词源
- [ ] **播放列表管理**：智能播放列表、收藏夹分组、导入导出
- [ ] **UI 主题定制**：自定义主题颜色、字体、布局
- [ ] **性能优化**：启动速度优化、内存占用优化、流畅度提升
- [ ] **播放增强**：均衡器、音效、淡入淡出、定时停止

欢迎通过 Issue/Discussions 提交新的功能建议。

---

## 🤝 贡献指南

1. Fork 仓库并创建分支：`git checkout -b feat/my-feature`
2. 提交前运行 `flutter format` 与必要的 `flutter test`
3. 提交信息遵循 Conventional Commits，示例：`feat(bilibili): support custom download directory`
4. 提交 PR 前请确认：
   - 新增/更新文档
   - 包含必要的截图 / 日志 / 复现步骤
   - 未引入敏感信息、未提交编译产物

我们欢迎任何形式的贡献，包括 Bug 反馈、新特性提案和 UI 设计建议。

---

## 📄 许可证

本项目基于 **Apache License 2.0** 开源。详见 [LICENSE](LICENSE)。

---

## 🙏 致谢

- Flutter / Dart 官方团队与社区
- audio_service、just_audio、drift 等优秀开源项目
- 社区贡献者与早期内测用户提供的反馈

---

> 准备好让 Motto Music 成为你的私人音乐枢纽了吗？Fork 项目、Star 支持、分享给更多音频爱好者吧！
