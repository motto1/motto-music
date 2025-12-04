# 通知栏图标生成工具

## 🎯 快速开始（3步完成）

### 步骤1：生成图标

1. **双击打开** `generate_icons.html` 文件（会在浏览器中打开）
2. **点击** "下载所有密度的图标" 按钮
3. **等待** 浏览器自动下载 20 个 PNG 文件（约需 5-10 秒）

下载的文件会保存在浏览器的默认下载目录，文件名格式：
```
play_arrow_mdpi.png
play_arrow_hdpi.png
play_arrow_xhdpi.png
...
```

### 步骤2：移动文件

将下载的所有 PNG 文件移动到当前目录（`icons_source` 文件夹）

### 步骤3：自动安装

在 PowerShell 中运行：
```powershell
cd F:\bilibili_player\LZF-Music\android\icons_source
.\install_icons.ps1
```

脚本会自动：
- 重命名文件（添加 `audio_service_` 前缀）
- 复制到对应的 `drawable-*dpi` 目录
- 显示安装结果

---

## 📁 文件说明

| 文件 | 用途 |
|------|------|
| `generate_icons.html` | 浏览器图标生成器（主工具） |
| `install_icons.ps1` | 自动安装脚本 |
| `*.svg` | SVG 源文件（备用） |
| `README.md` | 本说明文档 |

---

## 🔧 手动安装（如果自动脚本失败）

如果自动脚本无法运行，可以手动复制：

### 文件映射表

| 下载的文件 | 复制到 | 重命名为 |
|-----------|--------|---------|
| `play_arrow_mdpi.png` | `drawable-mdpi/` | `audio_service_play_arrow.png` |
| `play_arrow_hdpi.png` | `drawable-hdpi/` | `audio_service_play_arrow.png` |
| `play_arrow_xhdpi.png` | `drawable-xhdpi/` | `audio_service_play_arrow.png` |
| `play_arrow_xxhdpi.png` | `drawable-xxhdpi/` | `audio_service_play_arrow.png` |
| `play_arrow_xxxhdpi.png` | `drawable-xxxhdpi/` | `audio_service_play_arrow.png` |
| `pause_mdpi.png` | `drawable-mdpi/` | `audio_service_pause.png` |
| `pause_hdpi.png` | `drawable-hdpi/` | `audio_service_pause.png` |
| ... | ... | ... |

对 `skip_next` 和 `skip_previous` 重复相同操作。

---

## ✅ 验证安装

运行验证脚本：
```powershell
cd F:\bilibili_player\LZF-Music\android
.\verify_icons.ps1
```

应该看到所有图标都显示 ✅

---

## 🎨 图标预览

生成器页面会显示所有图标的预览，确保它们是正确的 Material Design 圆角风格。

---

## 🚀 完成后

1. **清理构建缓存：**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **重新编译：**
   ```bash
   flutter build apk
   ```

3. **测试：**
   - 安装应用到设备
   - 播放音乐
   - 下拉通知栏
   - 检查图标是否为新的圆角风格

---

## ❓ 常见问题

### Q: 浏览器没有自动下载文件？
A: 检查浏览器的下载设置，确保允许自动下载多个文件。

### Q: PowerShell 脚本无法运行？
A: 以管理员身份运行 PowerShell，或使用：
```powershell
powershell -ExecutionPolicy Bypass -File install_icons.ps1
```

### Q: 图标显示不正确？
A: 确保：
1. 文件名完全正确（包括 `audio_service_` 前缀）
2. 文件在正确的密度目录中
3. 已运行 `flutter clean`

---

## 📞 需要帮助？

如果遇到问题，请检查：
1. 浏览器控制台是否有错误信息
2. PowerShell 脚本的输出信息
3. 文件权限是否正确
