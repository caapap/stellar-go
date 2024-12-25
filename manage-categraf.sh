#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置文件路径
CONFIG_FILE='playbook/config/stellar_ip.txt'
HOSTS_FILE='playbook/config/hosts'
stellar_ip=$(cat "$CONFIG_FILE")



# 帮助信息
usage() {
    echo -e "${YELLOW}Categraf 管理脚本${NC}"
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  install    - 安装或更新 Categraf"
    echo "  uninstall  - 卸载 Categraf"
    echo "  status     - 查看 Categraf 运行状态"
    echo "  config     - 配置星相平台IP和目标主机"
    echo "  -h, --help - 显示此帮助信息"
}

# 检查ansible是否安装
check_ansible() {
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}错误: 未找到 ansible-playbook 命令${NC}"
        echo "请先安装 Ansible: $ cd ansible-install/{系统架构} && sudo ./install_ansible.sh"
        exit 1
    fi
}

# 检查并配置
check_config() {
    # 确保配置目录存在
    mkdir -p $(dirname "$CONFIG_FILE")
    mkdir -p $(dirname "$HOSTS_FILE")

    # 配置星相平台IP
    read -p "请输入星相平台IP地址 (回车将使用默认值[$stellar_ip]): " stellar_tmp_ip
    stellar_tmp_ip=${stellar_tmp_ip:-$stellar_ip}
    echo "$stellar_tmp_ip" > "$CONFIG_FILE"
    echo -e "${GREEN}星相平台IP已更新: $stellar_tmp_ip${NC}"

    # 显示并确认hosts文件
    if [ -f "$HOSTS_FILE" ]; then
        echo -e "\n${YELLOW}>>>目标主机列表<<<${NC}"
        cat "$HOSTS_FILE"
        echo -e "\n${YELLOW}>>>目标主机列表<<<${NC}"
        while true; do
            echo -e "\n请选择操作："
            read -p "编辑目标主机列表[e/E], 继续执行[y/Y], 取消执行[n/N]: " choice
            case "$choice" in
                [eE])
                    ${EDITOR:-vi} "$HOSTS_FILE"
                    echo -e "\n${YELLOW}更新后的hosts文件内容:${NC}"
                    cat "$HOSTS_FILE"
                    ;;
                [yY])
                    return 0
                    ;;
                [nN])
                    echo "安装已取消。"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}无效的选择，请重试${NC}"
                    ;;
            esac
        done
    else
        echo -e "${YELLOW}hosts文件不存在，创建新的hosts文件...${NC}"
        echo "[categraf]" > "$HOSTS_FILE"
        ${EDITOR:-vi} "$HOSTS_FILE"
        echo -e "\n${YELLOW}hosts文件内容:${NC}"
        cat "$HOSTS_FILE"
        while true; do
            echo -e "\n请选择操作："
            echo "y/Y - 继续安装"
            echo "n/N - 取消安装"
            read -p "您的选择: " choice
            case "$choice" in
                [yY])
                    return 0
                    ;;
                [nN])
                    echo "安装已取消。"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}无效的选择，请重试${NC}"
                    ;;
            esac
        done
    fi
}

# 配置星相平台IP和目标主机
configure() {
    # 确保配置目录存在
    mkdir -p $(dirname "$CONFIG_FILE")
    mkdir -p $(dirname "$HOSTS_FILE")

    # 配置星相平台IP
    local var_IP=""
    if [ -f "$CONFIG_FILE" ]; then
        var_IP=$(cat "$CONFIG_FILE")
    fi

    read -p "请输入星相平台IP地址 (回车将使用默认值[$var_IP]): " Stellar_IP
    Stellar_IP=${Stellar_IP:-$var_IP}
    echo "$Stellar_IP" > "$CONFIG_FILE"
    echo -e "${GREEN}星相平台IP已更新: $Stellar_IP${NC}"

    # 显示并确认hosts文件
    if [ -f "$HOSTS_FILE" ]; then
        echo -e "\n${YELLOW}当前hosts文件内容:${NC}"
        cat "$HOSTS_FILE"
        read -p "是否需要修改hosts文件？(y/n): " edit_hosts
        if [[ "$edit_hosts" =~ ^[Yy]$ ]]; then
            ${EDITOR:-vi} "$HOSTS_FILE"
        fi
    else
        echo -e "${YELLOW}创建新的hosts文件...${NC}"
        echo "[categraf]" > "$HOSTS_FILE"
        ${EDITOR:-vi} "$HOSTS_FILE"
    fi

    echo -e "\n${GREEN}配置完成！${NC}"
    echo -e "星相平台IP: $Stellar_IP"
    echo -e "目标主机配置:"
    cat "$HOSTS_FILE"
}

# 添加新的状态解析函数
parse_ansible_status() {
    local ansible_output_file="/tmp/ansible_output.txt"
    local total_hosts=0
    local success_hosts=0
    local failed_hosts=0
    local operation_type=$1  # 新增参数，用于区分操作类型

    # 统计categraf_machine组的主机数
    total_hosts=$(awk '/^\[categraf_machine\]/{flag=1;next}/^\[/{flag=0}flag&&/^[0-9]/{count++}END{print count}' "$HOSTS_FILE")
    
    # 解析ansible输出获取成功和失败的主机数
    while read -r line; do
        if [[ "$line" == *"服务状态: inactive"* || "$line" == *"服务状态: 未安装"* ]]; then
            ((failed_hosts++))
        fi
    done < <(grep "服务状态:" "$ansible_output_file")

    success_hosts=$((total_hosts - failed_hosts))

    # 根操作类型显示不同的标题
    if [ "$operation_type" = "uninstall" ]; then
        echo -e "\n${YELLOW}卸载状态统计:${NC}"
    else
        echo -e "\n${YELLOW}部署状态统计:${NC}"
    fi
    
#    echo -e "总计主机数: ${total_hosts}"
    echo -e "运行成功数: ${success_hosts}/${total_hosts}"
    
    if [ "$operation_type" = "uninstall" ]; then
        # 卸载操作时，inactive 状态是正常的
        if [ "$failed_hosts" -eq "$total_hosts" ]; then
            echo -e "${GREEN}所有主机已成功卸载${NC}"
        else
            echo -e "${RED}部分主机卸载可能未成功，请检查具体状态${NC}"
        fi
    else
        # 安装或状态检查操作
        if [ "$failed_hosts" -gt 0 ]; then
            echo -e "${RED}运行失败数: ${failed_hosts} 台${NC}"
            echo -e "${YELLOW}请检查失败主机的具体错误信息，解决方法参考如下：${NC}"
            echo "1. 检查机器是否关闭防火墙"
            echo "2. 检查是否关闭selinux"
            echo "3. 查看ansible报错日志，检查系统是否缺少相关依赖（见./playbook/rpm/*.rpm）"
            echo "4. 若仍无法部署，参考星相部署文档3.2章节进行categraf手动部署"
        else
            echo -e "${GREEN}所有主机运行正常${NC}"
        fi
    fi
}

# 修改run_playbook函数
run_playbook() {
    local tags=$1
    local desc=$2
    echo -e "${GREEN}正在${desc}...${NC}"
    
    local ansible_output_file="/tmp/ansible_output.txt"
    export ANSIBLE_FORCE_COLOR=true
    
    ansible-playbook -i "$HOSTS_FILE" playbook/categraf.yml --tags "$tags" | tee "$ansible_output_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${desc}完成${NC}"
        if [[ "$tags" == *"status"* ]]; then
            # 传递操作类型参数给parse_ansible_status
            if [[ "$desc" == *"卸载"* ]]; then
                parse_ansible_status "uninstall"
            else
                parse_ansible_status "install"
            fi
        fi
    else
        echo -e "${RED}${desc}失败${NC}"
        if [[ "$tags" == *"status"* ]]; then
            parse_ansible_status
        fi
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
            check_config
            run_playbook "install" "安装 Categraf"
            run_playbook "status" "检查 Categraf 状态"
            ;;
        uninstall)
            # 检查配置文件是否存在
            if [ ! -f "$CONFIG_FILE" ] || [ ! -f "$HOSTS_FILE" ]; then
                echo -e "${RED}错误: 配置文件不存在，请先运行 config 命令配置${NC}"
                exit 1
            fi

            # 显示当前配置信息
            echo -e "\n${YELLOW}>>>当前hosts文件内容:<<<${NC}"
            cat "$HOSTS_FILE"
            echo -e "\n${YELLOW}>>>当前hosts文件内容:<<<${NC}"

            # 确认卸载
            read -p "确定要卸载 Categraf 吗？(y/Y): " choice
            case "$choice" in
                [yY])
                    run_playbook "uninstall" "卸载 Categraf"
                    ;;
                *)
                    echo "卸载已取消。"
                    ;;
            esac
            ;;
        status)
            check_config
            run_playbook "status" "检查 Categraf 状态"
            ;;
        config)
            configure
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
