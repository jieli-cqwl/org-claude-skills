# Codex Doc Review Report

- 审查文件 (file): {file_path}
- 审查阶段 (stage): {stage}
- 审查时间 (timestamp): {timestamp}
- 状态码: {status_code}

---

## Findings

| severity | location | description | recommendation |
|----------|----------|-------------|----------------|

{findings_rows}

## DECEPTION

| severity | location | description | evidence |
|----------|----------|-------------|----------|

{deception_rows}

> 无 DECEPTION 时标注"无"；DECEPTION 维度未覆盖时标注"DECEPTION 维度未覆盖"

## Dimensions

| dimension | verdict | evidence |
|-----------|---------|----------|

{dimensions_rows}

## Summary

- total_findings: {total_findings}
- deception_count: {deception_count}
- status: {status}

---

## 处理建议

{action_items}
