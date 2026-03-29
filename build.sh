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
  TAG_NAME="v1.0.${NEW_PATCH}"
  
  # 在 pubspec.yaml 中替换为新版本号
  sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
  
  echo "🚀 版本号已自动更新为: $NEW_VERSION"
  echo "🔨 开始构建原生 APK，请稍候..."
  
  flutter build apk --release
  
  # 将构建好的 apk 复制到当前目录并重命名
  cp build/app/outputs/flutter-apk/app-release.apk "./$NEW_APK_NAME"
  
  echo "✅ 打包完成！已在当前目录生成: $NEW_APK_NAME"

  # 自动提交版本号变更
  git add -A
  git commit -m "🔖 release: ${TAG_NAME} — 自动构建"
  git push

  # 创建 GitHub Release 并上传 APK
  if command -v gh &> /dev/null; then
    echo "📦 正在创建 GitHub Release: ${TAG_NAME}..."
    gh release create "${TAG_NAME}" "./${NEW_APK_NAME}" \
      --title "万物打卡 ${TAG_NAME}" \
      --notes "自动构建 — $(date '+%Y-%m-%d %H:%M')" \
      --latest
    echo "🎉 GitHub Release 已发布: ${TAG_NAME}"
  else
    echo "⚠️  未安装 gh (GitHub CLI)，跳过自动发布 Release。"
    echo "   手动上传 APK：https://github.com/Mr-Q526/EveryTick/releases/new"
  fi
else
  echo "❌ 无法解析版本号。请确保 pubspec.yaml 的 version 格式为 '1.0.x+y'"
fi
