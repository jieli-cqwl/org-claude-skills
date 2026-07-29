---
name: qft-group-chat-export
description: Use when a product manager, operator, or internal user asks to export QFT customer-service robot group chat conversation data, message details, chat logs, robot conversation records, bot_id data, or time-windowed客服机器人群对话数据 for analysis, iteration, QA review, or system-notice counting.
---

# QFT Group Chat Export

## Purpose

Export QFT customer-service robot group chat message details to one Excel file. This skill is for product analysis, robot iteration, QA review, and system-notice counting. It should make the PM describe the data need in normal language while the agent runs the bundled export script.

## Use This Path

Use the bundled script. Do not hand-write SQL for the user unless the script cannot run and the user explicitly asks for SQL.

```bash
SKILL_DIR="/Users/lijieli/.agents/skills/qft-group-chat-export"
python3 "$SKILL_DIR/scripts/export_group_chat_messages.py" --bot "全房通小智"
```

The script performs a read-only MySQL query and writes one `.xlsx` file with a single sheet named `消息明细`.

## Defaults

- Time range: latest 7 natural days, from 6 days ago `00:00:00` through the export moment.
- Message categories: include all `user`, `assistant`, `staff`, and `system` messages.
- Output format: Excel `.xlsx` only.
- Output directory: `~/Downloads` unless overridden by `config.local.json` or `--output`.
- Maximum rows: 100000. If the export hits the limit, ask the PM to narrow the time range or specify group IDs.

## Robot Names

Known aliases:

| Name | bot_id |
| --- | --- |
| 测试环境 / 测试机器人 | `1688855768655786` |
| 监控机器人 | `1688857366689794` |
| 全房通小智 / 小智 | `1688857003746946` |

If the user gives an unknown robot name, ask one concise question for the robot name or `bot_id`. If the user gives multiple robots, pass them comma-separated to `--bot`.

## Time Handling

If the user does not specify a time range, use the default 7 natural days. If they specify dates, convert them to script arguments:

| User says | Script arguments |
| --- | --- |
| `昨天` | `--start YYYY-MM-DD --end YYYY-MM-DD` where end is today |
| `7月20日到7月22日` | `--start 2026-07-20 --end 2026-07-22` |
| `今天上午` | Use exact timestamps, e.g. `--start 2026-07-29 00:00:00 --end 2026-07-29 12:00:00` |

When only a date is passed as `--end`, the script includes that whole day by converting it to the next day at `00:00:00`.

## Optional Filters

- Group IDs: pass `--group group_id_1,group_id_2`.
- Explicit output path: pass `--output /absolute/path/file.xlsx`.
- Smaller exports: pass `--max-rows 20000` or narrower time windows.

## Configuration

The script reads `config.local.json` beside this file. This file is local-only and contains database connection details for the fixed PM environment. Keep it off Git and do not paste its password into chat.

If `config.local.json` is missing, the script can also read:

- `QFT_DB_HOST`
- `QFT_DB_PORT`
- `QFT_DB_USER`
- `QFT_DB_PASSWORD`
- `QFT_DB_NAME`

Use `config.example.json` as the shape reference.

The package vendors PyMySQL and openpyxl. The script can still auto-install missing Python packages into the skill-local `vendor/` directory if a dependency is removed or incomplete. If auto-install fails, report that technical help is needed.

## Output Contract

The Excel has one sheet: `消息明细`.

Columns are documented in `references/export-fields.md`. Before summarizing a completed export, report:

- Output file path
- Message row count
- Time range
- Robot ID(s)
- Any limit or dependency warning

## Failure Handling

If the export fails, do not expose stack traces, SQL, or credentials. Give the PM a short diagnosis and an action:

- Missing config: say the local database configuration is missing.
- Unknown robot: ask for robot name or `bot_id`.
- Too many rows: ask for shorter time range or group IDs.
- Dependency install failure: say Python dependency installation failed and needs technical help.
- Database connection failure: say the database connection failed and needs network/account verification.

## Examples

```bash
SKILL_DIR="/Users/lijieli/.agents/skills/qft-group-chat-export"
python3 "$SKILL_DIR/scripts/export_group_chat_messages.py" --bot "全房通小智"
python3 "$SKILL_DIR/scripts/export_group_chat_messages.py" --bot "监控机器人" --start 2026-07-20 --end 2026-07-22
python3 "$SKILL_DIR/scripts/export_group_chat_messages.py" --bot "1688857003746946" --group group_a,group_b --output ~/Downloads/xiaozhi_groups.xlsx
```
