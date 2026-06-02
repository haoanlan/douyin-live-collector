# 🎥 douyin-live — 抖音直播数据采集

> 🤖 抖音直播间数据采集与可视化分析工具。后台守护进程持续运行，自动检测开播/下播，采集弹幕/礼物/进场数据并生成可视化报告。
>
> **⚠️ 本项目仅供学习和研究使用，请勿用于任何商业或非法用途。使用者应遵守相关法律法规及平台规则。**

![Node](https://img.shields.io/badge/node-%3E%3D18-brightgreen)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20amd64-blue)
![License](https://img.shields.io/badge/license-MIT-green)

[查看许可证 →](LICENSE)

---

## 功能

- **实时监控** — WebSocket 连接 douyinLive 代理，监听弹幕/礼物/进场/在线人数
- **自动录制** — 检测到开播自动开始记录，下播自动保存
- **数据持久化** — 每 10 秒直写 MySQL，弹幕、礼物、进场记录完整
- **图片报告** — Playwright 截图生成可视化直播报告（含AI叙事总结）
- **飞书推送** — 下播报告通过飞书 Open API（tenant_access_token）自动推送到飞书群
- **用户画像** — 通过 secUid 查询用户资料，生成身份卡片
- **连击去重** — 智能识别抖音礼物连击帧，去重后统计真实送礼数据
- **任意切换房间** — 改配置重启即可切换监控目标

## 架构

```
抖音直播间 ←WebSocket→ douyinLive代理(二进制, 1088端口)
                               ↓
                    monitor.js (常驻守护进程)
                    ├─ dbFlush() 每10秒 → MySQL
                    │   ├─ streamers      主播信息
                    │   ├─ sessions       直播场次/统计
                    │   ├─ danmaku        弹幕记录（含飘屏弹幕）
                    │   ├─ gifts          礼物记录（含连击元数据、星守护）
                    │   ├─ members        进场记录
                    │   └─ online_records  在线人数时序
                    │
                    └─ 下播后 → report-image.js (Playwright截图)
                                    └── feishu-send.js → 飞书群（tenant_access_token 自动推送）
```

## 快速开始

### 前置条件

- Node.js ≥ 18
- MySQL 数据库
- Chromium（report-image.js 截图用，Playwright 自动安装）

### 安装

```bash
# 克隆仓库
git clone https://github.com/haoanlan/douyin-live-collector.git
cd douyin-live-collector

# 安装依赖
npm install

# 安装 Playwright 浏览器
npx playwright install chromium
```

### 配置

#### 1. douyin cookie

复制 `config.example.yaml` 为 `config.yaml`，填入抖音 cookie：

```yaml
cookie:
  douyin: "你的抖音登录cookie"
port: "1088"
monitor:
  poll_interval: 15s
  notify_interval: 30s
```

> cookie 获取方式：浏览器登录抖音网页版 → F12 → Application → Cookies → 复制完整 cookie 字符串

#### 2. 环境变量

复制 `.env.example` 为 `.env`，填入数据库连接信息：

```bash
DB_HOST=localhost
DB_PORT=3306
DB_USER=douyinlive
DB_PASSWORD=***
DB_NAME=douyinlive
DB_POOL=5
```

> 表结构会在首次启动时自动创建。`.env` 已加入 `.gitignore`，不会被提交。

#### 3. 房间号

编辑 `runtime-config.json`：

```json
{
  "room_id": "72288034336",
  "check_interval_seconds": 30,
  "reconnect_delay_seconds": 10,
  "save_json": false,
  "feishu": {
    "chat_id": "oc_xxx"
  }
}
```

| 字段 | 说明 |
|------|------|
| `room_id` | 抖音直播间房间号 |
| `save_json` | 是否同时保存 JSON 文件（默认 false，纯 MySQL） |
| `feishu.chat_id` | 飞书群 chat_id，下播报告自动推送到此群 |

> 主播排名自动排除直播间账号（room_author），无需手动配置。如需额外排除其他主播名，可在 `runtime-config.json` 添加 `exclude_hosts` 数组。

## 使用

### 守护进程

```bash
# 启动守护
node monitor.js

# 停止守护
node monitor.js stop

# 查看状态
node monitor.js status

# 手动快照（立即生成报告发飞书群）
node monitor.js snapshot
```

### 报告生成

```bash
# 生成当前 session 报告 → 保存到本地
node report-image.js --output

# 指定 session ID
node report-image.js --session 265 --output

# 从 JSON 文件加载（而非 MySQL）
node report-image.js --json --output
```

> 下播后报告自动通过飞书 Open API（tenant_access_token）推送到飞书群，无需手动操作。

### 礼物榜单

```bash
# 生成送给某人的礼物榜单（谁送给了XX）
node report-image.js --to "主播名" --output

# 生成某用户的送礼明细
node report-image.js --user "用户名" --output

# 全场礼物排名
node report-image.js --all --output
node report-image.js --all --highlight "用户名" --output
```

### 用户查询

```bash
# 查询神秘人/用户，生成身份卡片
node user-card.js <secUid> [数据库昵称] --output
```

身份卡片包含：头像 + 真名 + 抖音号 + 粉丝/关注 + 签名

### 其他工具

```bash
# 合并多场 session 数据
# 编辑 merge-sessions.js 顶部的 sessionIds 数组
node merge-sessions.js

# 生成感谢榜图片
node thanks-rank.js

# WS 消息调试
node ws-debug.js <room_id>
```

## 消息处理

| 消息类型 | 处理方式 |
|---------|---------|
| `WebcastChatMessage` | 弹幕 → `danmaku` 表 |
| `WebcastGiftMessage` | 礼物 → `gifts` 表（含连击元数据） |
| `WebcastMemberMessage` | 进场 → `members` 表 |
| `WebcastLikeMessage` | 点赞计数 |
| `WebcastSocialMessage` | 关注计数 |
| `WebcastRoomStatsMessage` | 在线人数时序 |
| `WebcastScreenChatMessage` | 飘屏弹幕 → `danmaku` 表（标记 `[飘屏]` 前缀） |
| `WebcastPrivilegeScreenChatMessage` | 特权飘屏 → `danmaku` 表（标记 `[飘屏]` 前缀） |
| `WebcastFansclubMessage` | action=7 星守护 → 转为礼物记录（1280钻/月）；其他 action 不记录 |

## 数据表

### gifts（礼物记录）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | |
| session_id | INT FK | 关联 sessions |
| nickname | VARCHAR | 送礼人昵称 |
| avatar | TEXT | 送礼人头像 URL |
| user_display_id | VARCHAR | 送礼人 displayId |
| user_sec_uid | VARCHAR | 送礼人 secUid |
| gift_name | VARCHAR | 礼物名 |
| diamond_count | INT | 单价（钻） |
| repeat_count | INT | 数量 |
| total_diamonds | INT | 总价 = 单价 × 数量 |
| to_nickname | VARCHAR | 收礼人 |
| to_user_display_id | VARCHAR | 收礼人 displayId |
| to_user_sec_uid | VARCHAR | 收礼人 secUid |
| combo_count | INT | 当前帧连击数 |
| repeat_end | TINYINT | 连击终结帧标记（1=终结） |
| send_type | TINYINT | 发送类型（1/4=连击 5=单次） |
| create_time | BIGINT | 时间戳（毫秒） |

> ⚠️ 送礼统计必须用 `comboDedupGifts()` 去重，不能直接 SUM。去重 key：`(user_display_id, gift_name, to_user_display_id)` 三分组。

### danmaku（弹幕记录）

| 字段 | 说明 |
|------|------|
| nickname | 用户名 |
| content | 弹幕内容（飘屏弹幕带 `[飘屏]` 前缀） |
| user_display_id | 用户 displayId |
| user_sec_uid | 用户 secUid |
| create_time | 时间戳 |

### members（进场记录）

| 字段 | 说明 |
|------|------|
| nickname | 用户名 |
| avatar | 头像 URL |
| user_display_id | 用户 displayId |
| user_sec_uid | 用户 secUid |
| create_time | 时间戳 |

## 连击去重逻辑

礼物入库时**全量写入**（所有 WebSocket 帧都进 MySQL），在**加载数据时**做 combo 去重：

- 函数 `comboDedupGifts(gifts)`（位于 report-image.js）
- 按 `(user_display_id || nickname, gift_name, to_user_display_id)` 三分组
- `comboCount` 连续递增(1→2→3) → 同一连击
- 同值+`repeatEnd` → 归入该组
- 帧序错乱时（如 combo 4 在 3 之前到达）→ 按 combo_count 排序取最高
- 每组只保留 comboCount 最大的那条

## 直播总结

report-image.js 的直播总结采用叙事体生成，根据实际数据动态组织语言：

- **热度定调** — 根据进场人数判断（>3000 "开播即爆" / >1000 "人气不错"）
- **弹幕氛围** — 分析弹幕内容（拉关注 / 打call / 笑声），而非列数字
- **进场节奏** — 用时段分布说故事（"晚上18点开播就直接拉满"）
- **关注收尾** — 自然收束（"结束时95人点了关注"）

## 切换房间

```bash
node monitor.js stop
# 编辑 runtime-config.json 修改 room_id
node monitor.js
```

## 致谢

- [douyinLive](https://github.com/飘渺/fork) — WebSocket 代理二进制
- [Learn-Python](https://github.com/fxxk888/Learn-Python) — 粉丝团信息管理工具（灵感参考）

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
