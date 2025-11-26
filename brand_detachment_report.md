# Motto Music 品牌彻底脱钩行动报告

## 1. 总体目标

在保留现有业务功能的前提下，将项目从 “LZF Music” 完整迁移为 "Motto Music"，确保任何终端用户界面、崩溃日志、通知、包签名、打包脚本及文档中均不再出现 "LZF" 字样或图标。迁移后，可无缝面向正式分发渠道，降低品牌混淆及版权风险。

---

## 2. 现状评估

### 2.1 Flutter / Dart 层
- ✅ Flutter 包名已更新为 `motto_music`，所有有效 Dart 源文件均改用 `package:motto_music/...`（备份及日志外无 `lzf_music` 残留）。
- ✅ `MaterialApp.title` 等展示字段已使用 Motto Branding；DevTools/堆栈中同步显示新包名。
- ⚠️ 仍需将 `LZF*` 命名的工具类、日志 Tag 全面替换（见 Step 4）。

### 2.2 平台显示名称 & 配置
- Android `android:label`、iOS `CFBundleName`、macOS `PRODUCT_NAME`、Linux `APPLICATION_ID`、Windows `Runner.rc`、`main.cpp`、Web `manifest.json` 均已更新，但部分构建脚本、打包元数据仍含旧字符串。
- 应用互斥量字符串/窗口 caption 的硬编码仍存在，如 `windows/runner/main.cpp` 等。

### 2.3 平台包标识
- Android: `com.example.lzf_music`，Kotlin 包路径 `com.example.lzf_music`。
- iOS/macOS: `Runner` 工程中 Bundle Identifier 与 Product Name 仍为 LZF。
- Windows/Mac/Linux：CMake、Runner 工程名称、应用 ID 等都引用 `lzf_music`。

### 2.4 图标与素材
- Android/iOS/macOS/Windows 图标已替换为 Motto 版本；但任何 `doc/images`、历史截图未清理仍可能显示旧 Logo。
- 托盘图标 `assets/windows/icons/tray_icon.ico`、`assets/icons/tray_icon.svg` 已更新，需确认后续生成流程沿用。

### 2.5 文档及仓库历史
- `README.md`、`doc/`、`历史文档/` 中大量 "LZF" 描述。
- Git 历史、Issue、Release 等仍为 LZF，若需对外完全脱钩需评估新的仓库或清理历史记录。

---

## 3. 脱钩步骤（建议按序执行）

### Step 1：确定新包名 & 命名规范（✅ 已完成）
- Flutter/Dart 包：`motto_music`（`pubspec.yaml`、`package_config.json` 已同步）。
- 平台命名空间：统一使用 `com.mottomusic.player`，Android/iOS/macOS/Windows/Linux/Web 的 manifest、CMake、Runner配置已对齐。
- 命名前缀：采用 `Motto*`（或 `MM*` 缩写）作为品牌前缀，例如 `MottoAudioHandler`、`MottoToast`，用于取代遗留的 `LZF*` 类型。

### Step 2：批量重命名 Flutter 包名（✅ 已完成）
- ✅ `pubspec.yaml:name` / `package_config.json` 同步为 `motto_music`，`flutter clean && flutter pub get` 后构建通过。
- ✅ 全局 `import 'package:lzf_music/...` → `package:motto_music/...`（含文档示例与历史备份文件），`rg -n \"lzf_music\" lib/*.dart` 无结果。
- ✅ 缓存示例文档 `lib/services/cache/USAGE.md`、归档文件 `global_search_page.dart.bak`、`audio_loader_service.dart.bak` 等已替换为 Motto 包路径，确保团队示例不再扩散旧前缀。

### Step 3：修改各平台包标识
- **Android**
  - `android/app/build.gradle.kts`: `namespace`、`applicationId` → `com.mottomusic.player`。
  - 目录 `android/app/src/main/kotlin/com/example/lzf_music` 重命名为 `com/mottomusic/player`，同步修改 `MainActivity.kt` 包声明。
  - `android/app/src/main/AndroidManifest.xml` 中任何 `com.example` 前缀清理。
- **iOS/macOS**
  - Xcode 中 Runner Target 的 Bundle Identifier → `com.mottomusic.player`。
  - `macos/Runner.xcodeproj`、`ios/Runner.xcodeproj` 的项目名称、Product Name、Team 设置调整。
- **Windows**
  - `windows/CMakeLists.txt`、`windows/runner/Runner.rc`、`windows/runner/main.cpp`、`windows/packaging/exe/make_config.yaml` 中 productName/companyName 修改。
- **Linux**
  - `linux/CMakeLists.txt` 与 Runner 代码中的 `BINARY_NAME` / `APPLICATION_ID` 改为 Motto。
- **Web**
  - `web/manifest.json`、`index.html` 中 `name`、`short_name`、`apple-mobile-web-app-title` 已更新，需检查缓存 manifest。

### Step 4：重命名含品牌前缀的类/日志
- 示例：`LZFAudioHandler`、`LZFDialog`、`LZFToast` 等。统一替换为 `MMAudioHandler` 或更泛化的命名。
- 所有日志 `debugPrint`、互斥量标识、Android `Mutex` 字符串、Windows `FindWindow` 的标题等等均需替换。

### Step 5：清理历史文档与展示材料
- `README.md`、`doc/`、`历史文档/` 等对外资料逐项检查，替换文本与截图。
- 若维护 changelog，需要在新的版本中明确指出品牌变更，便于用户知晓。

### Step 6：打包脚本与 CI/CD 更新
- 更新 `fastlane`、`Gradle`、`Xcode`、`Windows` 打包脚本中的包名与证书信息。
- 检查任何自动更新或 OTA 配置，确保新包名/ID 不影响分发。

### Step 7：验证与回归
- 执行 `flutter test`、平台构建（Android、iOS、macOS、Windows、Linux、Web）。
- 安装到真实设备（特别是曾暴露旧名称的平台）进行回归，确认：
  - 应用标题、通知栏、设置页显示均为 Motto。
  - 日志、崩溃堆栈、DevTools 中不再出现 `lzf_music`。
  - 所有图标与安装器界面使用最新素材。

### Step 8（可选）：仓库与分发渠道
- 若 GitHub/GitLab 仓库仍命名为 LZF，可新建 "motto-music" 仓库或重命名现有仓库并更新 README。
- 应用商店（Google Play、App Store、微软商店等）如已有上架版本，需要根据商店规则更新包名/签名或重新上架。

---

## 4. 风险与注意事项
- **包名/Bundle ID 变更** 会导致应用视为全新 App，旧版本无法直接升级，需要制定迁移策略（数据导入、用户提醒）。
- **证书/签名** 必须匹配新包名；Android 若换包名需重新生成 keystore 并按渠道要求配置。
- **历史日志/数据库** 中可能仍保留 LZF 字段，若对合法性有要求，可考虑数据库迁移脚本将旧值替换。
- **第三方依赖/接口** 如果以 LZF 命名，需要同步更新（例如 WebDAV 目录、后端接口等）。

---

## 5. 时间与资源估算
- **包名重命名 + 平台配置**：约 1~2 天（视平台数和 CI 流程而定）。
- **类名前缀与日志清理**：0.5~1 天（批量脚本 + 手动校验）。
- **文档和素材更新**：1 天左右（需校对、重新截图）。
- **测试与回归**：1~2 天（多平台验证）。
- 如需重新上架应用、配置证书，则额外安排 1~2 天。

---

## 6. 结论
目前项目在界面、图标层面已基本完成 Motto 化，但内部包名和大量类/日志仍使用 LZF。若希望彻底脱钩，必须执行一次全局重命名和文档清理，同时考虑包名变更带来的分发与升级影响。建议按本报告的步骤逐项推进，完成后再进行一次跨平台回归和文档审查，以确保对外展现完全统一。
