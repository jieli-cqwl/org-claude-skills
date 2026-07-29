import sys
import unittest
from contextlib import redirect_stderr
from datetime import datetime
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from openpyxl import load_workbook


SKILL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SKILL_DIR / "scripts"))

import export_group_chat_messages as export_script


class ExportGroupChatMessagesTest(unittest.TestCase):
    def test_default_range_uses_recent_seven_natural_days(self):
        now = datetime(2026, 7, 29, 15, 30, 45)

        start_time, end_time = export_script.default_time_range(now)

        self.assertEqual(start_time, datetime(2026, 7, 23, 0, 0, 0))
        self.assertEqual(end_time, now)

    def test_resolve_bot_ids_supports_alias_and_comma_separated_ids(self):
        config = {"bots": {"全房通小智": "1688857003746946"}}

        self.assertEqual(
            export_script.resolve_bot_ids("全房通小智", config),
            ["1688857003746946"],
        )
        self.assertEqual(
            export_script.resolve_bot_ids("1688857003746946,1688857366689794", config),
            ["1688857003746946", "1688857366689794"],
        )

    def test_build_query_is_read_only_parameterized_and_includes_system_messages(self):
        query, params = export_script.build_query(
            bot_ids=["1688857003746946", "1688857366689794"],
            start_time=datetime(2026, 7, 23, 0, 0, 0),
            end_time=datetime(2026, 7, 29, 15, 30, 45),
            group_chat_ids=["group-1"],
            after_id=100,
            limit=500,
        )

        upper_query = query.upper()
        self.assertIn("SELECT", upper_query)
        self.assertNotIn(" UPDATE ", upper_query)
        self.assertNotIn(" DELETE ", upper_query)
        self.assertNotIn(" INSERT ", upper_query)
        self.assertIn("M.IS_DELETE = 0", upper_query)
        self.assertIn("M.GROUP_CHAT_ID IS NOT NULL", upper_query)
        self.assertIn("M.GROUP_CHAT_ID != ''", upper_query)
        self.assertIn("M.BOT_ID IN (%S, %S)", query.upper().replace("%s", "%S"))
        self.assertNotIn("MESSAGE_CATEGORY IN", upper_query)
        self.assertEqual(
            params,
            [
                datetime(2026, 7, 23, 0, 0, 0),
                datetime(2026, 7, 29, 15, 30, 45),
                100,
                "1688857003746946",
                "1688857366689794",
                "group-1",
                500,
            ],
        )

    def test_build_query_collates_cross_table_string_joins(self):
        query, _ = export_script.build_query(
            bot_ids=["1688857003746946"],
            start_time=datetime(2026, 7, 23, 0, 0, 0),
            end_time=datetime(2026, 7, 29, 15, 30, 45),
            after_id=0,
            limit=500,
        )

        normalized_query = " ".join(query.split()).upper()
        self.assertIn("M.BOT_ID COLLATE UTF8MB4_GENERAL_CI = B.BOT_ID COLLATE UTF8MB4_GENERAL_CI", normalized_query)
        self.assertIn("M.USER_ID COLLATE UTF8MB4_GENERAL_CI = C.USER_ID COLLATE UTF8MB4_GENERAL_CI", normalized_query)
        self.assertIn("M.GROUP_CHAT_ID COLLATE UTF8MB4_GENERAL_CI = G.USER_ID COLLATE UTF8MB4_GENERAL_CI", normalized_query)
        self.assertIn("M.BOT_ID COLLATE UTF8MB4_GENERAL_CI = G.BOT_ID COLLATE UTF8MB4_GENERAL_CI", normalized_query)

    def test_write_xlsx_uses_expected_headers_and_message_type_labels(self):
        rows = [
            {
                "bot_id": "1688857003746946",
                "bot_name": "全房通小智",
                "group_chat_id": "group-1",
                "group_name": "测试群",
                "message_id": 123,
                "third_party_msg_id": "third-123",
                "message_category": "system",
                "sender_id": "system",
                "sender_name": None,
                "content": "人工接管通知",
                "create_time": datetime(2026, 7, 29, 10, 5, 0),
            }
        ]

        with TemporaryDirectory() as tmpdir:
            output_path = Path(tmpdir) / "messages.xlsx"
            export_script.write_xlsx(rows, output_path)
            workbook = load_workbook(output_path)
            sheet = workbook["消息明细"]

            headers = [cell.value for cell in sheet[1]]
            self.assertEqual(headers, export_script.EXPORT_HEADERS)
            values = [cell.value for cell in sheet[2]]
            self.assertEqual(values[6], "系统通知（人工接管、异常通知）")
            self.assertIsNone(values[8])
            self.assertEqual(values[10], "2026-07-29 10:05:00")

    def test_write_xlsx_wraps_filesystem_failures(self):
        with TemporaryDirectory() as tmpdir:
            with self.assertRaises(export_script.ExportError) as caught:
                export_script.write_xlsx([], Path(tmpdir))

        self.assertIn("Excel 文件写入失败", str(caught.exception))

    def test_invalid_env_port_is_user_readable(self):
        with patch.dict("os.environ", {"QFT_DB_PORT": "abc"}, clear=False):
            with self.assertRaises(export_script.ExportError) as caught:
                export_script.load_config(Path("/tmp/qft-missing-config.json"))

        self.assertIn("数据库端口配置无效", str(caught.exception))

    def test_normalize_limits_rejects_above_hard_max_rows(self):
        with self.assertRaises(export_script.ExportError) as caught:
            export_script.normalize_limits(page_size=5000, max_rows=100001)

        self.assertIn("单次导出最大行数不能超过", str(caught.exception))

    def test_main_sanitizes_unexpected_errors(self):
        stderr = StringIO()
        with patch.object(export_script, "run", side_effect=RuntimeError("password=secret SELECT *")):
            with redirect_stderr(stderr):
                exit_code = export_script.main()

        self.assertEqual(exit_code, 1)
        self.assertIn("出现未预期错误", stderr.getvalue())
        self.assertNotIn("secret", stderr.getvalue())
        self.assertNotIn("SELECT", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
