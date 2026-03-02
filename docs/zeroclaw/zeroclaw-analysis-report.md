# ZeroClaw 项目分析报告

> **项目路径**: `/opt/gopath/src/github.com/wangfeiping/zeroclaw/`  
> **分析时间**: 2026年2月25日  
> **版本**: v0.1.7

---

## 一、项目概述

**ZeroClaw** 是一个用 **Rust** 编写的高性能 AI 助手运行时操作系统，定位为 "零开销、零妥协、100% Rust"。

### 核心理念
- **极简**: 能在 $10 的硬件上运行，内存占用 < 5MB
- **极速**: 启动时间 < 10ms（对比 OpenClaw 的 >500s）
- **可插拔**: 所有核心系统均为 Trait 驱动，可零代码替换实现
- **安全**: 默认安全设计，严格沙箱、显式白名单、工作区隔离

### 项目标语
> "Zero overhead. Zero compromise. 100% Rust. 100% Agnostic."

---

## 二、技术架构

### 2.1 编程语言与统计

| 指标 | 数据 |
|------|------|
| **主要语言** | Rust (100%) |
| **Rust 版本要求** | 1.87+ |
| **源代码文件数** | 216 个 .rs 文件 |
| **总代码行数** | ~146,000 行 |
| **二进制大小** | ~8.8 MB (Release 构建) |
| **内存占用** | < 5MB 运行时 |

### 2.2 核心模块架构

ZeroClaw 采用 **Trait 驱动架构**，所有子系统均可通过配置更换实现：

| 子系统 | Trait 名称 | 功能说明 |
|--------|-----------|----------|
| **AI 模型** | `Provider` | 支持 OpenAI、Anthropic、OpenRouter、Ollama、vLLM 等 |
| **通讯渠道** | `Channel` | CLI、Telegram、Discord、Slack、WhatsApp、Matrix、Email 等 |
| **记忆系统** | `Memory` | SQLite 混合搜索、PostgreSQL、Markdown、Lucid 等后端 |
| **工具系统** | `Tool` | Shell、文件、浏览器、Cron、Git、截图、硬件控制等 |
| **可观测性** | `Observer` | 日志、Prometheus、OpenTelemetry |
| **运行时** | `RuntimeAdapter` | Native、Docker 沙箱 |
| **安全策略** | `SecurityPolicy` | 网关配对、沙箱、白名单、速率限制 |
| **隧道** | `Tunnel` | Cloudflare、Tailscale、ngrok、自定义 |

### 2.3 记忆系统（全栈搜索引擎）

ZeroClaw 实现了 **零外部依赖** 的自定义记忆系统：

| 层级 | 实现方式 |
|------|----------|
| **向量数据库** | SQLite BLOB 存储 + 余弦相似度搜索 |
| **关键词搜索** | FTS5 虚拟表 + BM25 评分 |
| **混合合并** | 自定义加权合并算法 |
| **嵌入模型** | OpenAI / 自定义 URL / 禁用 |
| **分块** | 基于行的 Markdown 分块，保留标题 |

---

## 三、主要功能特性

### 3.1 多通道通讯支持

支持 12+ 种通讯渠道：

- **即时通讯**: Telegram、Discord、Slack、Matrix、WhatsApp、iMessage、Signal
- **企业通讯**: Lark(飞书)、DingTalk(钉钉)、QQ
- **传统渠道**: Email、IRC、Nostr
- **Webhook**: 自定义 HTTP 回调

### 3.2 多 AI 提供商支持

| 提供商 | 状态 | 备注 |
|--------|------|------|
| OpenAI | ✅ | GPT 系列 |
| Anthropic | ✅ | Claude 系列 |
| OpenRouter | ✅ | 聚合多模型 |
| Ollama | ✅ | 本地部署 |
| vLLM | ✅ | 高性能推理 |
| llama.cpp | ✅ | 边缘设备 |
| Osaurus | ✅ | macOS MLX 推理 |
| GLM/Zhipu | ✅ | 智谱 AI |
| 自定义端点 | ✅ | OpenAI 兼容 API |

### 3.3 工具系统

内置 15+ 种工具：

- **系统工具**: shell、file_read、file_write、memory_search
- **网络工具**: web_fetch、web_search、http_request
- **自动化**: cron、schedule、git
- **浏览器**: browser_open、browser_click、screenshot
- **硬件**: usb_discover、peripheral_flash
- **通知**: pushover
- **外部集成**: composio (1000+ OAuth 应用)

### 3.4 硬件支持

- **USB 设备枚举** (Linux/macOS/Windows)
- **串口通信** (STM32、Arduino)
- **Raspberry Pi GPIO**
- **Nucleo 开发板** (通过 probe-rs)
- **固件烧录** (ESP32、Arduino UNO)

---

## 四、项目结构

```
zeroclaw/
├── src/                     # 核心源代码 (~146k 行)
│   ├── main.rs             # CLI 入口点 (~69KB)
│   ├── lib.rs              # 库导出
│   ├── agent/              # AI 代理逻辑
│   ├── channels/           # 通讯渠道实现
│   ├── providers/          # AI 提供商实现
│   ├── tools/              # 工具系统
│   ├── memory/             # 记忆系统
│   ├── gateway/            # HTTP 网关服务器
│   ├── daemon/             # 后台守护进程
│   ├── security/           # 安全模块
│   ├── cron/               # 定时任务
│   ├── hardware/           # 硬件发现
│   └── ...
├── crates/                 # 工作区子 crate
│   └── robot-kit/          # 机器人工具包
├── docs/                   # 文档 (14 个子目录)
├── python/                 # Python 伴侣包 (zeroclaw-tools)
├── firmware/               # 嵌入式固件 (ESP32、Arduino)
├── web/                    # Web 前端仪表板
├── benches/                # 性能基准测试
├── tests/                  # 集成测试
├── scripts/                # 安装和辅助脚本
└── Cargo.toml             # Rust 项目配置
```

---

## 五、性能对比

与同类产品对比（0.8GHz 边缘设备）：

| 指标 | OpenClaw | NanoBot | PicoClaw | **ZeroClaw** |
|------|----------|---------|----------|--------------|
| **语言** | TypeScript | Python | Go | **Rust** |
| **内存** | >1GB | >100MB | <10MB | **<5MB** |
| **启动时间** | >500s | >30s | <1s | **<10ms** |
| **二进制大小** | ~28MB | N/A | ~8MB | **~8.8MB** |
| **硬件成本** | Mac Mini $599 | Linux SBC ~$50 | Linux Board $10 | **$10** |

---

## 六、安全设计

### 6.1 多层安全防护

| 层级 | 机制 | 状态 |
|------|------|------|
| **网关绑定** | 默认 127.0.0.1，拒绝 0.0.0.0 除非配置隧道 | ✅ |
| **配对认证** | 6 位一次性密码，Bearer Token 认证 | ✅ |
| **文件系统隔离** | workspace_only 默认开启，14 个系统目录 + 4 个敏感文件被屏蔽 | ✅ |
| **隧道访问** | 无活动隧道时拒绝公网绑定 | ✅ |
| **频道白名单** | 空白名单 = 拒绝所有入站消息（显式拒绝） | ✅ |

### 6.2 沙箱支持

- **Landlock** (Linux): 文件系统访问控制
- **Bubblewrap**: 命名空间隔离
- **Docker**: 容器化运行时

---

## 七、部署方式

### 7.1 安装方式

```bash
# Homebrew
brew install zeroclaw

# 一键安装脚本
curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/main/scripts/install.sh | bash

# 从源码构建
git clone https://github.com/zeroclaw-labs/zeroclaw.git
cd zeroclaw
cargo build --release
```

### 7.2 预构建二进制文件支持

- **Linux**: x86_64、aarch64、armv7
- **macOS**: x86_64、aarch64 (Apple Silicon)
- **Windows**: x86_64

### 7.3 服务管理

支持 systemd (用户级) 和 OpenRC (Alpine 系统级)：

```bash
zeroclaw service install
zeroclaw service start
zeroclaw service status
```

---

## 八、配置系统

配置文件位置: `~/.zeroclaw/config.toml`

### 8.1 关键配置项

```toml
api_key = "sk-..."
default_provider = "openrouter"
default_model = "anthropic/claude-sonnet-4-6"
default_temperature = 0.7

[memory]
backend = "sqlite"  # sqlite | lucid | postgres | markdown | none
auto_save = true
embedding_provider = "none"

[gateway]
port = 42617
host = "127.0.0.1"
require_pairing = true

[autonomy]
level = "supervised"  # readonly | supervised | full
workspace_only = true

[runtime]
kind = "native"  # native | docker
```

---

## 九、生态系统

### 9.1 Python 伴侣包

`zeroclaw-tools` 提供 LangGraph 集成：

```python
from zeroclaw_tools import create_agent, shell

agent = create_agent(
    tools=[shell],
    model="glm-5",
    api_key="your-key"
)
```

### 9.2 身份系统

支持两种身份格式：
- **OpenClaw**: Markdown 文件 (IDENTITY.md、SOUL.md、USER.md)
- **AIEOS**: JSON 标准化格式 (AI Entity Object Specification v1.1)

### 9.3 技能系统 (Skills)

TOML 清单 + SKILL.md 指令的可插拔技能：

```bash
zeroclaw skills list
zeroclaw skills install <source>
zeroclaw skills audit <skill>
```

---

## 十、开发与贡献

### 10.1 构建系统

```bash
cargo build --release           # 标准发布构建
cargo build --profile release-fast  # 快速构建 (需 16GB+ RAM)
cargo test                      # 运行测试套件
cargo clippy --locked         # 静态检查
```

### 10.2 项目治理

- **许可证**: MIT OR Apache-2.0 (双许可)
- **贡献者**: 27+
- **社区**: 来自 Harvard、MIT、Sundai.Club 的学生和成员

### 10.3 官方渠道

- **网站**: https://zeroclawlabs.ai
- **GitHub**: https://github.com/zeroclaw-labs/zeroclaw
- **X**: @zeroclawlabs
- **Telegram**: @zeroclawlabs

---

## 十一、总结与评估

### 优势

1. **极致性能**: Rust 实现带来极低的内存占用和启动时间
2. **架构先进**: Trait 驱动设计实现真正的可插拔架构
3. **功能丰富**: 支持 12+ 通讯渠道、10+ AI 提供商、15+ 工具
4. **安全第一**: 多层安全防护，默认安全设计
5. **硬件友好**: 支持边缘设备和嵌入式硬件
6. **生态完整**: 文档齐全、社区活跃、多语言支持

### 潜在挑战

1. **构建复杂度**: 从源码构建需要较高资源 (2GB+ RAM、6GB+ 磁盘)
2. **Rust 门槛**: 贡献和定制需要 Rust 知识
3. **新兴项目**: 相比 OpenClaw 等成熟项目，生态尚在建设中

### 适用场景

- **边缘设备部署**: Raspberry Pi、嵌入式 Linux
- **低资源环境**: 容器、Serverless
- **高安全性要求**: 金融、企业内网
- **多频道机器人**: Telegram、Discord、Slack 统一接入
- **硬件集成**: IoT、机器人、自动化

---

## 十二、关键指标一览

| 指标 | 数值 |
|------|------|
| 项目版本 | v0.1.7 |
| 代码行数 | ~146,000 行 |
| Rust 文件数 | 216 个 |
| 通讯渠道 | 12+ |
| AI 提供商 | 10+ |
| 内置工具 | 15+ |
| 内存占用 | < 5MB |
| 启动时间 | < 10ms |
| 二进制大小 | ~8.8 MB |
| 支持平台 | Linux、macOS、Windows、ARM |
| 文档语言 | 6 种 (英/中/日/俄/法/越) |

---

*报告生成时间: 2026-02-25 19:48 CST*  
*分析工具: OpenClaw Agent with web_fetch and file analysis tools*
