#!/usr/bin/env bash
# 版本信息脚本 - 获取和显示HyDE版本信息

# 获取Git仓库信息
HYDE_CLONE_PATH=$(git rev-parse --show-toplevel)                    # 仓库根目录路径
HYDE_BRANCH=$(git rev-parse --abbrev-ref HEAD)                      # 当前分支名
HYDE_REMOTE=$(git config --get remote.origin.url)                   # 远程仓库URL
HYDE_VERSION=$(git describe --tags --always)                        # 版本标签
HYDE_COMMIT_HASH=$(git rev-parse HEAD)                              # 当前提交哈希
HYDE_VERSION_COMMIT_MSG=$(git log -1 --pretty=%B)                   # 最新提交消息
HYDE_VERSION_LAST_CHECKED=$(date +%Y-%m-%d\ %H:%M%S\ %z)            # 最后检查时间

# 生成发布说明的函数
generate_release_notes() {
  local latest_tag
  local commits

  # 获取最新的标签
  latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)

  if [[ -z "$latest_tag" ]]; then
    echo "No release tags found"
    return
  fi

  echo "=== Changes since $latest_tag ==="

  # 获取自上次发布以来的提交
  commits=$(git log --oneline --pretty=format:"• %s" "$latest_tag"..HEAD 2>/dev/null)

  if [[ -z "$commits" ]]; then
    echo "No commits since last release"
    return
  fi

  echo "$commits"
}

# 生成发布说明
HYDE_RELEASE_NOTES=$(generate_release_notes)

# 显示版本信息
echo "HyDE $HYDE_VERSION built from branch $HYDE_BRANCH at commit ${HYDE_COMMIT_HASH:0:12} ($HYDE_VERSION_COMMIT_MSG)"
echo "Date: $HYDE_VERSION_LAST_CHECKED"
echo "Repository: $HYDE_CLONE_PATH"
echo "Remote: $HYDE_REMOTE"
echo ""

# 处理命令行参数
if [[ "$1" == "--cache" ]]; then
  # 缓存版本信息到文件
  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hyde"
  mkdir -p "$state_dir"
  version_file="$state_dir/version"

  # 将版本信息写入文件
  cat >"$version_file" <<EOL
HYDE_CLONE_PATH='$HYDE_CLONE_PATH'
HYDE_BRANCH='$HYDE_BRANCH'
HYDE_REMOTE='$HYDE_REMOTE'
HYDE_VERSION='$HYDE_VERSION'
HYDE_VERSION_LAST_CHECKED='$HYDE_VERSION_LAST_CHECKED'
HYDE_VERSION_COMMIT_MSG='$HYDE_VERSION_COMMIT_MSG'
HYDE_COMMIT_HASH='$HYDE_COMMIT_HASH'
HYDE_RELEASE_NOTES='$HYDE_RELEASE_NOTES'
EOL

  echo -e "Version cache output to $version_file\n"

elif [[ "$1" == "--release-notes" ]]; then
  # 只显示发布说明
  echo "$HYDE_RELEASE_NOTES"

fi
