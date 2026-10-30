# plugin-naming

[English](README.md) · [한국어](README.ko.md) · **简体中文**

用统一规则和词典强制插件 · 技能 · 命令 · 代理的名称。

只处理**名称**。放在哪个目录、如何分发，不属于本插件的范围。

## 安装

在本仓库中由 SessionStart 钩子（`.claude/hooks/sync-internal-plugins.sh`）注册 · 启用 · 安装。
这是 internal 插件，不分发到其他仓库。要在别处使用，请移到 `public-plugins/`。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| name-create | 起名 · 改名，创建插件 · 技能 · 命令 | 从目的句（"没有它会 …"）中选出要承载的概念，用 `{대상}-{범위}-{관심사}-{행위}`（对象-范围-关注点-行为）槽位（每个槽位 1 ~ 3 个词）和词典确定名称。通过的名称交给 `naming-reviewer` 判定 |
| glossary-update | 向词典添加 · 修改词，"这个词能用吗" | 遵守重复 · 排序 · 分类规则修改词典 |
| /naming-review | 直接调用 | 验证并判定单个名称或整个仓库 |

## 代理

| 代理 | 说明 |
|---|---|
| naming-reviewer | 判定通过机械规则的名称能否说明它指什么，目的句的关键词是否体现在名称中 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-naming.sh | PreToolUse (Write\|Edit) | 从路径中提取名称，违反规则则**阻止**；通过的新名称则请求 AI 判断 |
| validate-naming.sh | PostToolUse (Write\|Edit) | 保存 `glossary.json` 时验证词典结构 |

## 文件

| 路径 | 作用 |
|---|---|
| `references/naming-rules.md` | 命名规则原文。唯一标准 |
| `references/glossary.json` | 默认词典（`use` / `deny` / `meaning`） |
| `scripts/validate-naming.sh` | 机械验证。钩子与 CLI 共用 |
| `test/` | 回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 — 起名技能触发 · 阻止单词名称。由 `plugin-workflow` 的 `eval-all.sh` 运行 |

## 行为

`Write` / `Edit` 时从路径中提取名称并检查，违反则以退出码 2 阻止。

| 路径模式 | 检查对象 |
|---|---|
| `*plugins/<名称>/...` | 插件名 |
| `.../skills/<名称>/...` | 技能名 |
| `.../commands/<名称>.md` | 命令名 |
| `.../agents/<名称>.md` | 代理名 |

其他路径不响应。像 `plugins/`、`public-plugins/`、`my-own-plugins/` 这样**名为 `plugins` 或以 `-plugins` 结尾的目录**，都视为插件位置。这些目录的含义由仓库决定。

## 项目专用词典

词典按以下顺序解析。

1. `$NAMING_GLOSSARY`
2. 编辑路径（CLI 为当前目录，`--all` 为根目录）所在 git 顶层的 `internal-plugins/plugin-naming/references/glossary.json` ← 在工作树中修改的词典
3. `$CLAUDE_PROJECT_DIR/references/glossary.json` ← 项目专用
4. `${CLAUDE_PLUGIN_ROOT}/references/glossary.json` ← 插件默认

项目词典会**替换**插件词典。不是合并，所以先复制默认词典再加入领域词。

## CLI

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" <名称或路径>
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --all .
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --glossary
```

## 测试

```bash
test/validate-naming.test.sh
```

TC 规格见 [`test/README.md`](test/README.md)。

## 变更记录

见 [`CHANGELOG.md`](CHANGELOG.md)。
