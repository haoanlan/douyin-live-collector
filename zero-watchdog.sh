#!/bin/bash
# 零token消耗的watchdog - 纯bash，不调任何LLM
# 每30分钟由crontab调用

MONITOR_PID=$(ps aux | grep 'monitor.js' | grep -v grep | awk '{print $2}')
LOG_FILE="/tmp/watchdog.log"

if [ -z "$MONITOR_PID" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] monitor.js 不在运行，正在重启..." >> "$LOG_FILE"
    cd /home/node/.openclaw/douyin-live && nohup node monitor.js --daemon 72288034336 > /tmp/monitor.log 2>&1 &
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 已重启 monitor.js (PID: $!)" >> "$LOG_FILE"
else
    # 一切正常，什么都不做（零token）
    exit 0
fi
