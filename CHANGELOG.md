# 更新日志

本文档记录了 Motto Music 的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 计划中
- UI 风格统一：统一多个页面的风格一致性，修复 BUG
- 歌词体验优化：歌词翻译多行显示、更多歌词源、可视化偏移调节
- 模块化配置：支持备份配置、导入导出
- Bilibili 接入：点赞、三连、收藏夹控制
- 性能优化：启动速度优化、内存占用优化、流畅度提升
- 播放增强：均衡器、音效、淡入淡出、定时停止

## [0.1.0-beta] - 2025-12-01

### 说明
本版本为项目的首个 **Beta 公开版本**，重新定位版本号为 `0.1.0`，标志着项目进入测试阶段。

### 核心功能
- ✅ Bilibili 音源支持（登录、收藏夹、下载管理、音质选择）
- ✅ 本地音乐文件支持（自动元数据读取）
- ✅ 智能歌词系统（LRC/TTML 解析，网易云 API 搜索，偏移调整）
- ✅ Apple Music 风格播放器界面
- ✅ 锁屏界面与歌词滚动支持
- ✅ 通知栏播放控制（audio_service + just_audio）
- ✅ 自定义下载目录与缓存管理
- ✅ 后台下载（可调并发、断点续传、LRU 缓存）

### 技术栈
- Flutter 3.3+ / Dart 3（仅支持 Android 平台）
- Drift + sqlite3_flutter_libs（本地数据库）
- audio_service + just_audio（音频播放引擎）
- Bilibili API 集成
- 模块化 Service 架构

### 项目信息
- 完整的开源文档（README、CONTRIBUTING、CODE_OF_CONDUCT、SECURITY）
- GitHub Issue 和 PR 模板
- Apache License 2.0 开源许可

### 致谢
本项目借鉴了以下优秀开源项目的经验和代码：
- [namida](https://github.com/namidaco/namida)
- [BBPlayer](https://github.com/bbplayer-app/BBPlayer)
- [LZF-Music](https://github.com/GerryDush/LZF-Music)
- [Metro](https://github.com/MuntashirAkon/Metro)

感谢 linuxdo 社区的优秀服务商和公益站的支持。

---

## 版本说明

- **[Unreleased]**：开发中的功能
- **[0.1.0-beta]**：当前 Beta 测试版本

### 类型定义

- **新增**：新功能
- **改进**：对现有功能的改进
- **修复**：Bug 修复
- **废弃**：即将移除的功能
- **移除**：已移除的功能
- **安全**：安全相关的修复

[Unreleased]: https://github.com/motto1/motto-music/compare/v0.1.0-beta...HEAD
[0.1.0-beta]: https://github.com/motto1/motto-music/releases/tag/v0.1.0-beta
