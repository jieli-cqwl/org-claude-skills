## Phase 1: Spec Review

### AC 核对
| AC | 状态 | 证据 |
|----|------|------|
| AC-1 | {PASS, FAIL} | file:line + 说明 |

### 结论
{SPEC_OK, SPEC_ISSUE}

---

## Phase 2A: 实现真实性（仅 SPEC_OK 后）

### 检查明细
| # | 检查项 | 结论 | 证据 |
|---|--------|------|------|
| 1 | TDD 证据完整性 | {PASS, FAIL} | {具体说明} |
| 2 | 虚假实现检测 | {PASS, FAIL} | {file:line} |

### 结论
{2A_OK, 2A_ISSUE}

---

## Phase 2B: 健壮性（仅 SPEC_OK 后）

### 检查明细
| # | 检查项 | 结论 | 证据 |
|---|--------|------|------|
| 3 | 静默失败检测 | {PASS, FAIL} | {file:line} |
| 4 | 硬编码检测 | {PASS, FAIL} | {file:line} |

### 结论
{2B_OK, 2B_ISSUE}

---

## Phase 2C: 规范与有效性（仅 SPEC_OK 后）

### 检查明细
| # | 检查项 | 结论 | 证据 |
|---|--------|------|------|
| 5 | 代码规范 | {PASS, FAIL} | {file:line} |
| 6 | 测试有效性 | {PASS, FAIL} | {file:line + 临界度评分} |
| 7 | 测试可维护性 | {PASS, FAIL} | {file:line} |

### 结论
{2C_OK, 2C_ISSUE}
