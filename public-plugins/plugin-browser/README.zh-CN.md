# plugin-browser

[English](README.md) · [한국어](README.ko.md) · **简体中文**

在终端中查看、挑选并安装 plugin-search-install 查询结果的 CLI 界面 — 按宽度显示为表格 · 精简表格 · 卡片 · 列表，处理韩文 · 表情符号 · 歧义宽度字符，支持方向键 · 空格选择和编号输入、菜单、范围确认。

```
검색 테스트 커버리지  3개
──────────────────────────────────────────────────────────────────────────────
#   이름                         마켓                  설명
1   java-spring-aitest-coverage  jaemyeong-hwnag-plu⋯  Java · Spring Boot(Gr⋯
2 ✓ project-completeness         jaemyeong-hwnag-plu⋯  프로젝트가 서비스로서 ⋯

❯ [x]   java-spring-aitest-coverage  Java · Spring Boot(Gradle) 프로젝트에서 ⋯
  [ ] ✓ project-completeness         프로젝트가 서비스로서 갖출 것을 갖췄는지 재⋯
↑↓ 이동 · Space 선택 · a 전부 · n 해제 · i 반전 · Enter 설치 · q 취소
```

查询与安装由 [`plugin-search-install`](../plugin-search-install/README.md) 完成。本插件只负责绘制其结果（JSON）并供挑选。

## 安装

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install plugin-browser@jaemyeong-hwnag-plugins --scope user
```

`plugin-search-install` 作为依赖一并安装。需要：`bash`（3.2 及以上）、`jq`（1.6 及以上）、`stty`。

要在终端直接使用，可设置别名（路径为 `claude plugin list --json` 中的 `installPath`）。

```bash
alias plugins='bash <installPath>/scripts/plugin-browser.sh'
```

## 依赖

| 插件 | 原因 |
|---|---|
| plugin-search-install | 目录 · 搜索 · 关联 · 项目 · 安装引擎 |

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| plugin-browser | 我想在终端里选 · 用表格显示 · 插件浏览器 | 在 Claude 内以代码块展示固定宽度的渲染结果；交互式使用时给出用户终端要执行的命令 |

## 注意事项

- **交互式选择只在真正的终端中打开**（stdin · stdout 均为 TTY）。在 Claude 的 Bash、管道、CI 中只输出静态界面和 `--select` 提示
- 对于把歧义宽度字符（`·` `─` `…`）画成两格的终端（东亚宽度设置），启动时询问光标位置来判别。终端不响应时等待 1 秒后按一格处理 — 可用 `PLUGIN_BROWSER_AMBIGUOUS=1|2` 固定
- 窗口大小变化在 1 秒内重绘（用周期检查代替 `SIGWINCH` — bash 3.2 的 `read` 不会被信号唤醒）
- 终端窄于 10 列时不绘制，只给出提示
- 表情符号宽度以 Unicode 15.1 为准（带 VS16 的字符为两格）。旧终端 · 字体可能把部分表情符号画成一格，行会变短（不会溢出）
- 安装默认为 `project` 范围。选择界面之后会询问范围

## 用法

```bash
P=scripts/plugin-browser.sh
$P                                   # 菜单
$P project                           # 本项目需要的插件
$P search naming has:hook -java      # 查询语法与 plugin-search-install 相同
$P related java-naming --by name
$P installed
$P show github-workflow
$P facets                             # 领域 · 技术 · 标签（说明）· 组件 · 已安装 · 关键词
$P search 커버리지 --width 60 --no-pick           # 只绘制，固定宽度
$P search 커버리지 --select 1,3 --scope user --dry-run   # 不询问，显示安装计划
plugin-search-install.sh search x | $P render -   # 只绘制引擎 JSON
```

| 选项 | 含义 |
|---|---|
| `--width N` | 固定宽度，10 及以上（默认：终端 → `$COLUMNS` → 80） |
| `--ascii` | 用 ASCII 装饰（非 UTF-8 语言环境自动启用） |
| `--color auto\|always\|never` | 默认 auto — 为 TTY、未设置 `NO_COLOR` 且 `TERM` 不是 `dumb` 时 |
| `--plain` | 用编号输入代替方向键选择 |
| `--no-pick` | 只绘制 |
| `--select` · `--install-all` · `--scope` · `--dry-run` | 不询问直接安装 |

## 按宽度的布局

| 宽度 | 布局 |
|---|---|
| 120 及以上 | 表格 — # · 标记 · 名称 · 市场 · 标签 · 原因 · 说明 |
| 100 ~ 119 | 表格 — # · 标记 · 名称 · 市场 · 说明 |
| 70 ~ 99 | 单行 — # · 标记 · 名称 · 说明 |
| 40 ~ 69 | 卡片 — 名称 / 市场 · 标签 / 说明 2 行 / 原因 |
| 40 以下 | 列表 — 名称 / 说明 1 行（24 及以上） |

标记：`✓` 已安装 · `!` 必需但缺失 · `-` 已停用（ASCII 为 `*` `!` `-`）。每行都在 宽度 − 1 格以内（针对写到最后一列会自动换行的终端）。

## 文件

| 路径 | 作用 |
|---|---|
| `scripts/plugin-browser.sh` | 菜单 · 渲染 · 交互式选择 · 安装确认 |
| `references/display-width.json` | 显示宽度表 — 0 格 · 2 格 · 歧义宽度范围（Unicode 15.1，韩文音节走脚本的快速路径） |
| `test/` | 回归测试与 TC 规格 — 19 种宽度 · pty 操作 |
| `evals/` | `claude plugin eval` 用例 — 技能触发（`browser-request`） |

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
