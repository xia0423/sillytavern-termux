#!/data/data/com.termux/files/usr/bin/bash

# SillyTavern Termux 一键部署脚本
# 作者: 夏夏
# 版本: 5.0.0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ST_DIR="$HOME/SillyTavern"
CONFIG_FILE="$ST_DIR/config.yaml"
BACKUP_DIR="$HOME/SillyTavern_Backup"
BASHRC="$HOME/.bashrc"

# 清屏函数
clear_screen() {
    clear
}

# 打印标题
print_header() {
    clear_screen
    echo -e "${CYAN}~~~~ SillyTavern & 夏夏 ~~~~${NC}"
}

# 打印信息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

# 打印成功
print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

# 打印警告
print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

# 打印错误
print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 等待用户按键
wait_for_key() {
    echo ""
    read -p "按回车键继续..."
}

# 检查 SillyTavern 是否已安装
check_st_installed() {
    if [ -d "$ST_DIR" ]; then
        return 0
    else
        return 1
    fi
}

# 检查 Node.js 是否已安装
check_nodejs() {
    if command -v node &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 安装依赖
install_dependencies() {
    print_header
    echo ""
    print_info "正在安装系统依赖..."

    print_info "更新软件包列表..."
    pkg update -y

    print_info "升级已安装的软件包（自动处理配置文件冲突）..."
    DEBIAN_FRONTEND=noninteractive pkg upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

    print_info "安装必要依赖..."
    pkg install -y git nodejs-lts python build-essential

    if [ $? -eq 0 ]; then
        print_success "依赖安装完成"
    else
        print_error "依赖安装失败"
    fi
}

# 克隆 SillyTavern
clone_sillytavern() {
    print_header
    echo ""

    if check_st_installed; then
        print_warning "SillyTavern 已存在于 $ST_DIR"
        wait_for_key
        return
    fi

    print_info "正在克隆 SillyTavern 仓库..."
    cd "$HOME"
    git clone -b release https://github.com/SillyTavern/SillyTavern.git

    if [ $? -eq 0 ]; then
        cd "$ST_DIR"
        print_info "正在安装 npm 依赖..."
        npm install

        if [ $? -eq 0 ]; then
            print_success "SillyTavern 安装完成"
        else
            print_error "npm 依赖安装失败"
        fi
    else
        print_error "克隆仓库失败"
    fi
    wait_for_key
}

# 启动酒馆
start_tavern() {
    print_header
    echo ""

    if ! check_st_installed; then
        print_error "SillyTavern 未安装，请先安装"
        wait_for_key
        return
    fi

    print_info "正在启动 SillyTavern..."
    cd "$ST_DIR"
    node server.js
}

# 更新酒馆
update_tavern() {
    print_header
    echo ""

    if ! check_st_installed; then
        print_error "SillyTavern 未安装"
        wait_for_key
        return
    fi

    print_info "正在更新 SillyTavern..."
    cd "$ST_DIR"

    # 保存本地更改
    git stash

    # 拉取最新代码
    git pull origin release

    if [ $? -eq 0 ]; then
        print_info "正在更新 npm 依赖..."
        npm install

        # 恢复本地更改
        git stash pop

        print_success "更新完成"
    else
        print_error "更新失败"
    fi
    wait_for_key
}

# 修改内存限制
modify_memory_limit() {
    print_header
    echo ""

    if ! check_st_installed; then
        print_error "SillyTavern 未安装"
        wait_for_key
        return
    fi

    cd "$ST_DIR"

    if [ ! -f "start.sh" ]; then
        print_error "未找到 start.sh 文件"
        wait_for_key
        return
    fi

    # 备份 start.sh
    if [ ! -f "start.sh.bak" ]; then
        cp start.sh start.sh.bak
        print_info "已备份 start.sh"
    fi

    echo ""
    print_info "当前内存限制配置："
    grep "max-old-space-size" start.sh || echo "未设置内存限制"
    echo ""

    read -p "请输入新的内存限制（MB，范围1024-8192）: " mem_limit

    # 验证输入
    if ! [[ "$mem_limit" =~ ^[0-9]+$ ]]; then
        print_error "请输入有效的数字"
        wait_for_key
        return
    fi

    if [ "$mem_limit" -lt 1024 ] || [ "$mem_limit" -gt 8192 ]; then
        print_error "请输入 1024-8192 范围内的数值"
        wait_for_key
        return
    fi

    # 修改内存限制
    if grep -q 'node --max-old-space-size=[0-9]\+ "server.js" "\$@"' start.sh; then
        sed -i "s/node --max-old-space-size=[0-9]\+ \"server.js\" \"\\\$@\"/node --max-old-space-size=${mem_limit} \"server.js\" \"\\\$@\"/" start.sh
        print_success "内存限制已设置为 ${mem_limit} MB"
    elif grep -q 'node "server.js" "\$@"' start.sh; then
        sed -i "s/node \"server.js\" \"\\\$@\"/node --max-old-space-size=${mem_limit} \"server.js\" \"\\\$@\"/" start.sh
        print_success "已插入内存限制参数，现为 ${mem_limit} MB"
    else
        print_warning "未检测到标准 node 启动命令，未做更改"
    fi

    wait_for_key
}

# 酒馆版本切换
switch_tavern_version() {
    print_header
    echo ""

    if ! check_st_installed; then
        print_error "SillyTavern 未安装"
        wait_for_key
        return
    fi

    cd "$ST_DIR"

    print_info "正在获取可用版本..."
    git fetch --tags

    echo ""
    print_info "最近的 10 个版本:"
    echo ""
    git tag --sort=-version:refname | head -10 | nl
    echo ""

    echo "快速选择:"
    echo "1. 最新 release 分支"
    echo "2. staging 分支"
    echo "3. 输入具体版本号 (如: 1.12.5)"
    echo ""

    read -p "请选择 (1-3): " choice

    case $choice in
        1)
            target="release"
            ;;
        2)
            target="staging"
            ;;
        3)
            read -p "请输入版本号: " target
            ;;
        *)
            print_error "无效选择"
            wait_for_key
            return
            ;;
    esac

    print_info "正在切换到 $target..."
    git stash

    if [ "$target" = "release" ] || [ "$target" = "staging" ]; then
        # 分支切换：直接切换并 pull
        git checkout "$target"
        git pull origin "$target" 2>/dev/null
    else
        # 版本号切换：切换到 release 分支，然后重置到该版本标签
        git checkout release
        git reset --hard "$target"
        print_info "已切换到 release 分支的 $target 版本"
    fi

    print_info "正在重新安装依赖..."
    npm install

    git stash pop 2>/dev/null

    print_success "版本切换完成，依赖已更新"
    wait_for_key
}

# 一键卸载酒馆和脚本
uninstall_all() {
    print_header
    echo ""
    print_error "警告: 此操作将完全删除 SillyTavern 和脚本"
    print_warning "建议先导出数据备份"
    echo ""
    read -p "确认卸载? 输入 'YES' 继续: " confirm

    if [ "$confirm" = "YES" ]; then
        print_info "正在卸载..."

        # 删除 SillyTavern
        if check_st_installed; then
            rm -rf "$ST_DIR"
            print_success "SillyTavern 已删除"
        fi

        # 删除脚本
        if [ -f "$HOME/install.sh" ]; then
            rm -f "$HOME/install.sh"
            print_success "脚本已删除"
        fi

        # 删除自启动配置
        if [ -f "$BASHRC" ]; then
            sed -i '/install.sh/d' "$BASHRC"
            sed -i '/SillyTavern/d' "$BASHRC"
            print_success "自启动配置已删除"
        fi

        print_success "卸载完成"
        echo ""
        print_info "感谢使用！"
        sleep 2
        exit 0
    else
        print_info "操作已取消"
    fi
    wait_for_key
}

# 酒馆管理菜单
tavern_management_menu() {
    while true; do
        print_header
        echo ""
        echo -e "${YELLOW}~~~~ 酒馆管理 ~~~~${NC}"
        echo "0. 返回上级"
        echo "1. 修改内存限制"
        echo "2. 酒馆版本切换"
        echo "3. 一键卸载酒馆与脚本"
        echo "~~~~~~~~~~~~~~~~~~"
        read -p "请选择操作 (0-3): " choice

        case $choice in
            0) return ;;
            1) modify_memory_limit ;;
            2) switch_tavern_version ;;
            3) uninstall_all ;;
            *) print_error "无效选择" ; wait_for_key ;;
        esac
    done
}

# 查看依赖版本
check_versions() {
    print_header
    echo ""
    print_info "系统依赖版本信息："
    echo ""

    echo -e "${CYAN}Node.js 版本:${NC}"
    node --version
    echo ""

    echo -e "${CYAN}npm 版本:${NC}"
    npm --version
    echo ""

    echo -e "${CYAN}Git 版本:${NC}"
    git --version
    echo ""

    echo -e "${CYAN}Python 版本:${NC}"
    python --version
    echo ""

    if check_st_installed; then
        echo -e "${CYAN}SillyTavern 版本:${NC}"
        cd "$ST_DIR"
        git describe --tags 2>/dev/null || git rev-parse --short HEAD
        echo ""
    fi

    wait_for_key
}

# 修复依赖环境
fix_dependencies() {
    print_header
    echo ""
    print_info "正在修复依赖环境..."

    # 更新包管理器
    pkg update -y

    # 重新安装核心依赖
    pkg install -y git nodejs-lts python build-essential

    # 如果 SillyTavern 已安装，重新安装 npm 依赖
    if check_st_installed; then
        cd "$ST_DIR"
        print_info "正在重新安装 npm 依赖..."
        rm -rf node_modules package-lock.json
        npm install
    fi

    print_success "依赖环境修复完成"
    wait_for_key
}

# 导出酒馆数据
export_tavern_data() {
    print_header
    echo ""

    if ! check_st_installed; then
        print_error "SillyTavern 未安装"
        wait_for_key
        return
    fi

    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/ST_data_$(date +%Y%m%d_%H%M%S).tar.gz"

    print_info "正在导出酒馆数据..."
    cd "$ST_DIR"
    tar -czf "$BACKUP_FILE" data/ config.yaml public/settings.json 2>/dev/null

    if [ $? -eq 0 ]; then
        print_success "数据已导出到: $BACKUP_FILE"
    else
        print_error "导出失败"
    fi
    wait_for_key
}

# 导出酒馆本体
export_tavern_full() {
    print_header
    echo ""

    if ! check_st_installed; then
        print_error "SillyTavern 未安装"
        wait_for_key
        return
    fi

    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/ST_full_$(date +%Y%m%d_%H%M%S).tar.gz"

    print_info "正在导出酒馆完整备份..."
    cd "$HOME"
    tar -czf "$BACKUP_FILE" SillyTavern/

    if [ $? -eq 0 ]; then
        print_success "完整备份已导出到: $BACKUP_FILE"
    else
        print_error "导出失败"
    fi
    wait_for_key
}

# 导入酒馆数据
import_tavern_data() {
    print_header
    echo ""

    if ! check_st_installed; then
        print_error "SillyTavern 未安装"
        wait_for_key
        return
    fi

    print_info "备份文件列表:"
    echo ""
    ls -lh "$BACKUP_DIR"/ST_data_*.tar.gz 2>/dev/null | nl
    echo ""

    read -p "请输入要导入的备份文件完整路径: " backup_file

    if [ -f "$backup_file" ]; then
        print_warning "此操作将覆盖现有数据"
        read -p "确认继续? (y/n): " confirm

        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            cd "$ST_DIR"
            tar -xzf "$backup_file"
            print_success "数据导入完成"
        else
            print_info "操作已取消"
        fi
    else
        print_error "文件不存在"
    fi
    wait_for_key
}

# 导入酒馆本体
import_tavern_full() {
    print_header
    echo ""

    print_info "完整备份文件列表:"
    echo ""
    ls -lh "$BACKUP_DIR"/ST_full_*.tar.gz 2>/dev/null | nl
    echo ""

    read -p "请输入要导入的备份文件完整路径: " backup_file

    if [ -f "$backup_file" ]; then
        print_warning "此操作将完全替换现有 SillyTavern"
        read -p "确认继续? (y/n): " confirm

        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            if check_st_installed; then
                rm -rf "$ST_DIR"
            fi

            cd "$HOME"
            tar -xzf "$backup_file"
            print_success "酒馆本体导入完成"
        else
            print_info "操作已取消"
        fi
    else
        print_error "文件不存在"
    fi
    wait_for_key
}

# 系统管理菜单
system_management_menu() {
    while true; do
        print_header
        echo ""
        echo -e "${YELLOW}~~~~ 系统管理 ~~~~${NC}"
        echo "0. 返回上级"
        echo "1. 查看依赖版本"
        echo "2. 修复依赖环境"
        echo "3. 导出酒馆数据"
        echo "4. 导出酒馆本体"
        echo "5. 导入酒馆数据"
        echo "6. 导入酒馆本体"
        echo "~~~~~~~~~~~~~~~~~~"
        read -p "请选择操作 (0-6): " choice

        case $choice in
            0) return ;;
            1) check_versions ;;
            2) fix_dependencies ;;
            3) export_tavern_data ;;
            4) export_tavern_full ;;
            5) import_tavern_data ;;
            6) import_tavern_full ;;
            *) print_error "无效选择" ; wait_for_key ;;
        esac
    done
}

# 关于脚本
about_script() {
    print_header
    echo ""
    echo -e "${CYAN}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
    echo -e "${GREEN}  SillyTavern Termux 部署脚本${NC}"
    echo -e "${CYAN}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
    echo ""
    echo -e "${YELLOW}作者:${NC} 夏夏"
    echo -e "${YELLOW}版本:${NC} 5.0.0"
    echo -e "${YELLOW}项目:${NC} SillyTavern Termux 一键部署"
    echo ""
    echo -e "${CYAN}功能特性:${NC}"
    echo "  • 一键安装和部署"
    echo "  • 自动依赖管理"
    echo "  • 数据备份和恢复"
    echo "  • 版本切换"
    echo ""
    echo -e "${CYAN}感谢使用!${NC}"
    echo ""
    wait_for_key
}

# 关于脚本菜单
about_menu() {
    while true; do
        print_header
        echo ""
        echo -e "${YELLOW}~~~~ 关于脚本 ~~~~${NC}"
        echo "0. 返回上级"
        echo "1. 作者信息"
        echo "~~~~~~~~~~~~~~~~~~"
        read -p "请选择操作 (0-1): " choice

        case $choice in
            0) return ;;
            1) about_script ;;
            *) print_error "无效选择" ; wait_for_key ;;
        esac
    done
}

# 设置开机自启动
setup_auto_start() {
    if [ ! -f "$BASHRC" ]; then
        touch "$BASHRC"
    fi

    # 检查是否已设置自启动
    if ! grep -q "install.sh" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# SillyTavern 一键脚本自启动" >> "$BASHRC"
        echo 'bash $HOME/install.sh' >> "$BASHRC"
    fi
}

# 主菜单
main_menu() {
    # 首次运行检查 - 检查依赖
    if ! check_nodejs; then
        install_dependencies
    fi

    # 检查 SillyTavern 是否已安装
    if ! check_st_installed; then
        clone_sillytavern
    fi

    # 设置开机自启动
    setup_auto_start

    while true; do
        print_header
        echo -e "${RED}0. 退出脚本${NC}"
        echo -e "${YELLOW}1. 启动酒馆${NC}"
        echo -e "${BLUE}2. 更新酒馆${NC}"
        echo -e "${YELLOW}3. 酒馆管理${NC}"
        echo -e "${YELLOW}4. 系统管理${NC}"
        echo -e "${PURPLE}5. 关于脚本${NC}"
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        read -p "请选择操作 (0-5): " choice

        case $choice in
            0)
                clear_screen
                print_success "感谢使用，再见!"
                exit 0
                ;;
            1) start_tavern ;;
            2) update_tavern ;;
            3) tavern_management_menu ;;
            4) system_management_menu ;;
            5) about_menu ;;
            *)
                print_error "无效选择"
                wait_for_key
                ;;
        esac
    done
}

# 脚本入口
main_menu
