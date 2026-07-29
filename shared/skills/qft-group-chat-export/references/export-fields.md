# Export Fields

The export contains one Excel sheet named `消息明细`.

| Column | Source | Meaning |
| --- | --- | --- |
| 机器人ID | `qft_ai_coze_message.bot_id` | Robot ID used to process or record the message. |
| 机器人名称 | `qft_ai_coze_message.bot_name` or `qft_bot_account.bot_name` | Robot display name when available. |
| 群ID | `qft_ai_coze_message.group_chat_id` | External group chat ID. Only group-chat records are exported. |
| 群名称 | `qft_user_message_config.user_name` for `group_chat_id` | Group display name when found. |
| 消息ID | `qft_ai_coze_message.id` | Internal message primary key. |
| 第三方消息ID | `qft_ai_coze_message.third_party_msg_id` | Upstream platform message ID. |
| 消息类型 | `qft_ai_coze_message.message_category` | Display mapping below. |
| 发送人ID | `qft_ai_coze_message.user_id` | Sender user/contact ID stored on the message. |
| 发送人名称 | `qft_user_message_config.user_name` for `user_id` | Sender display name when found. |
| 对话内容 | `qft_ai_coze_message.content` | Message text stored after the application processed the callback. |
| 创建时间 | `qft_ai_coze_message.create_time` | Message creation time, formatted as `YYYY-MM-DD HH:mm:ss`. |

## Message Type Mapping

| Raw value | Excel label |
| --- | --- |
| `user` | 用户 |
| `assistant` | Ai客服 |
| `staff` | 员工 |
| `system` | 系统通知（人工接管、异常通知） |
| other or empty | 未知 |

## Query Rules

- Read-only `SELECT`.
- Filter `m.is_delete = 0`.
- Export only rows with non-empty `m.group_chat_id`.
- Include all message categories, including `system`.
- Filter by `bot_id`.
- Filter by `create_time >= start_time` and `create_time < end_time`.
- Fetch in pages by `m.id > after_id`.
- Sort final Excel rows by `group_chat_id`, then `message_id`.
