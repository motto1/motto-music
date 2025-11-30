# 更新日志

本文档记录了 Motto Music 的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 计划中
- WebDAV / 私人云完善
- Bilibili 账号多端联动
- 可插拔歌词/音源 Provider
- UI 主题编辑器

## [0.2.6] - 2025-11-30

### 新增
- 完整的开源项目文档（CONTRIBUTING.md、CODE_OF_CONDUCT.md、SECURITY.md）
- GitHub Issue 和 PR 模板

### 改进
- 优化 README.md 结构和内容
- 完善项目描述和技术栈说明

## [0.2.5] - 之前版本

### 核心功能
- ✅ 多源音频支持（本地文件 + Bilibili 音源）
- ✅ 跨平台支持（Windows / macOS / Linux / Android / iOS）
- ✅ 智能歌词系统（自动解析 LRC/TTML，内置搜索和偏移工具）
- ✅ Apple Music 风格播放器界面
- ✅ 自定义下载目录配置
- ✅ 后台下载与自动缓存
- ✅ Bilibili 登录、收藏夹、下载管理
- ✅ 通知栏播放控制（audio_service + just_audio）
- ✅ 锁屏界面优化

### 技术架构
- Flutter 3.3+ / Dart 3
- Drift 数据库层
- audio_service + just_audio 播放引擎
- 模块化 Service 架构

---

## 版本说明

- **[Unreleased]**：开发中的功能
- **[0.2.6]**：当前最新版本
- **[0.2.5]**：核心功能版本

### 类型定义

- **新增**：新功能
- **改进**：对现有功能的改进
- **修复**：Bug 修复
- **废弃**：即将移除的功能
- **移除**：已移除的功能
- **安全**：安全相关的修复

[Unreleased]: https://github.com/motto1/motto-music/compare/v0.2.6...HEAD
[0.2.6]: https://github.com/motto1/motto-music/releases/tag/v0.2.6
[0.2.5]: https://github.com/motto1/motto-music/releases/tag/v0.2.5
