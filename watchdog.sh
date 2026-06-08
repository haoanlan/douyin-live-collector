#!/bin/bash
# 直播监控看门狗 - 检测守护进程是否存活，死了就重启

MONITOR_DIR="/home/node/.openclaw/douyin-live"
LOG_FILE="/tmp/monitor.log"
PID_FILE="/tmp/monitor.pid"

# 检查 monitor.js 是否在运行
if pgrep -f "node monitor.js" > /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [OK] monitor.js is running (PID: $(pgrep -f 'node monitor.js'))"
    exit 0
fi

# 没在运行，重启
echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] monitor.js not running, restarting..."
cd "$MONITOR_DIR"
nohup node monitor.js >> "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "$NEW_PID" > "$PID_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') [RESTARTED] monitor.js started with PID: $NEW_PID"

# 等待3秒确认启动成功
sleep 3
if pgrep -f "node monitor.js" > /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [OK] monitor.js restarted successfully"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] monitor.js failed to start!"
    exit 1
fi
