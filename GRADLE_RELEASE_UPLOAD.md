# Gradle 依赖上传指南

## 📦 需要上传的文件

文件已准备好在项目根目录：
```
gradle-8.12-all.zip  (219 MB)
```

## 🚀 上传步骤

### 1. 创建 Release Tag

在 GitHub 仓库创建一个专门用于存放构建依赖的 Release：

```bash
git tag gradle-deps -m "Gradle and build dependencies"
git push origin gradle-deps
```

### 2. 上传到 Release

方式一：**使用 GitHub Web 界面**（推荐）

1. 访问 https://github.com/motto1/motto-music/releases
2. 点击 "Draft a new release"
3. 选择标签：`gradle-deps`（如果不存在就创建）
4. Release 标题：`Gradle and Build Dependencies`
5. 描述：
   ```
   ## 构建依赖文件
   
   此 Release 用于存放 CI/CD 构建所需的依赖文件：
   
   - `gradle-8.12-all.zip` - Gradle 8.12 完整发行版
   
   **用途**：GitHub Actions 构建时从此处下载 Gradle，避免网络限制问题。
   ```
6. 上传文件：将 `gradle-8.12-all.zip` 拖放到文件上传区
7. 点击 "Publish release"

方式二：**使用 GitHub CLI**

```bash
# 安装 GitHub CLI (如果还没安装)
# Windows: winget install GitHub.cli

# 创建 Release 并上传文件
cd f:\bilibili_player\LZF-Music
gh release create gradle-deps gradle-8.12-all.zip \
  --title "Gradle and Build Dependencies" \
  --notes "构建依赖文件，用于 GitHub Actions CI/CD"
```

### 3. 验证上传

上传完成后，验证文件可以访问：

```bash
# 应该返回 200 OK
curl -I https://github.com/motto1/motto-music/releases/download/gradle-deps/gradle-8.12-all.zip
```

## ✅ Workflow 配置

Workflow 已经配置好从 Release 下载 Gradle：

- 如果 Gradle 缓存命中，直接使用缓存（快速）
- 如果缓存未命中，从 GitHub Release 下载（可靠）
- 下载后会缓存到 `~/.gradle/wrapper`，后续构建会复用

## 🔧 更新 Gradle 版本

如果将来需要升级 Gradle 版本：

1. 找到新版本的 Gradle zip 文件（通常在 `~/.gradle/wrapper/dists/` 下）
2. 上传到同一个 `gradle-deps` Release
3. 更新 `android/gradle/wrapper/gradle-wrapper.properties`
4. 更新 `.github/workflows/android-build.yml` 中的下载 URL

## 📊 预期效果

- ✅ **完全自主可控** - 不依赖外部镜像源
- ✅ **下载速度极快** - GitHub Actions 访问同仓库 Release 速度很快
- ✅ **永久可用** - 不会因为第三方服务问题导致构建失败
- ✅ **版本锁定** - 使用经过验证的确切版本

## ⚠️ 注意事项

- Release 文件大小限制：单个文件最大 2GB（Gradle 219MB 完全没问题）
- 如果文件被删除，需要重新上传
- 建议保留此 `gradle-deps` Release，不要删除
