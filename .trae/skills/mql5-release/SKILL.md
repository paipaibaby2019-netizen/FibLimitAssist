---
name: "mql5-release"
description: "Enforces version bump + git push on every code change. Invoke before finalizing any edit to FibLimitAssist.mq5 or project docs."
---

# MQL5 Release Workflow

This skill enforces two mandatory gates that MUST run after ANY code or doc change to this repository. Skip neither.

## When to Invoke

Invoke this skill immediately after completing any edit to project files (`.mq5`, `.md`). Before saying "done" or "已修改", run both gates below.

## Gate 1: Version Bump (MANDATORY)

### What to bump

| File | Field | Rule |
|------|-------|------|
| `FibLimitAssist.mq5` | `#property version   "X.Y"` | Increment minor: e.g. `1.52` → `1.53` |
| `FibLimitAssist.mq5` | `#property description "半自动...(vX.Y)"` | Sync the version number in the description line |
| `FibLimitAssist.mq5` | Add a NEW `#property description "vX.Y: <changelog>"` | One line per change, appended after the previous version line. Describe WHAT changed and WHY. |
| `FibLimitAssist项目说明文档.md` | `## 变更记录` section | Add a row for the new version, mirroring the `#property description` line |

### How to bump

```bash
# 1. Read current version
grep "#property version" FibLimitAssist.mq5

# 2. Edit mq5: bump version, update description line, append changelog line
# 3. Edit 项目说明文档.md: append changelog entry
# 4. Verify
grep -n "property version\|v1\." FibLimitAssist.mq5 | head -10
```

### Version convention

- Minor bump only (1.52 → 1.53). No major/revision changes unless the user explicitly asks.
- Changelog line format: `"vX.Y: <summary> — <detail>"`. Keep it concise but specific. Examples of good lines:
  - `"v1.52 FVG 修复: ① DetectFVG 调用参数顺序搞反(firstBar/lastBar), guard 恒触发 return 导致全部漏检"`
  - `"v1.53 FVG 半透明填充: ARGB alpha 在部分 MT5 build 上不生效, 改用同色系浅色调"`

## Gate 2: Commit + Push (MANDATORY)

### Commit message format

```
vX.Y: <summary>

<optional detail lines explaining the change>
```

Always include the version number as the prefix. Example:
```
v1.53: FVG 填充色调淡 (极浅色, 价格线更清晰)
```

### Commit steps

```bash
cd /workspace
git add FibLimitAssist.mq5 [FibLimitAssist项目说明文档.md]
git commit -m "vX.Y: <summary>"
```

### Push steps

This sandbox has no persistent GitHub credentials. Push requires a temporary PAT provided by the user.

```bash
# Get token from user first if not already available
git push "https://x-access-token:<TOKEN>@github.com/paipaibaby2019-netizen/FibLimitAssist.git" main
```

### Verify

```bash
git fetch origin
git rev-list --left-right --count main...origin/main
# Should output "0       0"
```

## Complete Checklist

Before finishing any edit to this repo, ALL of the following must be true:

- [ ] Version number bumped in `#property version`
- [ ] Version string synced in the main description line
- [ ] New `#property description` changelog line appended
- [ ] Changelog entry added to `FibLimitAssist项目说明文档.md`
- [ ] `git commit` created with `vX.Y:` prefix
- [ ] `git push` to `origin/main` succeeded
- [ ] `git rev-list --left-right --count main...origin/main` shows `0 0`

## Notes

- If a change is ONLY to documentation (no code change), still bump version and commit. The project principle: "凡调整代码必须同步更新文档" also implies doc-only changes get their own version entry.
- If the user explicitly says "don't bump" or "don't push", skip that gate. Otherwise, never skip.
- After push, remind the user to revoke any PAT they pasted in the conversation if it was a classic PAT.
