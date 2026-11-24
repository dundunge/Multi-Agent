#!/usr/bin/env zsh
set -euo pipefail

# AICall 本地同步上游 (pingdotgg/t3code) 并重新编译安装脚本
# 用法:
#   ./scripts/sync-upstream-and-build.sh            # 拉取上游更新 + 编译打包 AICall.app
#   ./scripts/sync-upstream-and-build.sh --install  # 拉取 + 编译 + 自动替换 /Applications/AICall.app
#   ./scripts/sync-upstream-and-build.sh --build-only --install # 不拉上游，仅本地编译并安装

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

export PATH="$HOME/.vite-plus/bin:$HOME/.cargo/bin:$HOME/Library/pnpm:/opt/homebrew/bin:/usr/local/bin:$PATH"
if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
  export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi

DO_SYNC=1
DO_INSTALL=0
DO_PUSH=0

for arg in "$@"; do
  case "$arg" in
    --build-only) DO_SYNC=0 ;;
    --install)    DO_INSTALL=1 ;;
    --push)       DO_PUSH=1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

git config rerere.enabled true

if [ "$DO_SYNC" -eq 1 ]; then
  echo "==> [1/4] Fetching upstream (https://github.com/pingdotgg/t3code.git)..."
  git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/pingdotgg/t3code.git
  git fetch upstream main
  echo "==> Merging upstream/main into local branch..."
  git merge --no-edit upstream/main
fi

echo "==> [2/4] Installing workspace dependencies via Vite+..."
vp i

echo "==> [3/4] Running zero-telemetry security regression checks..."
vp test run apps/server/src/telemetry/Identify.test.ts apps/server/src/telemetry/AnalyticsService.test.ts packages/shared/src/otelEnvironment.test.ts

echo "==> [4/4] Building macOS arm64 AICall.app & DMG..."
rm -rf release/mac-arm64
node scripts/build-desktop-artifact.ts --platform mac --target dir --arch arm64 --output-dir release

APP_BUNDLE="$REPO_ROOT/release/mac-arm64/AICall.app"
if [ ! -d "$APP_BUNDLE" ]; then
  echo "ERROR: Expected built bundle at $APP_BUNDLE" >&2
  exit 1
fi

# Ad-hoc sign with consistent identifier so macOS TCC recognizes AICall
codesign --force --deep --sign - --identifier "com.natie.aicall" "$APP_BUNDLE"

echo "✓ Built successfully: $APP_BUNDLE"

if [ "$DO_INSTALL" -eq 1 ]; then
  echo "==> Installing AICall.app to /Applications/AICall.app..."
  if pgrep -x "AICall" >/dev/null 2>&1; then
    echo "    Closing running AICall instance gracefully..."
    osascript -e 'tell application "AICall" to quit' || true
    sleep 2
  fi
  rm -rf "/Applications/AICall.app"
  ditto "$APP_BUNDLE" "/Applications/AICall.app"
  xattr -dr com.apple.quarantine "/Applications/AICall.app" 2>/dev/null || true
  echo "✓ Installed to /Applications/AICall.app"
fi

if [ "$DO_PUSH" -eq 1 ]; then
  echo "==> Pushing updated branch to origin..."
  git push origin HEAD
fi
