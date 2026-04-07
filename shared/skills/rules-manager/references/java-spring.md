# Java + Spring Boot 规则模板

## 架构级问题（init Step 2 使用）

1. 你们的后端分层架构是什么？标准三层（Controller → Service → DAO/Repository）还是 DDD？
2. 数据访问层用的是 MyBatis 还是 JPA/Hibernate？有没有混用？
3. 异常处理有统一策略吗？比如全局 @ControllerAdvice，还是各层各自 try-catch？

## 规则草稿 + 共创提问（init Step 3 使用）

以下每条规则包含：默认约束 + 配套提问。展示草稿时逐条确认。

### 规则 1：分层职责隔离

```
Controller 层只负责参数校验、路由和响应封装，禁止包含业务逻辑。
Service 层承载业务逻辑，禁止直接操作 HttpServletRequest/Response。
DAO/Repository 层只负责数据访问，禁止包含业务判断。
```

**共创提问**：你们有没有例外场景？比如简单的单表 CRUD 是否允许 Controller 直接调 DAO？Service 之间允许互相调用吗？有没有调用层级限制？

### 规则 2：异常处理统一

```
业务异常必须通过自定义异常类抛出，禁止直接抛 RuntimeException 或 Exception。
Controller 层禁止 try-catch 业务异常，统一由 @ControllerAdvice 处理。
异常响应必须包含错误码和用户可理解的提示信息。
```

**共创提问**：你们有统一的错误码体系吗？异常分几级（业务异常、系统异常、第三方异常）？有没有已有的 BaseException 基类？

### 规则 3：接口规范

```
RESTful API 使用统一的响应包装类（如 Result<T>）。
接口入参必须使用 @Valid/@Validated 进行校验，禁止在 Service 层手动校验请求参数。
分页查询必须限制最大页大小。
```

**共创提问**：你们的统一响应结构长什么样？分页用的是什么组件（PageHelper / MyBatis-Plus / Spring Data）？最大页大小限制是多少？

### 规则 4：事务管理

```
@Transactional 只允许标注在 Service 层方法上，禁止标注在 Controller 或 DAO 层。
只读查询方法必须标注 @Transactional(readOnly = true)。
```

**共创提问**：你们有没有遇到过事务失效的坑（比如自调用、非 public 方法）？对长事务有没有特殊处理策略？跨 Service 事务怎么管理？

### 规则 5：配置管理

```
环境相关配置禁止硬编码，必须通过 application.yml 或环境变量注入。
配置类必须使用 @ConfigurationProperties 绑定，禁止在业务代码中散落 @Value。
多环境配置使用 Spring Profiles（application-{env}.yml）。
```

**共创提问**：你们用 yml 还是 properties？有没有用配置中心（Nacos/Apollo）？敏感配置如何管理？

### 规则 6：日志规范

```
使用 SLF4J + Logback，禁止 System.out.println 和 e.printStackTrace()。
日志必须使用占位符格式（log.info("userId={}", id)），禁止字符串拼接。
Controller 入口和 Service 关键业务节点必须有 INFO 级别日志。
```

**共创提问**：你们有统一的日志格式要求（traceId、链路追踪）吗？日志落盘策略是什么？

## 生成的规则文件 paths 配置

```yaml
---
paths:
  - "**/*.java"
---
```
