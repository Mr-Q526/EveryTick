#!/bin/bash
set -e

# 提取当前的 version 字段，例如: version: 1.0.0+1
VERSION_LINE=$(grep '^version:' pubspec.yaml)

if [[ $VERSION_LINE =~ version:\ 1\.0\.([0-9]+)\+([0-9]+) ]]; then
  PATCH="${BASH_REMATCH[1]}"
  BUILD="${BASH_REMATCH[2]}"
  
  # 每次打包，补丁号(Patch)和构建号(Build Number)自动 +1
  NEW_PATCH=$((PATCH + 1))
  NEW_BUILD=$((BUILD + 1))
  NEW_VERSION="1.0.${NEW_PATCH}+${NEW_BUILD}"
  NEW_APK_NAME="EveryTick1.0.${NEW_PATCH}.apk"
  
  # 在 pubspec.yaml 中替换为新版本号
  sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
  
  echo "🚀 版本号已自动更新为: $NEW_VERSION"
  echo "🔨 开始构建原生 APK，请稍候..."
  
  flutter build apk --release
  
  # 将构建好的 apk 复制到当前目录并重命名
  cp build/app/outputs/flutter-apk/app-release.apk "./$NEW_APK_NAME"
  
  echo "✅ 打包完成！已在当前目录生成: $NEW_APK_NAME"
else
  echo "❌ 无法解析版本号。请确保 pubspec.yaml 的 version 格式为 '1.0.x+y'"
fi
