#!/usr/bin/env python3
"""Export QFT group-chat robot messages to an Excel detail sheet."""

from __future__ import annotations

import argparse
import importlib
import json
import os
import re
import subprocess
import sys
from datetime import date, datetime, time, timedelta
from pathlib import Path
from typing import Any, Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
DEFAULT_CONFIG_PATH = SKILL_DIR / "config.local.json"
DEFAULT_OUTPUT_DIR = Path.home() / "Downloads"
DEFAULT_PAGE_SIZE = 5000
DEFAULT_MAX_ROWS = 100000
HARD_MAX_ROWS = 100000

EXPORT_HEADERS = [
    "机器人ID",
    "机器人名称",
    "群ID",
    "群名称",
    "消息ID",
    "第三方消息ID",
    "消息类型",
    "发送人ID",
    "发送人名称",
    "对话内容",
    "创建时间",
]

MESSAGE_TYPE_LABELS = {
    "user": "用户",
    "staff": "员工",
    "assistant": "Ai客服",
    "system": "系统通知（人工接管、异常通知）",
}

DEFAULT_CONFIG: dict[str, Any] = {
    "database": {
        "host": "",
        "port": 3306,
        "user": "",
        "password": "",
        "database": "qft_ai",
        "connect_timeout": 10,
        "read_timeout": 60,
    },
    "bots": {
        "测试环境": "1688855768655786",
        "测试机器人": "1688855768655786",
        "监控机器人": "1688857366689794",
        "全房通小智": "1688857003746946",
        "小智": "1688857003746946",
    },
    "defaults": {
        "output_dir": str(DEFAULT_OUTPUT_DIR),
        "page_size": DEFAULT_PAGE_SIZE,
        "max_rows": HARD_MAX_ROWS,
    },
}


class ExportError(RuntimeError):
    """A user-facing export failure without secrets or stack traces."""


def default_time_range(now: datetime | None = None) -> tuple[datetime, datetime]:
    """Return the latest 7 natural days: 6 days ago 00:00:00 through now."""
    current = now or datetime.now()
    start_day = current.date() - timedelta(days=6)
    return datetime.combine(start_day, time.min), current


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    result = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def load_config(path: Path = DEFAULT_CONFIG_PATH) -> dict[str, Any]:
    config = DEFAULT_CONFIG
    if path.exists():
        try:
            with path.open("r", encoding="utf-8") as handle:
                config = deep_merge(DEFAULT_CONFIG, json.load(handle))
        except json.JSONDecodeError as exc:
            raise ExportError(f"配置文件不是有效 JSON：{path}") from exc

    env_database = {
        "host": os.getenv("QFT_DB_HOST"),
        "port": os.getenv("QFT_DB_PORT"),
        "user": os.getenv("QFT_DB_USER"),
        "password": os.getenv("QFT_DB_PASSWORD"),
        "database": os.getenv("QFT_DB_NAME"),
    }
    database_override = {key: value for key, value in env_database.items() if value}
    if database_override:
        if "port" in database_override:
            try:
                database_override["port"] = int(database_override["port"])
            except ValueError as exc:
                raise ExportError("数据库端口配置无效，请填写数字端口。") from exc
        config = deep_merge(config, {"database": database_override})

    return config


def validate_database_config(config: dict[str, Any]) -> dict[str, Any]:
    database = dict(config.get("database") or {})
    missing = [
        key for key in ("host", "port", "user", "password", "database") if not database.get(key)
    ]
    if missing:
        raise ExportError(
            "数据库配置缺失："
            + ", ".join(missing)
            + "。请检查本机配置文件或 QFT_DB_* 环境变量。"
        )
    try:
        database["port"] = int(database["port"])
    except (TypeError, ValueError) as exc:
        raise ExportError("数据库端口配置无效，请填写数字端口。") from exc
    return database


def split_values(value: str | Iterable[str]) -> list[str]:
    if isinstance(value, str):
        candidates = re.split(r"[,，\s]+", value.strip())
    else:
        candidates = []
        for item in value:
            candidates.extend(re.split(r"[,，\s]+", str(item).strip()))
    return [item for item in candidates if item]


def resolve_bot_ids(bot: str, config: dict[str, Any]) -> list[str]:
    bots = config.get("bots") or {}
    if not bot or not bot.strip():
        raise ExportError("机器人不能为空。请指定机器人名称或 bot_id。")

    raw_items = split_values(bot)
    resolved: list[str] = []
    unknown: list[str] = []
    for item in raw_items:
        if item in bots:
            resolved.append(str(bots[item]))
        elif re.fullmatch(r"\d{8,}", item):
            resolved.append(item)
        else:
            unknown.append(item)

    if unknown:
        known = "、".join(sorted(bots.keys()))
        raise ExportError(f"无法识别机器人：{'、'.join(unknown)}。可用名称：{known}")

    return list(dict.fromkeys(resolved))


def parse_datetime_value(value: str, *, is_end: bool = False) -> datetime:
    raw = value.strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(raw, fmt)
        except ValueError:
            pass

    try:
        parsed_date = datetime.strptime(raw, "%Y-%m-%d").date()
    except ValueError as exc:
        raise ExportError(f"无法识别时间：{value}。格式示例：2026-07-29 或 2026-07-29 15:30:00") from exc

    if is_end:
        return datetime.combine(parsed_date + timedelta(days=1), time.min)
    return datetime.combine(parsed_date, time.min)


def build_query(
    *,
    bot_ids: list[str],
    start_time: datetime,
    end_time: datetime,
    group_chat_ids: list[str] | None = None,
    after_id: int = 0,
    limit: int = DEFAULT_PAGE_SIZE,
) -> tuple[str, list[Any]]:
    bot_placeholders = ", ".join(["%s"] * len(bot_ids))
    params: list[Any] = [start_time, end_time, after_id, *bot_ids]

    group_filter = ""
    if group_chat_ids:
        group_placeholders = ", ".join(["%s"] * len(group_chat_ids))
        group_filter = f" AND m.group_chat_id IN ({group_placeholders})"
        params.extend(group_chat_ids)

    params.append(limit)

    # Keep this as a read-only detail export: no message category filter, because
    # product analysis needs user/assistant/staff/system messages in the same raw timeline.
    query = f"""
        SELECT
            m.bot_id,
            COALESCE(m.bot_name, b.bot_name, '') AS bot_name,
            m.group_chat_id,
            COALESCE(g.user_name, '') AS group_name,
            m.id AS message_id,
            COALESCE(m.third_party_msg_id, '') AS third_party_msg_id,
            COALESCE(m.message_category, '') AS message_category,
            m.user_id AS sender_id,
            COALESCE(c.user_name, '') AS sender_name,
            COALESCE(m.content, '') AS content,
            m.create_time
        FROM qft_ai_coze_message m
        LEFT JOIN qft_bot_account b
            ON m.bot_id COLLATE utf8mb4_general_ci = b.bot_id COLLATE utf8mb4_general_ci
            AND b.is_deleted = 0
        LEFT JOIN qft_user_message_config c
            ON m.user_id COLLATE utf8mb4_general_ci = c.user_id COLLATE utf8mb4_general_ci
            AND m.bot_id COLLATE utf8mb4_general_ci = c.bot_id COLLATE utf8mb4_general_ci
            AND c.is_delete = 0
        LEFT JOIN qft_user_message_config g
            ON m.group_chat_id COLLATE utf8mb4_general_ci = g.user_id COLLATE utf8mb4_general_ci
            AND m.bot_id COLLATE utf8mb4_general_ci = g.bot_id COLLATE utf8mb4_general_ci
            AND g.user_type = 1
            AND g.is_delete = 0
        WHERE m.is_delete = 0
          AND m.group_chat_id IS NOT NULL
          AND m.group_chat_id != ''
          AND m.create_time >= %s
          AND m.create_time < %s
          AND m.id > %s
          AND m.bot_id IN ({bot_placeholders})
          {group_filter}
        ORDER BY m.id ASC
        LIMIT %s
    """
    return query, params


def import_dependency(module_name: str, package_spec: str, auto_install: bool = True):
    vendor_dir = SKILL_DIR / "vendor"
    if vendor_dir.exists():
        sys.path.insert(0, str(vendor_dir))
    try:
        return importlib.import_module(module_name)
    except ModuleNotFoundError:
        if not auto_install:
            raise ExportError(f"缺少 Python 依赖 {module_name}，请开启自动安装或联系技术同事。")

    vendor_dir.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable,
        "-m",
        "pip",
        "install",
        "--disable-pip-version-check",
        "--quiet",
        "--target",
        str(vendor_dir),
        package_spec,
    ]
    try:
        subprocess.run(command, check=True, timeout=120)
    except (subprocess.SubprocessError, OSError) as exc:
        raise ExportError(f"自动安装 Python 依赖 {module_name} 失败，请检查网络或 Python pip。") from exc

    sys.path.insert(0, str(vendor_dir))
    try:
        return importlib.import_module(module_name)
    except ModuleNotFoundError as exc:
        raise ExportError(f"Python 依赖 {module_name} 安装后仍不可用，请重新运行或联系技术同事。") from exc


def import_pymysql(auto_install: bool = True):
    return import_dependency("pymysql", "PyMySQL>=1.1,<2", auto_install)


def import_openpyxl(auto_install: bool = True):
    import_dependency("openpyxl", "openpyxl>=3.1,<4", auto_install)
    workbook_module = importlib.import_module("openpyxl")
    styles_module = importlib.import_module("openpyxl.styles")
    return workbook_module.Workbook, styles_module.Alignment, styles_module.Font


def fetch_rows(
    *,
    config: dict[str, Any],
    bot_ids: list[str],
    start_time: datetime,
    end_time: datetime,
    group_chat_ids: list[str] | None,
    page_size: int,
    max_rows: int,
    auto_install_deps: bool = True,
) -> list[dict[str, Any]]:
    database = validate_database_config(config)
    pymysql = import_pymysql(auto_install=auto_install_deps)

    try:
        connection = pymysql.connect(
            host=database["host"],
            port=database["port"],
            user=database["user"],
            password=database["password"],
            database=database["database"],
            charset="utf8mb4",
            connect_timeout=int(database.get("connect_timeout") or 10),
            read_timeout=int(database.get("read_timeout") or 60),
            cursorclass=pymysql.cursors.DictCursor,
        )
    except Exception as exc:
        raise ExportError("数据库连接失败，请联系技术同事核对网络、白名单或账号权限。") from exc

    rows: list[dict[str, Any]] = []
    after_id = 0
    try:
        with connection.cursor() as cursor:
            while len(rows) < max_rows:
                limit = min(page_size, max_rows - len(rows))
                query, params = build_query(
                    bot_ids=bot_ids,
                    start_time=start_time,
                    end_time=end_time,
                    group_chat_ids=group_chat_ids,
                    after_id=after_id,
                    limit=limit,
                )
                try:
                    cursor.execute(query, params)
                    batch = list(cursor.fetchall())
                except Exception as exc:
                    raise ExportError("数据库查询失败，请联系技术同事核对表结构、账号权限或字符集配置。") from exc
                if not batch:
                    break
                rows.extend(batch)
                after_id = int(batch[-1]["message_id"])
                if len(batch) < limit:
                    break
    finally:
        connection.close()

    if len(rows) >= max_rows:
        raise ExportError(f"命中单次导出上限 {max_rows} 行，请缩短时间范围或指定群ID。")

    return sorted(rows, key=lambda row: (str(row.get("group_chat_id") or ""), int(row["message_id"])))


def format_datetime(value: Any) -> str:
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    return "" if value is None else str(value)


def row_to_values(row: dict[str, Any]) -> list[Any]:
    category = str(row.get("message_category") or "")
    return [
        row.get("bot_id") or "",
        row.get("bot_name") or "",
        row.get("group_chat_id") or "",
        row.get("group_name") or "",
        row.get("message_id") or "",
        row.get("third_party_msg_id") or "",
        MESSAGE_TYPE_LABELS.get(category, "未知"),
        row.get("sender_id") or "",
        row.get("sender_name") or "",
        row.get("content") or "",
        format_datetime(row.get("create_time")),
    ]


def write_xlsx(rows: list[dict[str, Any]], output_path: Path) -> None:
    Workbook, Alignment, Font = import_openpyxl()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "消息明细"
    sheet.append(EXPORT_HEADERS)

    for cell in sheet[1]:
        cell.font = Font(bold=True)
        cell.alignment = Alignment(horizontal="center", vertical="center")

    for row in rows:
        sheet.append(row_to_values(row))

    widths = [18, 18, 24, 24, 12, 26, 24, 24, 18, 60, 20]
    for index, width in enumerate(widths, start=1):
        sheet.column_dimensions[sheet.cell(row=1, column=index).column_letter].width = width

    sheet.freeze_panes = "A2"
    sheet.auto_filter.ref = sheet.dimensions
    for row in sheet.iter_rows(min_row=2, min_col=10, max_col=10):
        row[0].alignment = Alignment(wrap_text=True, vertical="top")

    try:
        workbook.save(output_path)
    except Exception as exc:
        raise ExportError("Excel 文件写入失败，请确认输出路径可写，且目标文件没有被 Excel 打开。") from exc


def safe_filename_part(value: str) -> str:
    cleaned = re.sub(r"[^\w\u4e00-\u9fff.-]+", "_", value.strip())
    return cleaned.strip("_") or "messages"


def default_output_path(output_dir: Path, bot: str, start_time: datetime, end_time: datetime) -> Path:
    name = "qft_group_chat_messages_{bot}_{start}_{end}.xlsx".format(
        bot=safe_filename_part(bot),
        start=start_time.strftime("%Y%m%d%H%M%S"),
        end=end_time.strftime("%Y%m%d%H%M%S"),
    )
    candidate = output_dir.expanduser() / name
    if not candidate.exists():
        return candidate
    stem = candidate.stem
    suffix = candidate.suffix
    for index in range(2, 100):
        sibling = candidate.with_name(f"{stem}-{index}{suffix}")
        if not sibling.exists():
            return sibling
    raise ExportError("输出目录中同名文件过多，请指定新的 --output 路径。")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="导出全房通客服机器人群对话消息明细")
    parser.add_argument("--bot", required=True, help="机器人名称或 bot_id，多个用逗号分隔")
    parser.add_argument("--start", help="开始时间，默认最近7个自然日")
    parser.add_argument("--end", help="结束时间，默认当前时刻；日期格式会包含整天")
    parser.add_argument("--group", action="append", help="可选群ID，多个用逗号分隔；可重复传")
    parser.add_argument("--output", help="输出 xlsx 路径；默认写入配置的 output_dir 或 Downloads")
    parser.add_argument("--config", default=str(DEFAULT_CONFIG_PATH), help="本机配置文件路径")
    parser.add_argument("--page-size", type=int, help="分页大小，默认 5000")
    parser.add_argument("--max-rows", type=int, help="单次导出最大行数，默认 100000")
    parser.add_argument("--no-install-deps", action="store_true", help="关闭 PyMySQL 自动安装")
    return parser.parse_args(argv)


def normalize_limits(page_size: int, max_rows: int) -> tuple[int, int]:
    try:
        normalized_page_size = int(page_size)
        normalized_max_rows = int(max_rows)
    except (TypeError, ValueError) as exc:
        raise ExportError("page-size 和 max-rows 必须是数字。") from exc
    if normalized_page_size <= 0 or normalized_max_rows <= 0:
        raise ExportError("page-size 和 max-rows 必须大于 0。")
    if normalized_max_rows > HARD_MAX_ROWS:
        raise ExportError(f"单次导出最大行数不能超过 {HARD_MAX_ROWS}。请缩短时间范围或指定群ID。")
    return normalized_page_size, normalized_max_rows


def run(argv: list[str] | None = None) -> Path:
    args = parse_args(argv)
    config = load_config(Path(args.config).expanduser())
    start_time, end_time = default_time_range()
    if args.start:
        start_time = parse_datetime_value(args.start)
    if args.end:
        end_time = parse_datetime_value(args.end, is_end=len(args.end.strip()) == 10)
    if start_time >= end_time:
        raise ExportError("开始时间必须早于结束时间。")

    bot_ids = resolve_bot_ids(args.bot, config)
    group_chat_ids = split_values(args.group or []) or None
    defaults = config.get("defaults") or {}
    page_size, max_rows = normalize_limits(
        args.page_size or defaults.get("page_size") or DEFAULT_PAGE_SIZE,
        args.max_rows or defaults.get("max_rows") or DEFAULT_MAX_ROWS,
    )

    rows = fetch_rows(
        config=config,
        bot_ids=bot_ids,
        start_time=start_time,
        end_time=end_time,
        group_chat_ids=group_chat_ids,
        page_size=page_size,
        max_rows=max_rows,
        auto_install_deps=not args.no_install_deps,
    )

    if args.output:
        output_path = Path(args.output).expanduser()
    else:
        output_dir = Path(defaults.get("output_dir") or DEFAULT_OUTPUT_DIR).expanduser()
        output_path = default_output_path(output_dir, args.bot, start_time, end_time)
    write_xlsx(rows, output_path)
    print(f"导出完成：{output_path}")
    print(f"消息行数：{len(rows)}")
    print(f"时间范围：{format_datetime(start_time)} ~ {format_datetime(end_time)}")
    print(f"机器人ID：{', '.join(bot_ids)}")
    return output_path


def main() -> int:
    try:
        run()
        return 0
    except ExportError as exc:
        print(f"导出失败：{exc}", file=sys.stderr)
        return 2
    except Exception:
        print("导出失败：出现未预期错误，请联系技术同事查看运行环境。", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
