# 章节模板

init 模式的扫描信号、草稿模板和共创提问集中定义在此文件。

## 架构级提问

固定 3 个问题，影响所有章节的草稿填充：

1. 这个项目的核心职责是什么？（一句话概括）
2. 主要协作模式？（个人项目 / 小团队 / 开源社区）
3. 有哪些不看代码就不知道的重要约定或陷阱？

模型可根据扫描结果动态追加至多 2 个项目特定问题（如检测到 monorepo 结构则问包管理策略）。

---

## 基础组：Commands + Environment

### 扫描信号

| 文件/目录 | 推断内容 |
|-----------|---------|
| `package.json` | npm/yarn/pnpm 命令（解析 scripts 字段） |
| `pom.xml` / `build.gradle` | mvn/gradle 构建命令 |
| `go.mod` | go build/test 命令 |
| `Cargo.toml` | cargo build/test 命令 |
| `pyproject.toml` / `requirements.txt` | pip/poetry/uv 命令 |
| `Dockerfile` | 容器构建命令 |
| `Makefile` | make targets（解析目标名） |
| `.env.example` / `.env.template` | 环境变量清单 |

### Commands 草稿模板

```markdown
## Commands
| 命令 | 用途 |
|------|------|
| `{从 package.json scripts / Makefile targets 提取}` | {推断用途} |
```

填充规则：
- 从扫描到的配置文件中提取实际命令
- 优先列出：dev/start、build、test、lint、deploy
- 未扫描到的命令留空，由共创提问补充

### Environment 草稿模板

```markdown
## Environment
- {语言运行时} >= {从配置推断的版本}
- 必需环境变量：{从 .env.example 提取，列出变量名}
- 其他依赖：{如 Docker、Redis、PostgreSQL 等，从 docker-compose.yml 或 CI 配置推断}
```

### 共创提问

"扫描到了以下命令和环境依赖，是否正确？有遗漏的命令或环境要求吗？"

---

## 架构组：Architecture + Code Style + Workflow

### 扫描信号

| 文件/目录 | 推断内容 |
|-----------|---------|
| 顶层目录结构 | Architecture 草稿（目录树 + 模块职责推断） |
| `.eslintrc*` / `.prettierrc*` / `editorconfig` | Code Style 草稿（格式化规则） |
| `tsconfig.json` / `rustfmt.toml` / `.clang-format` | Code Style 草稿（语言特定风格） |
| `.github/workflows/` / `.gitlab-ci.yml` | Workflow 草稿（CI/CD 流程） |
| 分支命名模式（`git branch -r`） | Workflow 草稿（分支策略） |

### Architecture 草稿模板

```markdown
## Architecture
项目采用 {从配置推断的框架} 构建。
```
{顶层目录树，深度 2 层}
```
- `{目录}/` — {基于目录名和内容推断的职责}
```

### Code Style 草稿模板

```markdown
## Code Style
- 格式化：{从 .prettierrc/.eslintrc 等提取的关键规则}
- 命名约定：{从代码样本推断}
```

### Workflow 草稿模板

```markdown
## Workflow
- 分支策略：{从 git 分支模式推断}
- CI/CD：{从 workflow 配置推断}
- PR 流程：{从 CI 配置中的检查步骤推断}
```

### 共创提问

"目录结构和代码风格配置已扫描到，有什么隐含的架构约定、命名规范或开发流程是配置文件里看不出来的？"

---

## 质量组：Testing + Gotchas

### 扫描信号

| 文件/目录 | 推断内容 |
|-----------|---------|
| `jest.config.*` / `vitest.config.*` | Testing 草稿（JS/TS 测试框架） |
| `pytest.ini` / `pyproject.toml [tool.pytest]` | Testing 草稿（Python 测试框架） |
| `*_test.go` / `go test` | Testing 草稿（Go 测试） |
| CI 配置中的测试步骤 | Testing 草稿（测试命令 + 覆盖率要求） |
| `.github/CODEOWNERS` | Gotchas 草稿（代码审查要求） |

### Testing 草稿模板

```markdown
## Testing
- 框架：{从配置推断}
- 运行：`{测试命令}`
- 覆盖率：{从 CI 配置提取的覆盖率要求，若无则留空}
- 策略：{从测试目录结构推断，如 unit/integration/e2e 分层}
```

### Gotchas 草稿模板

```markdown
## Gotchas
- {从 CI 失败模式、特殊配置、非标准结构推断的潜在陷阱}
```

Gotchas 章节高度依赖用户输入——扫描只能发现结构性线索（如非标准目录命名、多构建系统共存），真正的"坑"需要共创提问激发。

### 共创提问

"测试框架和配置已扫描到。有什么测试相关的特殊约定（如测试数据管理、mock 策略）？另外，你踩过哪些坑是希望下一个人不要再踩的？"
