#!/bin/bash
# ============================================================
# FitTracker 项目初始化脚本
# 用途：一键搭建 HarmonyOS (ArkUI) 开发环境，安装依赖，
#        验证构建工具链可用性。
# 运行方式：bash init.sh
# 适用平台：Windows (Git Bash / WSL) | macOS | Linux
# ============================================================

set -e

echo "=========================================="
echo "  FitTracker - 项目环境初始化"
echo "=========================================="

# ----------------------------------------------------------
# Step 1: 检查 Node.js 环境（ohpm 依赖 Node.js）
# ----------------------------------------------------------
echo ""
echo "[1/4] 检查 Node.js 环境..."
if command -v node &> /dev/null; then
    echo "  ✓ Node.js 版本: $(node --version)"
else
    echo "  ✗ 未检测到 Node.js。请先安装 Node.js (推荐 LTS 版本)。"
    echo "    下载地址: https://nodejs.org/"
    exit 1
fi

# ----------------------------------------------------------
# Step 2: 检查并安装 ohpm（HarmonyOS 包管理器）
# ----------------------------------------------------------
echo ""
echo "[2/4] 检查 ohpm (HarmonyOS Package Manager)..."
if command -v ohpm &> /dev/null; then
    echo "  ✓ ohpm 版本: $(ohpm --version)"
else
    echo "  ⚠ 未检测到 ohpm。"
    echo "    ohpm 随 DevEco Studio 一起安装，默认路径:"
    echo "    Windows: %USERPROFILE%\\AppData\\Local\\OpenHarmony\\Sdk\\toolchains\\ohpm"
    echo "    macOS:   ~/Library/OpenHarmony/Sdk/toolchains/bin/ohpm"
    echo "    Linux:   ~/local/OpenHarmony/Sdk/toolchains/ohpm"
    echo "    请确认 DevEco Studio 已安装，并将 ohpm 添加至 PATH 环境变量。"
    echo "    (若仅需初始化 Git 仓库可忽略此警告，继续执行后续步骤。)"
fi

# ----------------------------------------------------------
# Step 3: 安装项目依赖（oh_modules）
# ----------------------------------------------------------
echo ""
echo "[3/4] 安装项目依赖..."
if command -v ohpm &> /dev/null; then
    ohpm install
    echo "  ✓ 依赖安装完成 (oh_modules)"
else
    echo "  ⚠ 跳过：ohpm 未安装。请手动执行 'ohpm install' 安装依赖。"
fi

# ----------------------------------------------------------
# Step 4: 检查 hvigor 构建工具
# ----------------------------------------------------------
echo ""
echo "[4/4] 检查 hvigor 构建工具..."
if [ -f "./hvigorw" ] || [ -f "./hvigorw.bat" ]; then
    echo "  ✓ hvigor wrapper 已就绪。"
    echo "    构建命令: ./hvigorw assembleHap  (或 Windows: hvigorw.bat assembleHap)"
else
    echo "  ⚠ 未找到 hvigor wrapper。"
    echo "    hvigor wrapper 通常由 DevEco Studio 自动生成。"
    echo "    请使用 DevEco Studio 打开本项目以自动生成 hvigorw。"
fi

# ----------------------------------------------------------
# 完成提示
# ----------------------------------------------------------
echo ""
echo "=========================================="
echo "  初始化完成！"
echo "=========================================="
echo ""
echo "  项目概览:"
echo "    - 已完成 MVP 功能点: 27 (见 tasks.json)"
echo "    - 后续开发任务: 见 tasks.next.json"
echo "    - 目标平台: HarmonyOS 6.0.2(22)"
echo "    - 构建工具: hvigor"
echo "    - 包管理器: ohpm"
echo "    - UI 框架: ArkUI (声明式)"
echo ""
echo "  后续步骤:"
echo "    1. 使用 DevEco Studio 打开项目根目录"
echo "    2. 若首次打开，等待 IDE 自动同步 Gradle/hvigor 配置"
echo "    3. 连接设备或启动模拟器后运行调试"
echo "    4. 阅读 tasks.next.json 获取下一阶段任务"
echo "    5. 查看 项目开发日志.txt 跟踪开发进度"
echo ""
