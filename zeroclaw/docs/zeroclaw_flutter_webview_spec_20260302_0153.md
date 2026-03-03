# ZeroClaw + Flutter WebView 自动化新闻收集系统

## 完整需求分析与实施方案

**文档版本**: 1.0  
**生成时间**: 2026年03月02日 01:53 (北京时间)  
**项目路径**: `/opt/gopath/src/github.com/wangfeiping/zeroclaw/`  
**目标平台**: iOS & Android  
**开发框架**: Flutter + Rust (ZeroClaw)

---

## 目录

1. [项目概述](#1-项目概述)
2. [需求分析](#2-需求分析)
3. [技术架构](#3-技术架构)
4. [核心模块设计](#4-核心模块设计)
5. [实现方案](#5-实现方案)
6. [安全与隐私](#6-安全与隐私)
7. [开发计划](#7-开发计划)
8. [风险评估](#8-风险评估)
9. [附录](#9-附录)

---

## 1. 项目概述

### 1.1 项目背景

基于 ZeroClaw AI 助手运行时，开发一款移动端 App，能够：
- 自动浏览主流新闻网站收集信息
- 支持用户登录后的个性化内容获取
- 通过 AI Agent 智能分析和整理新闻
- 支持多种内容输出渠道

### 1.2 核心特性

| 特性 | 说明 |
|------|------|
| **浏览器伪装** | 模拟桌面/iOS Safari 浏览器，绕过反爬 |
| **登录持久化** | Cookie 安全存储，一次登录长期有效 |
| **AI 驱动** | ZeroClaw Agent 决策和控制采集流程 |
| **跨平台** | Flutter 实现，同时支持 iOS 和 Android |
| **多网站支持** | 适配主流新闻网站结构 |

---

## 2. 需求分析

### 2.1 功能需求

#### 2.1.1 浏览器自动化 (FR-001 ~ FR-005)

| ID | 需求 | 优先级 | 说明 |
|----|------|--------|------|
| FR-001 | 浏览器伪装 | P0 | 模拟 Chrome/Safari User-Agent 和指纹 |
| FR-002 | JavaScript 执行 | P0 | 在页面内执行采集脚本 |
| FR-003 | 自动滚动 | P1 | 模拟用户滚动加载更多内容 |
| FR-004 | 页面导航 | P0 | 自动跳转链接、返回、刷新 |
| FR-005 | 截图能力 | P2 | 页面截图用于 AI 视觉分析 |

#### 2.1.2 登录与身份管理 (FR-006 ~ FR-010)

| ID | 需求 | 优先级 | 说明 |
|----|------|--------|------|
| FR-006 | Cookie 持久化 | P0 | 加密保存登录状态 |
| FR-007 | 登录状态检测 | P0 | 自动检测是否需要重新登录 |
| FR-008 | 多账号支持 | P2 | 支持同一网站多个账号 |
| FR-009 | 会话刷新 | P1 | 自动续期即将过期的会话 |
| FR-010 | 安全存储 | P0 | Cookie 加密存储，防止泄露 |

#### 2.1.3 新闻采集 (FR-011 ~ FR-015)

| ID | 需求 | 优先级 | 说明 |
|----|------|--------|------|
| FR-011 | 智能提取 | P0 | 自动提取标题、内容、时间 |
| FR-012 | 网站适配 | P0 | 支持主流新闻网站规则 |
| FR-013 | 定时采集 | P1 | 按设定时间自动执行采集 |
| FR-014 | 增量更新 | P1 | 只采集新内容，避免重复 |
| FR-015 | 内容过滤 | P2 | 按关键词、时间筛选 |

#### 2.1.4 AI 集成 (FR-016 ~ FR-020)

| ID | 需求 | 优先级 | 说明 |
|----|------|--------|------|
| FR-016 | Agent 控制 | P0 | ZeroClaw Agent 控制采集流程 |
| FR-017 | 智能摘要 | P1 | AI 生成新闻摘要 |
| FR-018 | 分类标签 | P2 | 自动分类和打标签 |
| FR-019 | 多语言 | P2 | 翻译非中文内容 |
| FR-020 | 情感分析 | P3 | 分析新闻情感倾向 |

### 2.2 非功能需求

| ID | 需求 | 目标值 |
|----|------|--------|
| NFR-001 | 启动时间 | < 3 秒 |
| NFR-002 | 内存占用 | < 100 MB |
| NFR-003 | 采集速度 | 每页 < 5 秒 |
| NFR-004 | 稳定性 | 崩溃率 < 0.1% |
| NFR-005 | 安全性 | Cookie AES-256 加密 |

### 2.3 支持的新闻网站

#### 第一阶段（P0）
- Financial Times (ft.com)
- Reuters (reuters.com)
- Bloomberg (bloomberg.com)
- CNBC (cnbc.com)
- Wall Street Journal (wsj.com)

#### 第二阶段（P1）
- BBC News (bbc.com)
- The Guardian (theguardian.com)
- 财新网 (caixin.com)
- FT中文网 (ftchinese.com)
- X.com / Twitter

#### 第三阶段（P2）
- 微信公众号（需特殊处理）
- 知乎
- 雪球
- 其他垂直媒体

---

## 3. 技术架构

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (UI Layer)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   新闻列表   │  │   设置页    │  │    网站管理         │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │ MethodChannel / HTTP
┌──────────────────────────▼──────────────────────────────────┐
│              Core Service (Rust - ZeroClaw)                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Agent      │  │  Scheduler  │  │  Cookie Manager     │  │
│  │  决策引擎    │  │  定时任务   │  │  会话管理           │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │ FFI / JNI
┌──────────────────────────▼──────────────────────────────────┐
│           WebView Controller (Kotlin/Swift)                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  WebView    │  │  JS Bridge  │  │  Cookie Sync        │  │
│  │  实例管理    │  │  通信桥     │  │  Cookie 同步        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS
┌──────────────────────────▼──────────────────────────────────┐
│                      目标网站                                │
│  FT.com  Reuters  Bloomberg  WSJ  CNBC  ...                  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 模块关系图

```
                    ┌─────────────┐
                    │   User      │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌─────────┐  ┌─────────┐  ┌─────────┐
        │ Flutter │  │ WebView │  │  AI     │
        │   UI    │  │Controller│  │ Agent   │
        └────┬────┘  └────┬────┘  └────┬────┘
             │            │            │
             └────────────┼────────────┘
                          │
                    ┌─────▼─────┐
                    │ ZeroClaw  │
                    │   Core    │
                    │  (Rust)   │
                    └───────────┘
```

---

## 4. 核心模块设计

### 4.1 Cookie 管理模块

#### 4.1.1 数据模型

```rust
// Rust 层 Cookie 数据结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Cookie {
    pub name: String,
    pub value: String,
    pub domain: String,
    pub path: String,
    pub expires: Option<DateTime<Utc>>,
    pub secure: bool,
    pub http_only: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SiteSession {
    pub site_id: String,
    pub cookies: Vec<Cookie>,
    pub last_used: DateTime<Utc>,
    pub is_valid: bool,
}

#[derive(Debug)]
pub struct CookieManager {
    storage: EncryptedStorage,
    sessions: HashMap<String, SiteSession>,
}
```

#### 4.1.2 核心接口

```rust
impl CookieManager {
    /// 保存网站 Cookie
    pub async fn save_session(&self, site_id: &str, cookies: Vec<Cookie>) -> Result<()> {
        let session = SiteSession {
            site_id: site_id.to_string(),
            cookies,
            last_used: Utc::now(),
            is_valid: true,
        };
        
        // 加密存储
        let encrypted = self.encrypt_session(&session)?;
        self.storage.save(&format!("session_{}", site_id), &encrypted).await?;
        
        Ok(())
    }
    
    /// 获取网站 Cookie
    pub async fn get_session(&self, site_id: &str) -> Result<Option<SiteSession>> {
        if let Some(cached) = self.sessions.get(site_id) {
            return Ok(Some(cached.clone()));
        }
        
        let encrypted = self.storage.load(&format!("session_{}", site_id)).await?;
        if encrypted.is_empty() {
            return Ok(None);
        }
        
        let session = self.decrypt_session(&encrypted)?;
        Ok(Some(session))
    }
    
    /// 检查会话是否有效
    pub async fn is_session_valid(&self, site_id: &str) -> Result<bool> {
        if let Some(session) = self.get_session(site_id).await? {
            // 检查是否过期
            if let Some(expires) = session.cookies.iter().filter_map(|c| c.expires).min() {
                return Ok(expires > Utc::now());
            }
            return Ok(true);
        }
        Ok(false)
    }
    
    /// 清除过期会话
    pub async fn cleanup_expired(&self) -> Result<usize> {
        let mut cleaned = 0;
        for site_id in self.storage.list_keys().await? {
            if let Ok(Some(session)) = self.get_session(&site_id).await {
                if self.is_session_expired(&session) {
                    self.storage.delete(&format!("session_{}", site_id)).await?;
                    cleaned += 1;
                }
            }
        }
        Ok(cleaned)
    }
}
```

### 4.2 WebView 控制模块

#### 4.2.1 平台抽象层

```rust
// Trait 定义
#[async_trait]
pub trait WebViewController: Send + Sync {
    /// 加载 URL
    async fn load_url(&self, url: &str) -> Result<()>;
    
    /// 执行 JavaScript
    async fn execute_js(&self, script: &str) -> Result<String>;
    
    /// 设置 Cookie
    async fn set_cookies(&self, cookies: Vec<Cookie>) -> Result<()>;
    
    /// 获取当前 URL
    async fn current_url(&self) -> Result<String>;
    
    /// 截图
    async fn take_screenshot(&self) -> Result<Vec<u8>>;
    
    /// 模拟点击
    async fn simulate_click(&self, x: i32, y: i32) -> Result<()>;
    
    /// 模拟滚动
    async fn simulate_scroll(&self, delta_y: i32) -> Result<()>;
    
    /// 检查登录状态
    async fn check_login_status(&self) -> Result<bool>;
}

// Android 实现
pub struct AndroidWebViewController {
    jni_env: JNIEnv,
    webview_instance: GlobalRef,
}

#[async_trait]
impl WebViewController for AndroidWebViewController {
    async fn load_url(&self, url: &str) -> Result<()> {
        // JNI 调用 Android WebView
        self.call_void_method("loadUrl", &[url.into()])
    }
    
    async fn execute_js(&self, script: &str) -> Result<String> {
        self.call_string_method("evaluateJavascript", &[script.into()])
    }
    
    // ... 其他方法
}

// iOS 实现
pub struct IOSWebViewController {
    wkwebview: id,
}

#[async_trait]
impl WebViewController for IOSWebViewController {
    async fn load_url(&self, url: &str) -> Result<()> {
        // Objective-C Runtime 调用
        unsafe {
            let nsurl: id = msg_send![class!(NSURL), URLWithString: nsstring(url)];
            let request: id = msg_send![class!(NSURLRequest), requestWithURL: nsurl];
            let () = msg_send![self.wkwebview, loadRequest: request];
        }
        Ok(())
    }
    
    // ... 其他方法
}
```

#### 4.2.2 网站适配器

```rust
pub trait SiteAdapter: Send + Sync {
    fn site_id(&self) -> &str;
    fn base_url(&self) -> &str;
    fn login_url(&self) -> Option<&str>;
    
    /// 提取新闻列表
    async fn extract_news(&self, html: &str) -> Result<Vec<NewsItem>>;
    
    /// 检查登录状态
    async fn check_login(&self, controller: &dyn WebViewController) -> Result<bool>;
    
    /// 获取下一页链接
    async fn next_page(&self, controller: &dyn WebViewController) -> Result<Option<String>>;
}

// Financial Times 适配器
pub struct FTAdapter;

impl SiteAdapter for FTAdapter {
    fn site_id(&self) -> &str { "ft" }
    fn base_url(&self) -> &str { "https://www.ft.com" }
    fn login_url(&self) -> Option<&str> { Some("https://accounts.ft.com/login") }
    
    async fn extract_news(&self, _html: &str) -> Result<Vec<NewsItem>> {
        let script = r#"
            (function() {
                var items = [];
                document.querySelectorAll('[data-testid="card-headline"]').forEach(function(el) {
                    var link = el.closest('a');
                    if (link) {
                        items.push({
                            title: el.innerText.trim(),
                            url: link.href,
                            summary: link.querySelector('p')?.innerText || '',
                            time: document.querySelector('time')?.innerText || ''
                        });
                    }
                });
                return JSON.stringify(items);
            })();
        "#;
        
        // 通过 WebView 执行
        let result = controller.execute_js(script).await?;
        let items: Vec<NewsItem> = serde_json::from_str(&result)?;
        Ok(items)
    }
    
    async fn check_login(&self, controller: &dyn WebViewController) -> Result<bool> {
        let script = r#"
            document.querySelector('.user-menu') !== null ||
            document.querySelector('[data-testid="my-account"]') !== null
        "#;
        let result = controller.execute_js(script).await?;
        Ok(result == "true")
    }
}
```

### 4.3 AI Agent 集成

#### 4.3.1 Web 采集工具

```rust
pub struct WebNewsCollector {
    cookie_manager: Arc<CookieManager>,
    webview_factory: Arc<dyn WebViewFactory>,
    adapters: HashMap<String, Box<dyn SiteAdapter>>,
}

#[async_trait]
impl Tool for WebNewsCollector {
    fn name(&self) -> &str { "web_news_collect" }
    
    fn description(&self) -> &str {
        "自动浏览新闻网站并收集最新新闻"
    }
    
    fn parameters(&self) -> Value {
        json!({
            "type": "object",
            "properties": {
                "site": {
                    "type": "string",
                    "description": "目标网站 ID (ft, reuters, bloomberg 等)"
                },
                "category": {
                    "type": "string",
                    "description": "新闻分类 (world, business, tech 等)"
                },
                "limit": {
                    "type": "integer",
                    "description": "采集数量限制",
                    "default": 10
                }
            },
            "required": ["site"]
        })
    }
    
    async fn execute(&self, params: Value, context: &ToolContext) -> Result<ToolOutput> {
        let site_id = params["site"].as_str().unwrap();
        let limit = params["limit"].as_i64().unwrap_or(10) as usize;
        
        // 获取网站适配器
        let adapter = self.adapters.get(site_id)
            .ok_or_else(|| anyhow!("Unknown site: {}", site_id))?;
        
        // 检查登录状态
        if !self.cookie_manager.is_session_valid(site_id).await? {
            return Ok(ToolOutput {
                content: format!("需要登录 {}，请先登录该网站", site_id),
                data: json!({"status": "login_required", "site": site_id}),
            });
        }
        
        // 创建 WebView 实例
        let controller = self.webview_factory.create().await?;
        
        // 恢复 Cookie
        if let Some(session) = self.cookie_manager.get_session(site_id).await? {
            controller.set_cookies(session.cookies).await?;
        }
        
        // 加载网站
        controller.load_url(adapter.base_url()).await?;
        
        // 等待页面加载
        tokio::time::sleep(Duration::from_secs(3)).await;
        
        // 提取新闻
        let mut all_news = Vec::new();
        
        loop {
            let html = controller.execute_js("document.documentElement.outerHTML").await?;
            let news = adapter.extract_news(&html).await?;
            all_news.extend(news);
            
            if all_news.len() >= limit {
                break;
            }
            
            // 加载更多
            match adapter.next_page(&controller).await? {
                Some(next_url) => {
                    controller.load_url(&next_url).await?;
                    tokio::time::sleep(Duration::from_secs(2)).await;
                }
                None => break,
            }
        }
        
        // 保存 Cookie（可能有更新）
        let cookies = controller.get_cookies().await?;
        self.cookie_manager.save_session(site_id, cookies).await?;
        
        // 关闭 WebView
        controller.close().await?;
        
        // 截断结果
        all_news.truncate(limit);
        
        Ok(ToolOutput {
            content: format!("从 {} 采集了 {} 条新闻", site_id, all_news.len()),
            data: json!({
                "site": site_id,
                "count": all_news.len(),
                "news": all_news
            }),
        })
    }
}
```

---

## 5. 实现方案

### 5.1 项目结构

```
zeroclaw_mobile/
├── Cargo.toml                      # Rust 项目配置
├── src/
│   ├── lib.rs                      # 库入口
│   ├── cookie/
│   │   ├── mod.rs                  # Cookie 模块
│   │   ├── manager.rs              # CookieManager
│   │   ├── storage.rs              # 加密存储
│   │   └── encryption.rs           # 加密工具
│   ├── webview/
│   │   ├── mod.rs                  # WebView 模块
│   │   ├── controller.rs           # 控制器 Trait
│   │   ├── android.rs              # Android 实现
│   │   ├── ios.rs                  # iOS 实现
│   │   └── factory.rs              # 工厂模式
│   ├── adapter/
│   │   ├── mod.rs                  # 适配器模块
│   │   ├── ft.rs                   # Financial Times
│   │   ├── reuters.rs              # Reuters
│   │   ├── bloomberg.rs            # Bloomberg
│   │   └── registry.rs             # 适配器注册
│   ├── tools/
│   │   ├── mod.rs                  # 工具模块
│   │   └── web_collector.rs        # WebNewsCollector
│   └── ffi/
│       ├── mod.rs                  # FFI 接口
│       ├── android_bridge.rs       # Android JNI
│       └── ios_bridge.rs           # iOS 桥接
├── flutter/
│   ├── lib/
│   │   ├── main.dart               # Flutter 入口
│   │   ├── screens/
│   │   │   ├── home_screen.dart    # 首页
│   │   │   ├── news_screen.dart    # 新闻列表
│   │   │   ├── sites_screen.dart   # 网站管理
│   │   │   └── login_screen.dart   # 登录引导
│   │   ├── services/
│   │   │   ├── zeroclaw_service.dart   # ZeroClaw 服务
│   │   │   ├── webview_service.dart    # WebView 服务
│   │   │   └── cookie_service.dart     # Cookie 服务
│   │   ├── widgets/
│   │   │   ├── news_card.dart      # 新闻卡片
│   │   │   └── site_tile.dart      # 网站列表项
│   │   └── models/
│   │       ├── news.dart           # 新闻模型
│   │       └── site.dart           # 网站模型
│   └── pubspec.yaml                # Flutter 依赖
└── docs/
    └── api.md                      # API 文档
```

### 5.2 关键技术点实现

#### 5.2.1 浏览器指纹伪装

```rust
// webview/android.rs
impl AndroidWebViewController {
    fn setup_stealth_mode(&self) {
        let settings = self.get_settings();
        
        // 设置桌面 Chrome User-Agent
        settings.set_user_agent_string(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        );
        
        // 注入伪装脚本
        let spoof_script = r#"
            (function() {
                Object.defineProperty(navigator, 'webdriver', { get: () => false });
                Object.defineProperty(navigator, 'plugins', { 
                    get: () => [
                        {name: "Chrome PDF Plugin"},
                        {name: "Chrome PDF Viewer"},
                        {name: "Native Client"}
                    ]
                });
                window.chrome = { runtime: {} };
                console.log = function(){};  // 禁用 console
            })();
        "#;
        
        self.inject_script_on_load(spoof_script);
    }
}
```

#### 5.2.2 Cookie 加密存储

```rust
// cookie/encryption.rs
use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use ring::rand::{SecureRandom, SystemRandom};

pub struct CookieEncryption {
    cipher: Aes256Gcm,
}

impl CookieEncryption {
    pub fn new(key: &[u8; 32]) -> Self {
        Self {
            cipher: Aes256Gcm::new(key.into()),
        }
    }
    
    pub fn encrypt(&self, plaintext: &[u8]) -> Result<Vec<u8>> {
        let rng = SystemRandom::new();
        let mut nonce_bytes = [0u8; 12];
        rng.fill(&mut nonce_bytes)?;
        
        let nonce = Nonce::from_slice(&nonce_bytes);
        let ciphertext = self.cipher.encrypt(nonce, plaintext)
            .map_err(|e| anyhow!("Encryption failed: {}", e))?;
        
        // nonce + ciphertext
        let mut result = Vec::with_capacity(12 + ciphertext.len());
        result.extend_from_slice(&nonce_bytes);
        result.extend_from_slice(&ciphertext);
        
        Ok(result)
    }
    
    pub fn decrypt(&self, ciphertext: &[u8]) -> Result<Vec<u8>> {
        if ciphertext.len() < 12 {
            return Err(anyhow!("Invalid ciphertext"));
        }
        
        let nonce = Nonce::from_slice(&ciphertext[..12]);
        let plaintext = self.cipher.decrypt(nonce, &ciphertext[12..])
            .map_err(|e| anyhow!("Decryption failed: {}", e))?;
        
        Ok(plaintext)
    }
}
```

#### 5.2.3 Flutter 与 Rust 通信

```dart
// flutter/lib/services/zeroclaw_service.dart
import 'dart:ffi';
import 'dart:io';

class ZeroClawService {
  static final DynamicLibrary _lib = Platform.isAndroid
      ? DynamicLibrary.open('libzeroclaw.so')
      : DynamicLibrary.process();
  
  late final _init = _lib.lookupFunction<Void Function(), void Function()>('zeroclaw_init');
  late final _collectNews = _lib.lookupFunction<
    Pointer<Utf8> Function(Pointer<Utf8> site, Pointer<Utf8> category),
    Pointer<Utf8> Function(Pointer<Utf8> site, Pointer<Utf8> category)
  >('zeroclaw_collect_news');
  
  void initialize() {
    _init();
  }
  
  Future<List<News>> collectNews(String site, {String category = 'all'}) async {
    final result = _collectNews(
      site.toNativeUtf8(),
      category.toNativeUtf8(),
    );
    
    final jsonStr = result.toDartString();
    calloc.free(result);
    
    final data = jsonDecode(jsonStr);
    return (data['news'] as List).map((e) => News.fromJson(e)).toList();
  }
}
```

---

## 6. 安全与隐私

### 6.1 数据安全

| 数据类型 | 存储方式 | 加密算法 |
|----------|----------|----------|
| Cookie | 本地文件 | AES-256-GCM |
| 登录凭证 | Keychain/Keystore | 系统级加密 |
| 新闻缓存 | SQLite | SQLCipher |
| 配置信息 | SharedPreferences | 明文（非敏感） |

### 6.2 隐私保护

1. **本地处理优先**：新闻内容本地分析，不发送到外部服务器
2. **可选云同步**：用户可选择是否同步到其他设备
3. **数据清除**：提供一键清除所有数据功能
4. **权限最小化**：仅申请必要的网络、存储权限

### 6.3 合规考虑

- 遵守目标网站的 robots.txt
- 合理的请求频率（每秒不超过 1 次）
- 用户明确授权后访问付费内容
- 不用于商业内容爬取

---

## 7. 开发计划

### 7.1 里程碑

| 阶段 | 时间 | 目标 |
|------|------|------|
| **M1** | 第 1-2 周 | 基础架构搭建，Cookie 管理实现 |
| **M2** | 第 3-4 周 | Android WebView 集成，基础采集功能 |
| **M3** | 第 5-6 周 | iOS WebView 集成，网站适配器（3 个） |
| **M4** | 第 7-8 周 | ZeroClaw 集成，AI Agent 控制 |
| **M5** | 第 9-10 周 | Flutter UI 开发，用户交互 |
| **M6** | 第 11-12 周 | 测试优化，文档完善 |

### 7.2 团队配置

| 角色 | 人数 | 职责 |
|------|------|------|
| Rust 开发 | 1-2 人 | ZeroClaw 扩展、Cookie 管理 |
| Android 原生 | 1 人 | WebView 封装、JNI 桥接 |
| iOS 原生 | 1 人 | WKWebView 封装、Objective-C 桥接 |
| Flutter 开发 | 1-2 人 | UI 开发、状态管理 |
| 测试工程师 | 1 人 | 自动化测试、兼容性测试 |

---

## 8. 风险评估

### 8.1 技术风险

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 网站反爬升级 | 中 | 持续更新适配器，多指纹轮换 |
| iOS 审核拒绝 | 中 | 使用 TestFlight 内测，准备备用方案 |
| WebView 兼容性 | 低 | 充分测试主流 Android ROM |
| Cookie 失效 | 低 | 自动检测，及时提醒用户 |

### 8.2 商业风险

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 网站 ToS 违规 | 中 | 限制采集频率，用户自担责任 |
| 付费墙绕过争议 | 中 | 仅采集公开内容，不破解付费墙 |
| 内容版权 | 低 | 仅个人使用，不提供分享功能 |

---

## 9. 附录

### 9.1 参考资源

- ZeroClaw 文档: https://docs.zeroclawlabs.ai
- flutter_rust_bridge: https://cjycode.com/flutter_rust_bridge
- WebView 文档: https://developer.android.com/reference/android/webkit/WebView
- WKWebView 文档: https://developer.apple.com/documentation/webkit/wkwebview

### 9.2 第三方库

**Rust**:
- `aes-gcm`: AES 加密
- `chrono`: 时间处理
- `serde_json`: JSON 序列化
- `anyhow`: 错误处理

**Flutter**:
- `webview_flutter`: WebView 控件
- `flutter_secure_storage`: 安全存储
- `sqflite`: SQLite 数据库
- `workmanager`: 后台任务

---

**文档结束**

*本文档基于 ZeroClaw v0.1.7 和 Flutter 3.x 技术栈设计*
