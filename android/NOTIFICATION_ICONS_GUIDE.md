# 通知栏图标替换指南

## 📋 当前状态

✅ **已完成：**
1. 创建了多密度 drawable 目录结构（mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi）
2. 从 audio_service 库复制了原始 PNG 图标到应用目录
3. 删除了之前错误命名的 `ic_notification_*.xml` 文件

⚠️ **待完成：**
- 将现有的 Vector Drawable 转换为 PNG 格式并替换

---

## 🎯 图标文件清单

需要替换的图标文件（每个密度都需要）：

| 文件名 | 用途 | 尺寸要求 |
|--------|------|---------|
| `audio_service_play_arrow.png` | 播放按钮 | mdpi: 24x24, hdpi: 36x36, xhdpi: 48x48, xxhdpi: 72x72, xxxhdpi: 96x96 |
| `audio_service_pause.png` | 暂停按钮 | 同上 |
| `audio_service_skip_next.png` | 下一首 | 同上 |
| `audio_service_skip_previous.png` | 上一首 | 同上 |

---

## 🔧 方法1：使用 Android Studio（推荐）

### 步骤：

1. **打开 Android Studio**
2. **右键点击** `app/src/main/res` 目录
3. **选择** `New > Image Asset`
4. **配置：**
   - Asset Type: `Notification Icons`
   - Name: `audio_service_play_arrow`（依次处理每个图标）
   - Icon Type: `Clip Art` 或 `Image`
   - 如果选择 Clip Art，搜索 `play arrow`
5. **调整：**
   - Padding: 0%
   - Trim: Yes
   - Color: White (#FFFFFF)
6. **点击 Next > Finish**
7. **重复** 以上步骤处理其他3个图标

### 图标对应关系：

| 文件名 | Android Studio Clip Art 名称 |
|--------|------------------------------|
| `audio_service_play_arrow.png` | `play arrow` |
| `audio_service_pause.png` | `pause` |
| `audio_service_skip_next.png` | `skip next` |
| `audio_service_skip_previous.png` | `skip previous` |

---

## 🔧 方法2：使用在线工具

### 工具推荐：
- **Android Asset Studio**: https://romannurik.github.io/AndroidAssetStudio/icons-notification.html

### 步骤：

1. **访问工具网站**
2. **上传或选择图标**
   - 可以使用项目中的 Vector Drawable 作为源
   - 或直接选择 Material Design 图标
3. **配置：**
   - Name: `audio_service_play_arrow`
   - Color: White
   - Padding: 0%
4. **下载生成的 ZIP 文件**
5. **解压并复制到项目：**
   ```
   解压后的文件结构：
   res/
   ├── drawable-mdpi/audio_service_play_arrow.png
   ├── drawable-hdpi/audio_service_play_arrow.png
   ├── drawable-xhdpi/audio_service_play_arrow.png
   ├── drawable-xxhdpi/audio_service_play_arrow.png
   └── drawable-xxxhdpi/audio_service_play_arrow.png
   
   复制到：
   LZF-Music/android/app/src/main/res/
   ```

---

## 🔧 方法3：手动转换（高级）

如果你有设计工具（如 Figma, Sketch, Illustrator）：

1. **导出 SVG** 从现有的 Vector Drawable
2. **在设计工具中打开**
3. **导出为 PNG**，按以下尺寸：
   - mdpi: 24x24 px
   - hdpi: 36x36 px
   - xhdpi: 48x48 px
   - xxhdpi: 72x72 px
   - xxxhdpi: 96x96 px
4. **确保：**
   - 背景透明
   - 图标颜色为白色 (#FFFFFF)
   - 文件名正确

---

## 📁 源 Vector Drawable 参考

项目中已有的 Vector Drawable 可作为参考：

```xml
<!-- 播放按钮 -->
<path android:pathData="M8,6.82v10.36c0,0.79 0.87,1.27 1.54,0.84l8.14,-5.18c0.62,-0.39 0.62,-1.29 0,-1.69L9.54,5.98C8.87,5.55 8,6.03 8,6.82z" />

<!-- 暂停按钮 -->
<path android:pathData="M8,19c1.1,0 2,-0.9 2,-2V7c0,-1.1 -0.9,-2 -2,-2s-2,0.9 -2,2v10C6,18.1 6.9,19 8,19zM14,7v10c0,1.1 0.9,2 2,2s2,-0.9 2,-2V7c0,-1.1 -0.9,-2 -2,-2S14,5.9 14,7z" />

<!-- 上一首 -->
<path android:pathData="M10.95,18l-6.49,-4.68c-0.61,-0.44 -0.61,-1.39 0,-1.83L10.95,7c0.69,-0.5 1.66,-0.02 1.66,0.83v9.34C12.61,18.02 11.64,18.5 10.95,18zM19.45,18l-6.49,-4.68c-0.61,-0.44 -0.61,-1.39 0,-1.83L19.45,7c0.69,-0.5 1.66,-0.02 1.66,0.83v9.34C21.11,18.02 20.14,18.5 19.45,18z" />

<!-- 下一首 -->
<path android:pathData="M5.58,16.89l5.77,-4.07c0.56,-0.4 0.56,-1.24 0,-1.63L5.58,7.11C4.91,6.65 4,7.12 4,7.93v8.14C4,16.88 4.91,17.35 5.58,16.89zM13,7.93v8.14c0,0.81 0.91,1.28 1.58,0.82l5.77,-4.07c0.56,-0.4 0.56,-1.24 0,-1.63l-5.77,-4.07C13.91,6.65 13,7.12 13,7.93z" />
```

---

## ✅ 验证替换成功

替换完成后，运行以下命令验证：

```bash
cd F:\bilibili_player\LZF-Music\android\app\src\main\res
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  echo "=== drawable-$density ==="
  ls -lh "drawable-$density"/audio_service_*.png
done
```

或在 PowerShell 中：

```powershell
Get-ChildItem -Path "F:\bilibili_player\LZF-Music\android\app\src\main\res\drawable-*dpi" -Filter "audio_service_*.png" | Format-Table Directory, Name, Length
```

---

## 🎨 设计规范

确保新图标符合以下规范：

- **风格：** Material Design 圆角风格
- **颜色：** 纯白色 (#FFFFFF)
- **背景：** 完全透明
- **内边距：** 无内边距（图标填满画布）
- **格式：** PNG-8 或 PNG-24，带 Alpha 通道

---

## 🔍 工作原理

Android 资源加载机制：

1. 应用运行时，`audio_service` 插件请求 `drawable/audio_service_play_arrow`
2. Android 系统首先在**应用的包**中查找该资源
3. 如果找到，使用应用中的资源（✅ 我们的自定义图标）
4. 如果未找到，回退到 `audio_service` 库中的默认资源

**因此，只要应用中有同名资源，就会自动覆盖库中的默认图标。**

---

## 📝 注意事项

1. **不要修改文件名**：必须保持 `audio_service_*.png` 的命名
2. **不要删除任何密度**：所有5个密度目录都需要对应的图标
3. **保持尺寸比例**：各密度的尺寸必须符合 Android 规范
4. **清理构建缓存**：替换后运行 `flutter clean` 和 `flutter pub get`

---

## 🚀 完成后的测试

1. **编译应用**：`flutter build apk` 或在 Android Studio 中运行
2. **安装到设备**
3. **播放音乐**
4. **下拉通知栏**
5. **验证图标是否为新的圆角风格**

---

## 📞 需要帮助？

如果遇到问题，检查：
- 文件名是否正确
- 文件是否在正确的目录
- 图标尺寸是否符合规范
- 是否清理了构建缓存
