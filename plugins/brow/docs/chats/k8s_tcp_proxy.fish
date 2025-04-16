function k8s_tcp_proxy
    # 设置默认值
    set -l env ""
    set -l ip ""
    set -l local_port 5433 # 本地端口默认为5433
    set -l remote_port 5432 # 远程端口默认为5432
    set -l service_name service # 服务名称默认值

    # 用户可以指定参数
    if test (count $argv) -ge 2
        set env $argv[1]
        set ip $argv[2]

        # 如果提供了第三个参数，设置为本地端口
        if test (count $argv) -ge 3
            set local_port $argv[3]
        end

        # 如果提供了第四个参数，设置为远程端口
        if test (count $argv) -ge 4
            set remote_port $argv[4]
        end

        # 如果提供了第五个参数，设置为服务名称
        if test (count $argv) -ge 5
            set service_name $argv[5]
        end

        echo "目标环境: $env"
        echo "目标IP: $ip"
        echo "本地端口: $local_port"
        echo "远程服务端口: $remote_port"
        echo "服务名称: $service_name"
    else
        echo "用法: k8s_tcp_proxy <环境> <IP> [本地端口=5433] [远程端口=5432] [服务名称=service]"
        return 1
    end

    echo "创建临时代理Pod..."

    # 创建临时YAML文件
    set -l tmp_yaml (mktemp)
    echo "apiVersion: v1
kind: Pod
metadata:
  name: socat-proxy
  labels:
    app: temp-$service_name-proxy
spec:
  containers:
  - name: socat
    image: alpine:latest
    command:
    - sh
    - -c
    - |
      apk add --no-cache socat
      socat TCP-LISTEN:$remote_port,fork TCP:$ip:$remote_port &
      sleep infinity
    ports:
    - containerPort: $remote_port" >$tmp_yaml

    # 我们不再需要切换全局context，而是在每个命令中指定context
    # 这使脚本在多tmux窗口环境中更可靠
    set -l k8s_context oasis-$env-aks-admin

    # 应用YAML创建Pod，显式指定context
    kubectl --context=$k8s_context apply -f $tmp_yaml >/dev/null

    # 删除临时YAML文件
    rm $tmp_yaml

    # 等待Pod就绪，显式指定context
    echo "等待代理Pod就绪..."
    kubectl --context=$k8s_context wait --for=condition=Ready pod/socat-proxy --timeout=60s >/dev/null

    if test $status -ne 0
        echo "错误: Pod未能在规定时间内就绪"
        kubectl --context=$k8s_context delete pod socat-proxy >/dev/null 2>&1
        return 1
    end

    echo "代理就绪！现在可以通过localhost:$local_port连接到服务"
    echo "连接信息："
    echo "  主机: localhost"
    echo "  端口: $local_port"
    echo "  远程服务: $ip:$remote_port"
    echo ""
    echo "按Ctrl+C终止代理并清理资源"

    # 启动端口转发，显式指定context
    kubectl --context=$k8s_context port-forward pod/socat-proxy $local_port:$remote_port

    # 清理函数
    function cleanup
        set -l ctx $argv[1]
        echo ""
        echo "清理资源..."
        kubectl --context=$ctx delete pod socat-proxy >/dev/null 2>&1
        echo "代理已关闭，资源已清理"
        return 0
    end

    # 如果port-forward正常退出，清理资源
    cleanup $k8s_context

    # 不再需要切换回原始context，因为我们没有改变全局context
end
