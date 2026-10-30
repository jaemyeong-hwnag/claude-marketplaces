# plugin-versioning

[English](README.md) · [한국어](README.ko.md) · **简体中文**

强制插件版本值与该值所记录位置之间一致性的内部插件。

名称由 `plugin-naming`、目录结构由 `marketplace-directory-structure`、放置 · 分发由仓库 `.claude/hooks/` 检查。
这里**只看版本**。

## 安装

在本仓库中由 SessionStart 钩子（`.claude/hooks/sync-internal-plugins.sh`）注册 · 启用 · 安装。
这是 internal 插件，不分发到其他仓库。要在别处使用，请移到 `public-plugins/`。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| version-update | 升级版本，CHANGELOG | semver 升级级别判断与升级顺序 |
| /versioning-validate | 直接调用 | 验证整个仓库和本次变更范围（`--since`）的版本一致性 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-versioning.sh | PreToolUse (Write\|Edit) | 写入 `plugin.json` 的 `version` 值错误时**阻止**（`V-01` · `V-03`） |
| validate-versioning.sh | PostToolUse (Write\|Edit) | 保存 `plugin.json` · `CHANGELOG.md` 后，若 `V-01` ~ `V-08` 不符则**提醒** |

## 文件

| 路径 | 作用 |
|---|---|
| `references/versioning-rules.md` | 规则原文 |
| `scripts/validate-versioning.sh` | 机械验证（钩子模式 + CLI 模式） |
| `test/` | 回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 — 级别判断技能触发 · 阻止 `0.0.x`。由 `plugin-workflow` 的 `eval-all.sh` 运行 |

## 检查什么

| | 条款 |
|---|---|
| 版本值 | `V-01` 三段 semver · `V-02` 必须有 version · `V-03` 初始版本 `0.1.0` |
| CHANGELOG | `V-04` 第一行 · `V-05` 条目标题 · `V-06` 存在当前版本条目 · `V-07` 降序 · `V-08` 不得重复 |
| 声明位置 | `V-09` 条目 ↔ plugin.json 一致 · `V-10` marketplace metadata.version · `V-11` dependencies 范围 |
| 标签 | `V-12` `{插件名}--v{版本}`（仅格式） · `V-13` 标签不能超前于清单 |
| 变更 | `V-14` 基准 ref 之后有文件变更的插件必须升级版本（`--since`） |

规则原文是 [`references/versioning-rules.md`](references/versioning-rules.md)。冲突时以它为准。

**升级级别（PATCH/MINOR/MAJOR）不由机器判定。** 由 `version-update` 技能判断。

## 钩子分两路的原因

升级版本并写 CHANGELOG 需要**两次编辑**。若第一次编辑就因 `V-06` 阻止，就什么都做不了。

- `PreToolUse` — 仅当写入 `plugin.json` 的 `version` 值本身错误时**阻止**（`V-01` · `V-03`）
- `PostToolUse` — 保存后若 `V-01` ~ `V-08` 不符，通过 `additionalContext` **提醒**。不阻止

## 用法

```bash
# 整个仓库（根目录 + 所有插件 + 标签）
scripts/validate-versioning.sh --all .

# 单个插件
scripts/validate-versioning.sh internal-plugins/plugin-versioning

# 仅根目录条目
scripts/validate-versioning.sh --marketplace .

# 仅标签
scripts/validate-versioning.sh --tag .

# PR 范围 — 变更的插件是否升级了版本
scripts/validate-versioning.sh --since origin/main .

# 回归测试
test/validate-versioning.test.sh
```

退出码 `2` 表示违反规则。

## 发布

```bash
# 1. 判断级别 → 2. CHANGELOG → 3. plugin.json → 4. 条目 → 5. 验证 → 6. 提交·PR·合并
```

7. 标签 · 发布不由本插件负责。合并并确认安装后，在 main 上用 `plugin-release-create` 技能（`plugin-workflow`）完成。其脚本为每个插件用 `claude plugin tag --push` 创建 `{插件名}--v{版本}` 标签并创建 GitHub 发布。

## 变更记录

见 [`CHANGELOG.md`](CHANGELOG.md)。
