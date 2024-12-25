#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

HOSTS_FILE='config/hosts'

# 帮助信息
usage() {
    echo -e "${YELLOW}cAdvisor 管理脚本${NC}"
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  install    - 安装或更新 cAdvisor"
    echo "  uninstall  - 卸载 cAdvisor"
    echo "  status     - 查看 cAdvisor 运行状态"
    echo "  -h, --help - 显示此帮助信息"
}

# 检查ansible是否安装
check_ansible() {
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}错误: 未找到 ansible-playbook 命令${NC}"
        echo "请先安装 Ansible: sudo apt install ansible 或 sudo yum install ansible"
        exit 1
    fi
}

# 执行ansible-playbook命令
run_playbook() {
    local tags=$1
    local desc=$2
    echo -e "${GREEN}正在${desc}...${NC}"
    ansible-playbook -i "$HOSTS_FILE" playbook/deploy-cadvisor.yml --tags "$tags"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${desc}完成${NC}"
    else
        echo -e "${RED}${desc}失败${NC}"
        exit 1
    fi
}

# 主程序
main() {
    # 检查是否提供了参数
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    # 检查ansible是否安装
    check_ansible

    # 处理命令行参数
    case "$1" in
        install)
            run_playbook "install,status" "安装 cAdvisor"
            ;;
        uninstall)
            read -p "确定要卸载 cAdvisor 吗？(y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                run_playbook "uninstall" "卸载 cAdvisor"
            fi
            ;;
        status)
            run_playbook "status" "检查 cAdvisor 状态"
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            usage
            exit 1
            ;;
    esac
}

# 执行主程序
main "$@" 
