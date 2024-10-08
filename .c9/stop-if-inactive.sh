# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Modifications made by inagozeixd, 2024/08/18
# Description of modifications:
# - Amazon Linux 2023 のみサポート
# - Cloud9 IDEリスペクト 元プロジェクトの階層構造（/home/ec2-user/.c9/）はそのまま継承
# - VSCode Extensions の Remote-SSH から利用想定のため、vfs-worker周りは削除

#!/bin/bash
set -euo pipefail
CONFIG=$(cat /home/ec2-user/.c9/autoshutdown-configuration)
SHUTDOWN_TIMEOUT=${CONFIG#*=}
if ! [[ $SHUTDOWN_TIMEOUT =~ ^[0-9]*$ ]]; then
    echo "shutdown timeout is invalid"
    exit 1
fi
is_shutting_down() {
    is_shutting_down_al2023 &> /dev/null
}
is_shutting_down_al2023() {
    local TIMEOUT
    TIMEOUT=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager ScheduledShutdown)
    if [ "$?" -ne "0" ]; then
        return 1
    fi
    local SHUTDOWN_TIMESTAMP
    SHUTDOWN_TIMESTAMP="$(echo $TIMEOUT | awk "{print \$3}")"
    if [ $SHUTDOWN_TIMESTAMP == "0" ] || [ $SHUTDOWN_TIMESTAMP == "18446744073709551615" ]; then
        return 1
    else
        return 0
    fi
}
is_vscode_connected() {
    # Remote-SSH接続時に生じるプロセスが存在するかチェック（あればRemote-SSHでEC2に接続中）
    pgrep -u ec2-user -f .vscode-server/cli/ -a | grep -F -- '--type=fileWatcher' | grep -v -F 'shellIntegration-bash.sh' >/dev/null || \
    pgrep -u ec2-user -f /home/ec2-user/.vscode-server/code- -a >/dev/null
}

if is_shutting_down; then
    # FIXME: /home/ec2-user/.c9/autoshutdown-timestamp はシャットダウン時刻追跡用に残してるが、現状bash中で読み取って使うような処理はない。要る？
    if [[ ! $SHUTDOWN_TIMEOUT =~ ^[0-9]+$ ]] || is_vscode_connected; then
        sudo shutdown -c
        echo > "/home/ec2-user/.c9/autoshutdown-timestamp"
    else
        TIMESTAMP=$(date +%s)
        echo "$TIMESTAMP" > "/home/ec2-user/.c9/autoshutdown-timestamp"
    fi
else
    if [[ $SHUTDOWN_TIMEOUT =~ ^[0-9]+$ ]] && ! is_vscode_connected; then
        sudo shutdown -h $SHUTDOWN_TIMEOUT
    fi
fi