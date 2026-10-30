# plugin-dependency

[English](README.md) · [한국어](README.ko.md) · **简体中文**

强制插件之间的**依赖关系** — 存在 · 循环 · common 与捆绑包的层级 · 市场边界 · 禁止 public→internal · 版本范围重叠。

范围字符串的格式由 `plugin-versioning`（`V-11`）、名称由 `plugin-naming`、位置由 `marketplace-directory-structure` 检查。这里只看**关系**。

## 安装

在本仓库中由 SessionStart 钩子（`.claude/hooks/sync-internal-plugins.sh`）注册 · 启用 · 安装。
这是 internal 插件，不分发到其他仓库。要在别处使用，请移到 `public-plugins/`。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| dependency-update | 添加 · 修改 · 删除依赖，组建 common · 捆绑包 | 判断层级方向与 common 资格 |
| /dependency-validate | 直接调用 | 验证整个仓库的依赖图；给出名称则显示反向依赖 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-dependency.sh | PostToolUse (Write\|Edit) | 保存 `plugin.json` 后重新检查整个仓库的依赖图并**提醒** |

## 文件

| 路径 | 作用 |
|---|---|
| `references/dependency-rules.md` | 依赖规则原文（`D-01` ~ `D-11`） |
| `scripts/validate-dependency.sh` | 机械验证。图计算（循环 · 范围交集）用 jq 完成 — macOS 默认 bash 3.2 没有关联数组 |
| `test/` | 回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 — 捆绑包指引技能触发 · 循环提醒。由 `plugin-workflow` 的 `eval-all.sh` 运行 |

## 检查什么

| | 条款 |
|---|---|
| 依赖图 | `D-01` 目标存在 · `D-02` 自我依赖 · `D-03` 循环 · `D-11` 重复声明 |
| 层级 | `D-04` common 不依赖任何插件 · `D-05` 禁止捆绑包 → 捆绑包 · `D-06` 捆绑包只有 dependencies |
| 边界 | `D-07` 禁止其他市场 · `D-08` 禁止 public → internal |
| 范围 | `D-09` 同一目标的范围必须重叠 · `D-10` 精确固定为警告 |

## 钩子只提醒的原因

断开循环或对齐范围往往需要修改**两个插件**。若第一次编辑就阻止，问题将无法解决。`--all` 会阻止。

## 用法

在仓库根目录运行。`--all` 一个插件都找不到时为执行错误（退出码 `1`）。

```bash
internal-plugins/plugin-dependency/scripts/validate-dependency.sh --all .                       # 整个仓库
internal-plugins/plugin-dependency/scripts/validate-dependency.sh --dependents common-naming .  # 谁依赖它
internal-plugins/plugin-dependency/scripts/validate-dependency.sh internal-plugins/order-sync   # 仅此插件的声明
internal-plugins/plugin-dependency/test/validate-dependency.test.sh                             # 回归测试
```

## 变更记录

见 [`CHANGELOG.md`](CHANGELOG.md)。
