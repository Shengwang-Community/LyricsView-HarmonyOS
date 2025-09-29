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
    echo "  (无参数)               编译 Release 版本 HAR 包"
    echo "  clean                  清理所有构建文件"
    echo "  help                   显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  ./build.sh              # 编译 Release 版本"
    echo "  ./build.sh clean        # 清理构建文件"
    echo ""
    echo "🚀 推荐使用: ./build.sh  # 一条命令搞定所有操作"
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
    
    # 根据SDK模式处理entry导入方式
    if [ "$SDK_MODE" = "true" ]; then
        print_info "SDK模式为HAR包模式，配置entry使用HAR包导入"
        
        # 确保entry/libs目录存在
        local ENTRY_LIBS_DIR="$PROJECT_ROOT/entry/libs"
        if [ ! -d "$ENTRY_LIBS_DIR" ]; then
            mkdir -p "$ENTRY_LIBS_DIR"
        fi
        
        # 复制HAR包到entry/libs目录
        local HAR_SOURCE="$PROJECT_ROOT/releases/v1.0.0/Agora-LyricsView-HarmonyOS-1.0.0.har"
        local HAR_TARGET="$ENTRY_LIBS_DIR/AgoraLyricsView.har"
        
        if [ -f "$HAR_SOURCE" ]; then
            cp "$HAR_SOURCE" "$HAR_TARGET"
            print_info "已复制HAR包到: $HAR_TARGET"
            
            # 修改entry/oh-package.json5使用HAR包导入
            local ENTRY_PACKAGE="$PROJECT_ROOT/entry/oh-package.json5"
            if [ -f "$ENTRY_PACKAGE" ]; then
                # 使用sed替换导入路径
                sed -i '' 's|"@shengwang/lyrics-view": "file:../lyrics_view"|"@shengwang/lyrics-view": "file:./libs/AgoraLyricsView.har"|g' "$ENTRY_PACKAGE"
                sed -i '' 's|"path": "../lyrics_view"|"path": "./libs/AgoraLyricsView.har"|g' "$ENTRY_PACKAGE"
                
                # 更新entry源码中的导入语句
                updateEntryImports "har"
                
                print_info "已更新entry导入配置为HAR包模式"
            fi
        else
            print_warn "HAR包不存在: $HAR_SOURCE，将使用源码导入"
        fi
    else
        print_info "SDK模式为源码模式，使用源码导入"
        
        # 确保entry使用源码导入
        local ENTRY_PACKAGE="$PROJECT_ROOT/entry/oh-package.json5"
        if [ -f "$ENTRY_PACKAGE" ]; then
            # 检查是否需要切换到源码导入
            if grep -q "AgoraLyricsView.har" "$ENTRY_PACKAGE"; then
                # 切换到源码导入，但保持@shengwang/lyrics-view名称
                sed -i '' 's|"@shengwang/lyrics-view": "file:./libs/AgoraLyricsView.har"|"@shengwang/lyrics-view": "file:../lyrics_view"|g' "$ENTRY_PACKAGE"
                sed -i '' 's|"path": "./libs/AgoraLyricsView.har"|"path": "../lyrics_view"|g' "$ENTRY_PACKAGE"
                
                print_info "已切换entry导入配置为源码模式（保持@shengwang/lyrics-view名称）"
            fi
            
            # 删除HAR包文件（源码模式不需要）
            local HAR_FILE="$PROJECT_ROOT/entry/libs/AgoraLyricsView.har"
            if [ -f "$HAR_FILE" ]; then
                rm "$HAR_FILE"
                print_info "已删除HAR包文件: $HAR_FILE"
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
    
    # 进入 lyrics_view 目录
    cd lyrics_view
    
    # 获取版本信息
    local VERSION=$(get_version)
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
    
    # 4. 准备发布文件
    print_step "📦 准备发布文件..."
    local RELEASE_DIR="releases/v$VERSION"
    mkdir -p "$RELEASE_DIR"
    
    # 检查编译结果
    local CUSTOM_HAR="lyrics_view/build/default/outputs/default/Agora-LyricsView-HarmonyOS-$VERSION.har"
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
    
    # 复制 HAR 包到发布目录
    local RELEASE_HAR="$RELEASE_DIR/Agora-LyricsView-HarmonyOS-$VERSION.har"
    cp "$HAR_PATH" "$RELEASE_HAR"
    
    print_success "🎉 构建完成!"
    print_info "📁 发布目录: $(pwd)/$RELEASE_DIR"
    print_info "📋 发布文件:"
    ls -lh "$RELEASE_DIR/"
    
    echo ""
    print_info "🚀 您现在可以："
    print_info "   1. 使用 HAR 包: Agora-LyricsView-HarmonyOS-$VERSION.har"
    print_info "   2. 集成到其他项目中使用"
    print_info "   3. 查看配置: entry/src/main/ets/utils/BuildConfig.ets"
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

# 主函数
main() {
    local COMMAND=${1:-build}
    
    case $COMMAND in
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
