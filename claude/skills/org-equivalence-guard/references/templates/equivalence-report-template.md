# 行为等价报告
- 状态: EQUIV_OK | EQUIV_BLOCKED
- 生成时间: {timestamp}
- run_id: {run_id}
- git_sha: {git_sha}
- manifest_hash: {manifest_hash}
- config_hash: {config_hash}
- snapshot_id: {snapshot_id}
- generated_at: {generated_at}
- 接口总数: {total_endpoints}
- 已验证: {verified_endpoints} / {total_endpoints}（覆盖率 {coverage_percent}%）
- 通过: {pass_requests}
- 差异（白名单内）: {whitelisted_diffs}
- 差异（未解决）: {unresolved_diffs}

## 未解决差异
| api_id | field_path | old_value_masked | new_value_masked | status |
|--------|------------|------------------|------------------|--------|
| ... | ... | ... | ... | FAIL |

## 白名单差异
| api_id | field_path | old_value_masked | new_value_masked | status |
|--------|------------|------------------|------------------|--------|
| ... | ... | ... | ... | WHITELISTED |

## 未验证接口
| api_id | reason |
|--------|--------|
| ... | missing request-set entry |
