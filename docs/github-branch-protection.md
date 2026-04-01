# GitHub 分支保护配置

目标：对 `main` 启用以下保护策略：
- 禁止直接推送（必须走 PR）
- 至少 1 人审批
- `test / validate` 状态检查必须通过
- 管理员也受约束
- 禁止 force push / 删除分支

## 一键执行

```bash
cd ~/org-claude-skills
bash tools/github/apply-branch-protection.sh jieli-cqwl org-claude-skills main
```

## 套餐前置条件

私有仓库启用分支保护/规则集需要 GitHub Pro（个人）或公开仓库。  
若当前为私有且账号未开通 Pro，会返回：

`HTTP 403: Upgrade to GitHub Pro or make this repository public to enable this feature.`

## 生效后核验

```bash
gh api repos/jieli-cqwl/org-claude-skills/branches/main/protection | jq
```
