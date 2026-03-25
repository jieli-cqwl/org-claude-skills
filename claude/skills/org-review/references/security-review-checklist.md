# 安全审查检查清单

> 供 /review 审查-A 安全性维度引用。

## 1. 输入验证（注入防护）

| 检查项 | 检查方法 | 代码模式示例 |
|--------|---------|-------------|
| SQL 注入 | 所有数据库查询是否使用参数化/预编译 | 差: `query("SELECT * WHERE id=" + id)` / 好: `query("SELECT * WHERE id=?", [id])` |
| NoSQL 注入 | MongoDB 查询是否验证输入类型 | 差: `find({role: req.body.role})` / 好: `find({role: String(req.body.role)})` |
| 命令注入 | 是否使用 shell 执行用户输入 | 差: `exec("ls " + userInput)` / 好: `execFile("ls", [userInput])` |
| 路径遍历 | 文件路径是否做规范化和边界检查 | 差: `readFile(basePath + userInput)` / 好: `resolve(basePath, userInput)` 后检查前缀 |
| XSS | 用户输入是否在输出前转义 | 差: `innerHTML = userInput` / 好: `textContent = userInput` |
| 模板注入 | 模板引擎是否使用安全模式 | 差: `eval(template)` / 好: 使用沙箱模板引擎 |

## 2. 认证授权

| 检查项 | 检查方法 | 代码模式示例 |
|--------|---------|-------------|
| 硬编码凭据 | 代码中是否包含密码/密钥/Token | 差: `const API_KEY = "sk-xxx"` / 好: `process.env.API_KEY` |
| 不安全的会话管理 | Session 配置是否安全 | 检查: httpOnly, secure, sameSite, maxAge |
| 权限检查缺失 | 受保护资源是否有权限中间件 | 差: 路由无 auth 中间件 / 好: `router.use(authMiddleware)` |
| 水平越权 | 资源访问是否验证所有者 | 差: `findById(id)` / 好: `findOne({id, ownerId: user.id})` |
| JWT 配置 | JWT 是否使用强算法和合理过期 | 检查: algorithm !== 'none', expiresIn 合理 |
| CORS 配置 | 是否限制允许的源 | 差: `origin: '*'` / 好: 白名单模式 |

## 3. 敏感数据保护

| 检查项 | 检查方法 | 代码模式示例 |
|--------|---------|-------------|
| 日志泄露 | 日志是否记录敏感数据 | 差: `log("User login:", {password})` / 好: 脱敏后记录 |
| 响应泄露 | API 响应是否包含不必要的敏感字段 | 差: 返回完整用户对象含密码 / 好: 使用 DTO/select 排除敏感字段 |
| 错误信息泄露 | 错误响应是否暴露内部细节 | 差: 返回完整堆栈 / 好: 通用错误消息 + 内部日志 |
| 不安全存储 | 密码是否明文存储 | 差: 直接存储密码 / 好: bcrypt/argon2 加盐哈希 |
| 传输安全 | 是否强制 HTTPS | 检查: HSTS header, HTTP 重定向 |

## 4. 其他安全风险

| 检查项 | 检查方法 |
|--------|---------|
| 依赖漏洞 | 是否引入已知有漏洞的依赖版本 |
| 不安全的反序列化 | 是否对不可信数据做反序列化 |
| 资源限制 | 是否有请求大小/速率限制 |
| CSRF 保护 | 状态修改接口是否有 CSRF Token |
| 文件上传 | 是否验证文件类型/大小/内容 |
