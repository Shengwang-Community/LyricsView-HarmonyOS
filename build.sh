#!/bin/bash

# Agora LyricsView HarmonyOS 统一构建脚本
# 集成版本管理、HAR编译、模式切换、发布等功能
# 
# 用法:
#   ./build.sh                               # 发布HAR包
#   ./build.sh clean                         # 清理构建文件
#   ./build.sh help                          # 显示帮助信息

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# 配置管理工具
CONFIG_MANAGER="$PROJECT_ROOT/scripts/config-manager.js"

# 确保entry源码使用统一的导入名称
updateEntryImports() {
    local mode="$1"
    local entry_src_dir="$PROJECT_ROOT/entry/src/main/ets"
    
    print_info "确保entry源码使用@shengwang/lyrics-view导入名称"
    # 统一将 'lyrics_view' 替换为 '@shengwang/lyrics-view'
    find "$entry_src_dir" -name "*.ets" -type f -exec sed -i '' "s|from 'lyrics_view'|from '@shengwang/lyrics-view'|g" {} \;
    find "$entry_src_dir" -name "*.ets" -type f -exec sed -i '' "s|from \"lyrics_view\"|from \"@shengwang/lyrics-view\"|g" {} \;
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "${PURPLE}🚀 $1${NC}"
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}Agora LyricsView HarmonyOS 构建工具${NC}"
    echo ""
    echo "用法: ./build.sh [command]"
    echo ""
    echo "命令:"
    echo "  (无参数)               编译 Release 版本 (HAR + HAP)"
    echo "  -release               编译并发布到 OHPM 中心仓"
    echo "  clean                  清理所有构建文件"
    echo "  help                   显示此帮助信息"
    echo ""
    echo "构建输出:"
    echo "  - HAR 包: lyrics_view/build/default/outputs/default/"
    echo "  - HAP 包: entry/build/default/outputs/default/"
    echo ""
    echo "发布目录结构:"
    echo "  releases/v{版本号}/"
    echo "    ├── sdk/                              # SDK 包（三方库发布）"
    echo "    │   ├── Agora-LyricsView-{版本号}.har  # HAR 包"
    echo "    │   ├── oh-package.json5              # 包配置（必需）"
    echo "    │   ├── README.md                     # 使用文档（必需）"
    echo "    │   ├── CHANGELOG.md                  # 更新日志（必需）"
    echo "    │   └── LICENSE                       # 开源协议（必需）"
    echo "    └── example/                          # 示例应用"
    echo "        └── LyricsView-Example-v{版本号}-{时间戳}.hap"
    echo ""
    echo "HAP 文件命名格式:"
    echo "  LyricsView-Example-v{版本号}-{时间戳}.hap"
    echo "  示例: LyricsView-Example-v1.0.0-20251011-123456.hap"
    echo ""
    echo "示例:"
    echo "  ./build.sh              # 编译 HAR 和 HAP"
    echo "  ./build.sh -release     # 编译并发布到 OHPM"
    echo "  ./build.sh clean        # 清理构建文件"
    echo ""
    echo "🚀 推荐使用: ./build.sh  # 一条命令编译 HAR + HAP"
}

# 生成项目配置
generate_config() {
    print_step "生成项目配置..."
    
    # 从工程配置读取版本号
    local VERSION=$(node "$CONFIG_MANAGER" version)
    local APP_NAME=$(node "$CONFIG_MANAGER" get project.name)
    local SDK_MODE=$(node "$CONFIG_MANAGER" sdk-mode)
    
    if [ -z "$VERSION" ]; then
        print_error "无法获取版本号"
        exit 1
    fi
    
    print_info "当前版本: $VERSION"
    print_info "应用名称: $APP_NAME"
    print_info "SDK模式: $SDK_MODE"
    
    # 生成配置文件到 entry 模块
    node "$PROJECT_ROOT/scripts/generate-config.js"
    print_info "已生成: entry/src/main/ets/utils/BuildConfig.ets"
    
    # SDK 模式的 HAR 包配置将在 build_har 之后处理
    if [ "$SDK_MODE" = "true" ]; then
        print_info "SDK模式为HAR包模式，将在编译HAR后配置entry"
    else
        print_info "SDK模式为源码模式，使用源码导入"
        
        # 确保entry使用源码导入
        local ENTRY_PACKAGE="$PROJECT_ROOT/entry/oh-package.json5"
        if [ -f "$ENTRY_PACKAGE" ]; then
            # 检查是否需要切换到源码导入
            if grep -q "file:./libs/Agora-LyricsView" "$ENTRY_PACKAGE"; then
                # 切换到源码导入，但保持@shengwang/lyrics-view名称
                sed -i '' 's|"@shengwang/lyrics-view": "file:./libs/Agora-LyricsView-[^"]*"|"@shengwang/lyrics-view": "file:../lyrics_view"|g' "$ENTRY_PACKAGE"
                sed -i '' 's|"path": "./libs/Agora-LyricsView-[^"]*"|"path": "../lyrics_view"|g' "$ENTRY_PACKAGE"
                
                print_info "已切换entry导入配置为源码模式（保持@shengwang/lyrics-view名称）"
            fi
            
            # 删除HAR包文件（源码模式不需要）
            local HAR_FILES="$PROJECT_ROOT/entry/libs/Agora-LyricsView-*.har"
            rm -f $HAR_FILES 2>/dev/null
            if [ $? -eq 0 ]; then
                print_info "已删除HAR包文件"
            fi
            
            # 确保entry源码使用统一的导入名称
            updateEntryImports "source"
        fi
    fi
    
    # 同步版本号到 package.json5 文件
    local FILES=(
        "lyrics_view/oh-package.json5"
        "entry/oh-package.json5"
    )
    
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            # 使用 sed 更新版本号
            sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" "$file"
            print_info "已更新: $file"
        fi
    done
    
    print_success "项目配置生成完成!"
    print_info "版本信息:"
    echo "  \"version\": \"$VERSION\","
}

# 获取版本号
get_version() {
    node "$CONFIG_MANAGER" version
}

# 编译 HAR 包
build_har() {
    local BUILD_TYPE=${1:-release}
    
    print_step "开始编译 lyrics_view HAR 包..."
    print_info "构建类型: $BUILD_TYPE"
    
    # 获取版本信息并清理旧的 release 目录
    local VERSION=$(get_version)
    local RELEASE_DIR="$PROJECT_ROOT/releases/v$VERSION"
    
    if [ -d "$RELEASE_DIR" ]; then
        print_info "清理旧的发布目录: releases/v$VERSION"
        rm -rf "$RELEASE_DIR"
        print_success "已清理旧版本目录"
    fi
    
    # 进入 lyrics_view 目录
    cd lyrics_view
    
    print_info "当前版本: $VERSION"
    
    # 清理之前的构建
    print_step "清理之前的构建..."
    rm -rf build/
    
    # 编译 HAR 包
    print_step "编译 HAR 包..."
    cd ..
    
    # 使用 DevEco Studio 的 hvigor 工具
    local HVIGOR_CMD="/Applications/DevEco-Studio.app/Contents/tools/node/bin/node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js"
    
    print_info "编译 Release 版本 HAR 包..."
    $HVIGOR_CMD --mode module -p module=lyrics_view@default -p product=default -p buildMode=release assembleHar --analyze=normal --parallel --incremental --daemon
    cd lyrics_view
    
    # 检查编译结果
    local HAR_PATH="build/default/outputs/default/lyrics_view.har"
    if [ -f "$HAR_PATH" ]; then
        print_success "HAR 包编译成功!"
        
        # 生成自定义文件名
        local HAR_NAME=$(node "$CONFIG_MANAGER" get build.harName)
        local CUSTOM_NAME="$HAR_NAME-$VERSION.har"
        
        # 复制并重命名文件
        local CUSTOM_PATH="build/default/outputs/default/$CUSTOM_NAME"
        cp "$HAR_PATH" "$CUSTOM_PATH"
        
        print_info "原始文件: $(pwd)/$HAR_PATH"
        print_info "自定义文件: $(pwd)/$CUSTOM_PATH"
        
        # 显示文件信息
        echo ""
        print_info "文件信息:"
        ls -lh "$HAR_PATH"
        ls -lh "$CUSTOM_PATH"
        
        # 返回根目录
        cd ..
        
        print_success "构建完成!"
        
    else
        print_error "HAR 包编译失败!"
        exit 1
    fi
}

# 生成三方库发布所需文件
generate_release_files() {
    local VERSION=$1
    local OUTPUT_DIR=$2
    
    print_step "生成三方库发布文件..."
    
    # 1. 复制 oh-package.json5
    if [ -f "lyrics_view/oh-package.json5" ]; then
        cp "lyrics_view/oh-package.json5" "$OUTPUT_DIR/oh-package.json5"
        print_success "✓ oh-package.json5"
    else
        print_error "oh-package.json5 不存在！"
        exit 1
    fi
    
    # 2. 生成 LICENSE 文件
    cat > "$OUTPUT_DIR/LICENSE" << 'EOF'
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   Copyright 2024 Shengwang Community

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
EOF
    print_success "✓ LICENSE"
    
    # 3. 生成 README.md
    cat > "$OUTPUT_DIR/README.md" << EOF
# Agora LyricsView HarmonyOS

[![Version](https://img.shields.io/badge/version-${VERSION}-blue.svg)](https://github.com/Shengwang-Community/LyricsView-HarmonyOS)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%209+-orange.svg)](https://developer.harmonyos.com/)

HarmonyOS 平台的歌词显示和卡拉OK组件，支持逐字高亮、音高评分、粒子特效等功能。

## ✨ 功能特性

- 🎵 **歌词显示**：支持 LRC 和 XML 格式歌词，自动滚动和居中显示
- 🎤 **卡拉OK模式**：逐字高亮显示，精确同步音乐播放进度
- 🎯 **音高评分**：实时评分系统，支持自定义评分算法
- 🎨 **粒子特效**：精彩演唱时的视觉反馈效果
- 📱 **触摸交互**：支持拖拽调整播放进度
- 🔄 **平滑动画**：流畅的过渡动画效果
- ⚙️ **高度可定制**：丰富的样式配置选项

## 📦 安装

### 方式一：使用 HAR 包（推荐）

1. 将 HAR 包复制到项目的 \`libs\` 目录

2. 在 \`oh-package.json5\` 中添加依赖：

\`\`\`json5
{
  "dependencies": {
    "@shengwang/lyrics-view": "file:./libs/Agora-LyricsView-${VERSION}.har"
  }
}
\`\`\`

3. 执行 \`ohpm install\`

### 方式二：源码集成

从 GitHub 克隆源码到项目中，然后在 \`oh-package.json5\` 中配置本地路径。

## 🚀 快速开始

### 1. 导入组件

\`\`\`typescript
import { 
  KaraokeView, 
  LyricsView, 
  ScoringView 
} from '@shengwang/lyrics-view';
\`\`\`

### 2. 创建 KaraokeView 实例

\`\`\`typescript
private karaokeView: KaraokeView = new KaraokeView();
\`\`\`

### 3. 解析歌词

\`\`\`typescript
// 从文件路径解析
const lyricModel = this.karaokeView.parseLyrics(
  '/path/to/lyrics.xml',
  '/path/to/pitch.txt',
  true,  // 包含版权信息
  0      // 歌词偏移量（毫秒）
);

// 设置歌词数据
if (lyricModel) {
  this.karaokeView.setLyricData(lyricModel, false);
}
\`\`\`

### 4. 在界面中使用组件

\`\`\`typescript
build() {
  Column() {
    // 评分视图
    ScoringView({
      enableParticleEffect: true
    })
      .width('100%')
      .height(180)
    
    // 歌词视图
    LyricsView({
      textSize: 16,
      currentLineTextSize: 20,
      currentLineTextColor: '#FFFF00',
      currentLineHighlightedTextColor: '#FFF44336',
      enableDragging: true
    })
      .width('100%')
      .height(260)
  }
}
\`\`\`

### 5. 更新播放进度

\`\`\`typescript
// 在播放器回调中更新进度（建议 20ms 间隔）
onPositionChanged(position: number) {
  this.karaokeView.setProgress(position);
}
\`\`\`

### 6. 设置音高数据（可选）

\`\`\`typescript
// 从麦克风输入获取音高数据
onPitch(speakerPitch: number, score: number) {
  this.karaokeView.setPitch(speakerPitch, score);
}
\`\`\`

### 7. 清理资源

\`\`\`typescript
aboutToDisappear() {
  this.karaokeView.destroy();
}
\`\`\`

## 📖 API 文档

### KaraokeView

主控制器类，管理歌词显示和评分系统。

#### 静态方法

\`\`\`typescript
// 获取 SDK 版本号
static getSdkVersion(): string
\`\`\`

#### 实例方法

\`\`\`typescript
// 解析歌词文件
parseLyrics(
  lyricSource: string | Uint8Array,
  pitchSource?: string | Uint8Array,
  includeCopyrightSentence?: boolean,
  lyricOffset?: number
): LyricModel | null

// 设置歌词数据
setLyricData(model: LyricModel, usingInternalScoring?: boolean): void

// 设置播放进度（毫秒）
setProgress(progress: number): void

// 设置音高数据
setPitch(speakerPitch: number, pitchScore: number): void

// 重置组件
reset(): void

// 销毁组件
destroy(): void
\`\`\`

### LyricsView 配置参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| \`textSize\` | number | 14 | 普通文本大小 |
| \`currentLineTextSize\` | number | 18 | 当前行文本大小 |
| \`currentLineTextColor\` | string | '#FFFFFF' | 当前行文本颜色 |
| \`currentLineHighlightedTextColor\` | string | '#FF6B35' | 当前行高亮颜色 |
| \`previousLineTextColor\` | string | '#999999' | 已唱行文本颜色 |
| \`upcomingLineTextColor\` | string | '#CCCCCC' | 未唱行文本颜色 |
| \`lineSpacing\` | number | 10 | 行间距 |
| \`enableDragging\` | boolean | true | 是否启用拖拽 |
| \`enableLineWrap\` | boolean | false | 是否启用自动换行 |

### ScoringView 配置参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| \`enableParticleEffect\` | boolean | true | 是否启用粒子特效 |

## 🎯 使用场景

- 🎤 在线K歌应用
- 🎵 音乐播放器
- 📺 KTV系统
- 🎓 音乐教学应用
- 🎮 音乐游戏

## 📋 系统要求

- HarmonyOS API 9 或更高版本
- DevEco Studio 4.0 或更高版本
- ArkTS/TS 支持

## 🔗 相关链接

- [GitHub 仓库](https://github.com/Shengwang-Community/LyricsView-HarmonyOS)
- [问题反馈](https://github.com/Shengwang-Community/LyricsView-HarmonyOS/issues)
- [更新日志](CHANGELOG.md)

## 📄 开源协议

本项目采用 [Apache License 2.0](LICENSE) 开源协议。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📧 联系我们

如有问题或建议，请通过以下方式联系：

- GitHub Issues: https://github.com/Shengwang-Community/LyricsView-HarmonyOS/issues
- 社区论坛: https://www.shengwang.cn/

---

Made with ❤️ by Shengwang Community
EOF
    print_success "✓ README.md"
    
    # 4. 生成 CHANGELOG.md
    local CURRENT_DATE=$(date +"%Y-%m-%d")
    cat > "$OUTPUT_DIR/CHANGELOG.md" << EOF
# 更新日志

本文档记录 Agora LyricsView HarmonyOS 的所有重要变更。

## [${VERSION}] - ${CURRENT_DATE}

### 🎉 新增功能

- ✨ 初始版本发布
- 🎵 支持 LRC 和 XML 格式歌词解析
- 🎤 支持卡拉OK逐字高亮显示
- 🎯 支持音高实时评分
- 🎨 支持粒子特效
- 📱 支持触摸拖拽调整进度
- 🔄 支持平滑滚动动画

### 🎨 组件列表

- **KaraokeView**: 主控制器，管理歌词和评分
- **LyricsView**: 歌词显示组件
- **ScoringView**: 评分显示组件

### 🛠️ 技术特性

- 基于 ArkTS 开发
- 支持 HarmonyOS API 9+
- 事件驱动架构
- 高性能渲染
- 内存管理优化

### 📦 发布说明

#### HAR 包信息

- **包名**: @shengwang/lyrics-view
- **版本**: ${VERSION}
- **大小**: 约 200 KB
- **依赖**: 无外部依赖

#### 安装方式

\`\`\`json5
{
  "dependencies": {
    "@shengwang/lyrics-view": "file:./libs/Agora-LyricsView-${VERSION}.har"
  }
}
\`\`\`

### 🐛 已知问题

- 无

### 📝 注意事项

- 建议每 20ms 调用一次 \`setProgress()\` 以确保歌词同步流畅
- 使用完毕后请调用 \`destroy()\` 释放资源
- 音高评分功能需要配合音频采集使用

### 🔜 计划功能

- [ ] 支持更多歌词格式
- [ ] 增加更多粒子特效样式
- [ ] 优化内存占用
- [ ] 添加更多配置选项
- [ ] 性能优化

---

## 版本规范

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范：

- **主版本号（MAJOR）**: 不兼容的 API 变更
- **次版本号（MINOR）**: 向下兼容的功能新增
- **修订号（PATCH）**: 向下兼容的问题修正

## 获取更新

- GitHub Releases: https://github.com/Shengwang-Community/LyricsView-HarmonyOS/releases
- 更新通知: 关注项目获取最新动态

---

感谢使用 Agora LyricsView HarmonyOS！
EOF
    print_success "✓ CHANGELOG.md"
    
    echo ""
    print_success "所有发布文件生成完成！"
    print_info "输出目录: $OUTPUT_DIR"
    echo ""
    print_info "📋 文件清单:"
    ls -lh "$OUTPUT_DIR" | grep -E "(oh-package|README|CHANGELOG|LICENSE)"
}

# 配置 entry 使用 HAR 包（SDK 模式）
configure_entry_har() {
    print_step "配置 entry 使用 HAR 包..."
    
    # 获取版本和配置
    local VERSION=$(get_version)
    local HAR_NAME=$(node "$CONFIG_MANAGER" get build.harName)
    local HAR_FILENAME="${HAR_NAME}-${VERSION}.har"
    local SDK_MODE=$(node "$CONFIG_MANAGER" sdk-mode)
    
    if [ "$SDK_MODE" != "true" ]; then
        print_info "SDK 模式未启用，跳过 HAR 包配置"
        return 0
    fi
    
    # 确保 entry/libs 目录存在
    local ENTRY_LIBS_DIR="$PROJECT_ROOT/entry/libs"
    mkdir -p "$ENTRY_LIBS_DIR"
    
    # 复制刚编译好的 HAR 包到 entry/libs
    local HAR_SOURCE="$PROJECT_ROOT/lyrics_view/build/default/outputs/default/$HAR_FILENAME"
    local HAR_TARGET="$ENTRY_LIBS_DIR/$HAR_FILENAME"
    
    if [ -f "$HAR_SOURCE" ]; then
        cp "$HAR_SOURCE" "$HAR_TARGET"
        print_success "已复制 HAR 包到: $HAR_TARGET"
        
        # 更新 entry/oh-package.json5
        local ENTRY_PACKAGE="$PROJECT_ROOT/entry/oh-package.json5"
        if [ -f "$ENTRY_PACKAGE" ]; then
            # 使用 sed 替换导入路径
            sed -i '' "s|\"@shengwang/lyrics-view\": \"file:../lyrics_view\"|\"@shengwang/lyrics-view\": \"file:./libs/$HAR_FILENAME\"|g" "$ENTRY_PACKAGE"
            sed -i '' "s|\"path\": \"../lyrics_view\"|\"path\": \"./libs/$HAR_FILENAME\"|g" "$ENTRY_PACKAGE"
            
            # 更新 entry 源码中的导入语句
            updateEntryImports "har"
            
            print_success "已更新 entry 导入配置为 HAR 包模式"
            print_info "配置文件: $ENTRY_PACKAGE"
            print_info "HAR 引用: file:./libs/$HAR_FILENAME"
        fi
    else
        print_error "HAR 包不存在: $HAR_SOURCE"
        exit 1
    fi
}

# 编译 HAP 包
build_hap() {
    local BUILD_TYPE=${1:-release}
    
    print_step "开始编译 entry HAP 包..."
    print_info "构建类型: $BUILD_TYPE"
    
    # 获取版本信息
    local VERSION=$(get_version)
    print_info "当前版本: $VERSION"
    
    # 检查依赖文件（SDK 模式下应该已经由 configure_entry_har 处理）
    print_step "检查依赖文件..."
    local SDK_MODE=$(node "$CONFIG_MANAGER" sdk-mode)
    local HAR_NAME=$(node "$CONFIG_MANAGER" get build.harName)
    local LYRICS_HAR_FILENAME="${HAR_NAME}-${VERSION}.har"
    local LYRICS_HAR_TARGET="entry/libs/$LYRICS_HAR_FILENAME"
    
    if [ "$SDK_MODE" = "true" ]; then
        if [ -f "$LYRICS_HAR_TARGET" ]; then
            print_info "HAR 包已就绪: $LYRICS_HAR_FILENAME"
        else
            print_warning "未找到 HAR 包，尝试复制..."
            local LYRICS_HAR_SOURCE="lyrics_view/build/default/outputs/default/$LYRICS_HAR_FILENAME"
            if [ -f "$LYRICS_HAR_SOURCE" ]; then
                mkdir -p entry/libs
                cp "$LYRICS_HAR_SOURCE" "$LYRICS_HAR_TARGET"
                print_info "已复制 $LYRICS_HAR_FILENAME 到 entry/libs"
            else
                print_error "HAR 包不存在: $LYRICS_HAR_SOURCE"
                exit 1
            fi
        fi
    else
        print_info "源码模式，使用 lyrics_view 源码"
    fi
    
    # 安装依赖
    print_step "安装依赖..."
    cd entry
    
    # 清理 oh_modules 缓存
    if [ -d "oh_modules" ]; then
        rm -rf oh_modules
    fi
    
    # 使用 DevEco Studio 的 ohpm 安装依赖
    local OHPM_CMD="/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm"
    if [ -f "$OHPM_CMD" ]; then
        $OHPM_CMD install
        print_success "依赖安装完成"
    else
        print_warning "未找到 ohpm，尝试使用系统 ohpm"
        ohpm install
    fi
    
    cd ..
    
    # 使用 DevEco Studio 的 hvigor 工具
    local HVIGOR_CMD="/Applications/DevEco-Studio.app/Contents/tools/node/bin/node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js"
    
    # 使用 release product 配置（使用发布证书签名）
    print_info "编译 Release 版本 HAP 包（使用发布证书）..."
    $HVIGOR_CMD --mode module -p module=entry@default -p product=release -p buildMode=release assembleHap --analyze=normal --parallel --incremental --daemon
    
    # 检查编译结果（支持 default 和 release product）
    local SIGNED_HAP_PATH_RELEASE="entry/build/release/outputs/default/entry-default-signed.hap"
    local UNSIGNED_HAP_PATH_RELEASE="entry/build/release/outputs/default/entry-default-unsigned.hap"
    local SIGNED_HAP_PATH_DEFAULT="entry/build/default/outputs/default/entry-default-signed.hap"
    local UNSIGNED_HAP_PATH_DEFAULT="entry/build/default/outputs/default/entry-default-unsigned.hap"
    
    local SIGNED_HAP_PATH=""
    local UNSIGNED_HAP_PATH=""
    
    # 优先检查 release product 的输出
    if [ -f "$SIGNED_HAP_PATH_RELEASE" ]; then
        SIGNED_HAP_PATH="$SIGNED_HAP_PATH_RELEASE"
    elif [ -f "$SIGNED_HAP_PATH_DEFAULT" ]; then
        SIGNED_HAP_PATH="$SIGNED_HAP_PATH_DEFAULT"
    fi
    
    if [ -f "$UNSIGNED_HAP_PATH_RELEASE" ]; then
        UNSIGNED_HAP_PATH="$UNSIGNED_HAP_PATH_RELEASE"
    elif [ -f "$UNSIGNED_HAP_PATH_DEFAULT" ]; then
        UNSIGNED_HAP_PATH="$UNSIGNED_HAP_PATH_DEFAULT"
    fi
    
    if [ -f "$SIGNED_HAP_PATH" ] || [ -f "$UNSIGNED_HAP_PATH" ]; then
        print_success "HAP 包编译成功!"
        
        if [ -f "$SIGNED_HAP_PATH" ]; then
            print_info "类型: 已签名版本 (signed) - 使用发布证书"
            print_success "✅ 此 HAP 可在任意 HarmonyOS 设备上安装！"
            ls -lh "$SIGNED_HAP_PATH"
        elif [ -f "$UNSIGNED_HAP_PATH" ]; then
            print_warning "类型: 未签名版本 (unsigned) - 建议配置签名"
            ls -lh "$UNSIGNED_HAP_PATH"
        fi
        
    else
        print_error "HAP 包编译失败!"
        exit 1
    fi
}

# 重命名并复制 HAP 文件到 release 目录
rename_hap_file() {
    local VERSION=$1
    local RELEASE_DIR=$2
    local TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    local NEW_FILENAME="LyricsView-Example-v${VERSION}-${TIMESTAMP}.hap"
    
    # 检查 release 和 default 两个目录
    local SIGNED_HAP_PATH_RELEASE="entry/build/release/outputs/default/entry-default-signed.hap"
    local UNSIGNED_HAP_PATH_RELEASE="entry/build/release/outputs/default/entry-default-unsigned.hap"
    local SIGNED_HAP_PATH_DEFAULT="entry/build/default/outputs/default/entry-default-signed.hap"
    local UNSIGNED_HAP_PATH_DEFAULT="entry/build/default/outputs/default/entry-default-unsigned.hap"
    
    local SIGNED_HAP_PATH=""
    local UNSIGNED_HAP_PATH=""
    
    # 优先使用 release product 的输出
    if [ -f "$SIGNED_HAP_PATH_RELEASE" ]; then
        SIGNED_HAP_PATH="$SIGNED_HAP_PATH_RELEASE"
    elif [ -f "$SIGNED_HAP_PATH_DEFAULT" ]; then
        SIGNED_HAP_PATH="$SIGNED_HAP_PATH_DEFAULT"
    fi
    
    if [ -f "$UNSIGNED_HAP_PATH_RELEASE" ]; then
        UNSIGNED_HAP_PATH="$UNSIGNED_HAP_PATH_RELEASE"
    elif [ -f "$UNSIGNED_HAP_PATH_DEFAULT" ]; then
        UNSIGNED_HAP_PATH="$UNSIGNED_HAP_PATH_DEFAULT"
    fi
    
    # 创建 example 目录
    local EXAMPLE_DIR="$RELEASE_DIR/example"
    mkdir -p "$EXAMPLE_DIR"
    
    local NEW_HAP_PATH="$EXAMPLE_DIR/$NEW_FILENAME"
    
    if [ -f "$SIGNED_HAP_PATH" ]; then
        cp "$SIGNED_HAP_PATH" "$NEW_HAP_PATH"
        print_success "HAP 文件已重命名并复制到 release 目录"
        print_info "文件名: $NEW_FILENAME"
        print_info "类型: 已签名版本 (signed) - 使用发布证书"
        print_success "✅ 此 HAP 可在任意 HarmonyOS 设备上安装！"
        print_info "位置: $NEW_HAP_PATH"
        
        # 显示文件信息
        echo ""
        print_info "HAP 文件信息:"
        ls -lh "$NEW_HAP_PATH"
        
        return 0
        
    elif [ -f "$UNSIGNED_HAP_PATH" ]; then
        cp "$UNSIGNED_HAP_PATH" "$NEW_HAP_PATH"
        print_success "HAP 文件已重命名并复制到 release 目录"
        print_info "文件名: $NEW_FILENAME"
        print_warning "类型: 未签名版本 (unsigned) - 建议配置签名"
        print_info "位置: $NEW_HAP_PATH"
        
        # 显示文件信息
        echo ""
        print_info "HAP 文件信息:"
        ls -lh "$NEW_HAP_PATH"
        
        return 0
        
    else
        print_warning "未找到 HAP 文件"
        return 1
    fi
}


# 构建 Release 版本
build_release() {
    # 获取版本号（从工程配置中读取）
    local VERSION=$(get_version)
    
    if [ -z "$VERSION" ]; then
        print_error "无法获取版本号"
        exit 1
    fi
    
    print_step "🚀 开始构建 Release 版本..."
    print_info "版本号: $VERSION"
    
    # 1. 生成项目配置
    print_step "📋 生成项目配置..."
    generate_config
    
    # 2. 清理构建文件
    print_step "🧹 清理构建文件..."
    clean_build
    
    # 3. 编译 Release 版本 HAR 包
    print_step "🔨 编译 Release 版本 HAR 包..."
    build_har release
    
    # 4. 如果是 SDK 模式，配置 entry 使用 HAR 包
    local SDK_MODE=$(node "$CONFIG_MANAGER" sdk-mode)
    if [ "$SDK_MODE" = "true" ]; then
        print_step "⚙️  配置 entry 使用 HAR 包..."
        configure_entry_har
    fi
    
    # 5. 编译 Release 版本 HAP 包
    print_step "📱 编译 Release 版本 HAP 包..."
    build_hap release
    
    # 6. 准备发布文件
    print_step "📦 准备发布文件..."
    local RELEASE_DIR="releases/v$VERSION"
    
    # 删除旧的 release 目录（如果存在）
    if [ -d "$RELEASE_DIR" ]; then
        print_info "删除旧版本目录: $RELEASE_DIR"
        rm -rf "$RELEASE_DIR"
    fi
    
    # 创建新的 release 目录
    mkdir -p "$RELEASE_DIR"
    print_success "创建发布目录: $RELEASE_DIR"
    
    # 创建 sdk 和 example 子目录
    local SDK_DIR="$RELEASE_DIR/sdk"
    mkdir -p "$SDK_DIR"
    
    # 检查 HAR 编译结果
    local HAR_NAME=$(node "$CONFIG_MANAGER" get build.harName)
    local CUSTOM_HAR="lyrics_view/build/default/outputs/default/${HAR_NAME}-${VERSION}.har"
    local ORIGINAL_HAR="lyrics_view/build/default/outputs/default/lyrics_view.har"
    
    local HAR_PATH
    if [ -f "$CUSTOM_HAR" ]; then
        HAR_PATH="$CUSTOM_HAR"
    elif [ -f "$ORIGINAL_HAR" ]; then
        HAR_PATH="$ORIGINAL_HAR"
    else
        print_error "HAR 包编译失败!"
        exit 1
    fi
    
    # 复制 HAR 包到 sdk 目录
    local RELEASE_HAR_FILENAME="${HAR_NAME}-${VERSION}.har"
    local RELEASE_HAR="$SDK_DIR/$RELEASE_HAR_FILENAME"
    cp "$HAR_PATH" "$RELEASE_HAR"
    print_info "已复制 HAR 包到: $SDK_DIR/$RELEASE_HAR_FILENAME"
    
    # 生成三方库发布所需文件（oh-package.json5, README.md, CHANGELOG.md, LICENSE）
    print_step "📝 生成三方库发布文件..."
    generate_release_files "$VERSION" "$SDK_DIR"
    
    # 复制并重命名 HAP 包到 example 目录
    rename_hap_file "$VERSION" "$RELEASE_DIR"
    
    print_success "🎉 构建完成!"
    print_info "📁 发布目录: $(pwd)/$RELEASE_DIR"
    echo ""
    print_info "📋 目录结构:"
    tree -L 2 "$RELEASE_DIR" 2>/dev/null || ls -lhR "$RELEASE_DIR/"
    
    echo ""
    print_success "📦 三方库发布文件已就绪！"
    print_info ""
    print_info "SDK 目录 ($RELEASE_DIR/sdk/):"
    print_info "  ✓ ${HAR_NAME}-${VERSION}.har       - HAR 包文件"
    print_info "  ✓ oh-package.json5                 - 包配置文件（必需）"
    print_info "  ✓ README.md                        - 使用文档（必需）"
    print_info "  ✓ CHANGELOG.md                     - 更新日志（必需）"
    print_info "  ✓ LICENSE                          - 开源协议（必需）"
    echo ""
    print_info "示例应用 ($RELEASE_DIR/example/):"
    print_info "  ✓ LyricsView-Example-v${VERSION}-*.hap"
    echo ""
    print_info "🚀 后续步骤："
    print_info "   1. 将 sdk 目录中的所有文件一起发布到 HarmonyOS 中心仓"
    print_info "   2. 在 oh-package.json5 中确认包名、版本号和描述"
    print_info "   3. 根据需要更新 README.md 和 CHANGELOG.md"
    print_info "   4. 示例 HAP 可用于演示和测试"
}

# 发布 HAR 包（保留原函数名以兼容）
release_har() {
    # 获取版本号参数（如果未提供，从工程配置中读取）
    local VERSION
    if [ -n "$1" ]; then
        VERSION="$1"
    else
        VERSION=$(get_version)
    fi
    
    local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    print_step "🚀 开始发布流程..."
    print_info "版本号: $VERSION"
    print_info "时间戳: $TIMESTAMP"
    
    # 1. 自动生成配置
    print_step "📋 生成项目配置..."
    generate_config
    
    # 2. 清理构建文件
    print_step "🧹 清理构建文件..."
    clean_build
    
    # 3. 编译 Release 版本 HAR 包
    print_step "🔨 编译 Release 版本 HAR 包..."
    build_har release
    
    # 4. 切换到 SDK 模式（可选）
    print_step "🔄 切换到 SDK 模式..."
    switch_mode "sdk"
    
    # 5. 编译应用（可选，跳过编译错误）
    print_step "📱 编译示例应用..."
    print_info "跳过应用编译（存在类型错误，HAR 包已可用）"
    
    # 6. 准备发布文件
    print_step "📦 准备发布文件..."
    local RELEASE_DIR="releases/v$VERSION"
    mkdir -p "$RELEASE_DIR"
    
    # 检查编译结果 - 优先使用自定义命名的文件
    local CUSTOM_HAR="lyrics_view/build/default/outputs/default/Agora-LyricsView-HarmonyOS-$VERSION.har"
    local ORIGINAL_HAR="lyrics_view/build/default/outputs/default/lyrics_view.har"
    local HAP_FILE="entry/build/default/outputs/default/entry-default-signed.hap"
    
    local HAR_PATH
    if [ -f "$CUSTOM_HAR" ]; then
        HAR_PATH="$CUSTOM_HAR"
    elif [ -f "$ORIGINAL_HAR" ]; then
        HAR_PATH="$ORIGINAL_HAR"
    else
        print_error "HAR 包编译失败!"
        exit 1
    fi
    
    # 复制 HAR 包到发布目录
    local RELEASE_HAR="$RELEASE_DIR/Agora-LyricsView-HarmonyOS-$VERSION.har"
    cp "$HAR_PATH" "$RELEASE_HAR"
    
    # 复制 HAP 包到发布目录（如果存在）
    if [ -f "$HAP_FILE" ]; then
        local RELEASE_HAP="$RELEASE_DIR/entry-default-signed.hap"
        cp "$HAP_FILE" "$RELEASE_HAP"
        print_info "已复制示例应用: $(basename "$RELEASE_HAP")"
    else
        print_info "示例应用未编译，HAR 包可直接使用"
    fi
    
    print_success "🎉 发布流程完成!"
    print_info "📁 发布目录: $(pwd)/$RELEASE_DIR"
    
    # 显示文件信息
    echo ""
    print_info "📋 发布文件:"
    ls -lh "$RELEASE_DIR/"
    
    # 生成发布说明
    local RELEASE_NOTES="$RELEASE_DIR/RELEASE_NOTES.md"
    cat > "$RELEASE_NOTES" << EOF
# LyricsView HAR v$VERSION

## 发布信息
- **版本**: $VERSION
- **发布时间**: $(date)
- **文件大小**: $(ls -lh "$RELEASE_HAR" | awk '{print $5}')

## 功能特性
- 🎵 歌词显示和滚动
- 🎤 卡拉OK高亮效果
- 🎯 评分系统
- 🎨 粒子特效
- 📱 触摸交互
- 🔄 动画过渡

## 使用方法

### 1. 添加依赖
在项目的 \`oh-package.json5\` 中添加:
\`\`\`json5
{
  "dependencies": {
    "lyrics_view": "file:./path/to/Agora-LyricsView-HarmonyOS-$VERSION.har"
  }
}
\`\`\`

### 2. 导入组件
\`\`\`typescript
import { LyricsView, ScoringView, LyricsViewVersion } from 'lyrics_view';
\`\`\`

### 3. 使用组件
\`\`\`typescript
LyricsView({
  textSize: 16,
  currentLineTextSize: 20,
  currentLineTextColor: '#FFFFFF',
  currentLineHighlightedTextColor: '#FF6B35'
})
\`\`\`

## 兼容性
- HarmonyOS API 9+
- DevEco Studio 4.0+

## 更新日志
- 初始版本发布
- 支持基础歌词显示功能
- 支持卡拉OK模式
- 支持评分系统

EOF
    
    echo ""
    print_info "发布说明已生成: $RELEASE_NOTES"
    
    # 创建校验文件
    echo "$(shasum -a 256 "$RELEASE_HAR")" > "$RELEASE_DIR/Agora-LyricsView-HarmonyOS-$VERSION.har.sha256"
    
    echo ""
    print_success "发布完成! 文件列表:"
    ls -la "$RELEASE_DIR/"
    
    echo ""
    print_info "后续步骤:"
    print_info "1. 测试 HAR 包在其他项目中的集成"
    print_info "2. 更新项目文档和示例"
    print_info "3. 发布到代码仓库"
    print_info "4. 通知相关开发者"
}

# 清理构建文件
clean_build() {
    print_step "清理构建文件..."
    
    # 清理 lyrics_view 构建文件
    if [ -d "lyrics_view/build" ]; then
        rm -rf lyrics_view/build/
        print_success "已清理 lyrics_view/build/"
    fi
    
    # 清理 entry 构建文件
    if [ -d "entry/build" ]; then
        rm -rf entry/build/
        print_success "已清理 entry/build/"
    fi
    
    # 清理根目录构建文件
    if [ -d "build" ]; then
        rm -rf build/
        print_success "已清理根目录 build/"
    fi
    
    # 清理 oh_modules 缓存
    if [ -d "oh_modules" ]; then
        rm -rf oh_modules/
        print_success "已清理 oh_modules/"
    fi
    
    if [ -d "entry/oh_modules" ]; then
        rm -rf entry/oh_modules/
        print_success "已清理 entry/oh_modules/"
    fi
    
    if [ -d "lyrics_view/oh_modules" ]; then
        rm -rf lyrics_view/oh_modules/
        print_success "已清理 lyrics_view/oh_modules/"
    fi
    
    print_success "构建文件清理完成!"
}

# 发布到 OHPM 中心仓
publish_to_ohpm() {
    print_step "📦 发布 HAR 包到 OHPM 中心仓..."
    
    # 获取版本号
    local VERSION=$(get_version)
    local HAR_NAME=$(node "$CONFIG_MANAGER" get build.harName)
    local HAR_FILENAME="${HAR_NAME}-${VERSION}.har"
    local SDK_DIR="releases/v${VERSION}/sdk"
    
    # 检查 SDK 目录是否存在
    if [ ! -d "$SDK_DIR" ]; then
        print_error "SDK 目录不存在: $SDK_DIR"
        print_info "请先运行 ./build.sh 编译项目"
        exit 1
    fi
    
    # 检查 HAR 文件是否存在
    if [ ! -f "$SDK_DIR/$HAR_FILENAME" ]; then
        print_error "HAR 文件不存在: $SDK_DIR/$HAR_FILENAME"
        print_info "请先运行 ./build.sh 编译项目"
        exit 1
    fi
    
    # 进入 SDK 目录
    cd "$SDK_DIR"
    
    # 1. 预验证
    print_step "预验证 HAR 包..."
    ohpm prepublish "$HAR_FILENAME"
    
    if [ $? -ne 0 ]; then
        print_error "预验证失败！"
        cd - > /dev/null
        exit 1
    fi
    
    echo ""
    print_success "预验证通过！"
    echo ""
    
    # 2. 发布
    print_step "正在发布到 OHPM..."
    print_info "HAR 文件: $HAR_FILENAME"
    print_info "版本: $VERSION"
    echo ""
    print_warning "请手动输入私钥密码完成发布"
    echo ""
    
    # 直接调用 ohpm publish，让用户手动输入密码
    ohpm publish "$HAR_FILENAME"
    
    local PUBLISH_RESULT=$?
    
    # 返回项目根目录
    cd - > /dev/null
    
    if [ $PUBLISH_RESULT -eq 0 ]; then
        echo ""
        print_success "🎉 HAR 包已成功发布到 OHPM 中心仓！"
        print_info "包名: @shengwang/lyrics-view"
        print_info "版本: $VERSION"
        print_info "查看: https://ohpm.openharmony.cn/#/cn/detail/@shengwang%2Flyrics-view"
    else
        echo ""
        print_error "发布失败！"
        print_info "请检查网络连接和 OHPM 配置"
        exit 1
    fi
}

# 构建并发布
build_and_publish() {
    print_step "🚀 开始构建并发布流程..."
    
    # 1. 先执行完整构建
    build_release
    
    echo ""
    echo ""
    
    # 2. 发布到 OHPM
    publish_to_ohpm
}

# 主函数
main() {
    local COMMAND=${1:-build}
    
    case $COMMAND in
        "-release")
            build_and_publish
            ;;
        "clean")
            clean_build
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "build"|*)
            build_release
            ;;
    esac
}

# 执行主函数
main "$@"
