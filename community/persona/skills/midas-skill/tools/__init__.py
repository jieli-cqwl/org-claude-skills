"""
Midas Skill — Python Tooling

Input parsers, evolution management, and quality validation for the
Midas wealth-signal extraction engine.

Tools:
    slack_export_parser      Parse Slack JSON/text exports into Midas input
    chat_export_parser       Parse WhatsApp/WeChat/Telegram chat exports
    browser_history_parser   Extract browsing history from Chrome/Firefox/Safari
    evolution_manager        Manage evolution.jsonl (append, query, decay, stats)
    signal_report_validator  Validate signal reports against Midas quality standards
"""

__version__ = "2.0.0"
