# 本地构建并上传到 GitHub Release
param(
    [Parameter(Mandatory=$false)]
    [string]$Tag
)

# 获取版本号
$version = (Get-Content pubspec.yaml | Select-String '^version:').ToString().Split()[1].Split('+')[0]

if (-not $Tag) {
    $Tag = "v$version"
}

Write-Host "🚀 开始构建 Motto Music $version" -ForegroundColor Green

# 构建 APK
Write-Host "`n📦 构建 APK..." -ForegroundColor Cyan
flutter build apk --split-per-abi --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ APK 构建失败" -ForegroundColor Red
    exit 1
}

# 构建 AAB
Write-Host "`n📦 构建 AAB..." -ForegroundColor Cyan
flutter build appbundle --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ AAB 构建失败" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ 构建完成！" -ForegroundColor Green

# 检查是否已存在 tag
$tagExists = git tag -l $Tag
if ($tagExists) {
    Write-Host "`n⚠️  Tag $Tag 已存在" -ForegroundColor Yellow
    $continue = Read-Host "是否继续上传到现有 Release? (y/n)"
    if ($continue -ne 'y') {
        exit 0
    }
} else {
    # 创建 tag
    Write-Host "`n🏷️  创建 tag $Tag..." -ForegroundColor Cyan
    git tag $Tag
    git push origin $Tag

    Write-Host "⏳ 等待 GitHub Release 创建..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
}

# 上传到 Release
Write-Host "`n📤 上传到 GitHub Release..." -ForegroundColor Cyan

$files = @(
    "build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk#MottoMusic-$version-armeabi-v7a.apk",
    "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk#MottoMusic-$version-arm64-v8a.apk",
    "build/app/outputs/flutter-apk/app-x86_64-release.apk#MottoMusic-$version-x86_64.apk",
    "build/app/outputs/bundle/release/app-release.aab#MottoMusic-$version.aab"
)

foreach ($file in $files) {
    gh release upload $Tag $file --clobber
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ 上传失败: $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n🎉 发布完成！" -ForegroundColor Green
Write-Host "查看 Release: https://github.com/motto1/motto-music/releases/tag/$Tag" -ForegroundColor Cyan
