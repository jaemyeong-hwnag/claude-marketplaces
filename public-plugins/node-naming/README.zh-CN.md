# node-naming

[English](README.md) · [한국어](README.ko.md) · **简体中文**

按 npm 规则和 JavaScript 惯例强制 Node.js 项目的命名 —— package.json name，环境变量 UPPER_SNAKE_CASE，类 PascalCase，变量·函数 camelCase，文件 kebab-case。

形式由钩子拦截，用哪个词由 `node-name-create` 技能判断。依据为 npm 的 package.json `name` 规则 · Airbnb JavaScript Style Guide 的 Naming Conventions · Node.js 与 POSIX 环境变量惯例。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install node-naming@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| node-name-create | package.json · npm 包名 · npm script · 环境变量名 · `.js` · `.mjs` | 形式表与选词判断（环境变量前缀 · 模块文件与 export · CLI bin · 事件名） |
| /node-naming-validate | 直接调用 | 校验整个项目的 `package.json` · JS 文件 · 环境变量，按条款报告 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-node-naming.sh | PreToolUse (Write\|Edit) | `package.json` · `*.js` · `*.mjs` · `*.cjs` · `*.jsx`（以及 TS 中的环境变量）编辑**新引入**违规时**拦截**，警告条款仅提示 |

## 注意事项

- 钩子比较编辑前后，**只拦截新增的违规**。修改遗留文件的其他行时不会因已有名称被拦截。已有违规用 `/node-naming-validate` 查找
- TS 文件（`*.ts` · `*.tsx` · `*.mts` · `*.cts`）只检查环境变量（`ND-03`）。标识符由 `typescript-naming` 负责
- 变量 · 函数只检查 `let` · `const` · `var` · `function` 声明中的第一个名称。方法 · 对象属性 · 参数 · 解构由技能判断
- 像 `const { dbHost } = process.env` 这样通过解构读取的环境变量不检查
- 编辑后的 `package.json` 不是合法 JSON 时不做判定
- 不检查 `node_modules/` · `dist/` · `build/` · `out/` · `coverage/` · `.next/` · `generated/` · `vendor/` 以及 `*.min.js`
- 需要 `jq`

## 规则摘要

| 条款 | 对象 | 规则 | 判定 |
|---|---|---|---|
| `ND-01` | `package.json` 顶层 `name` | npm 规则（≤ 214 字符 · 小写 · 不以 `.` `_` 开头 · URL 安全 · `@scope/name`） | 拦截 |
| `ND-02` | `package.json` 的 `scripts` 键 | 小写 · 数字用 `-` 和 `:` 连接（`test:unit`） | 警告 |
| `ND-03` | `process.env.NAME` · `process.env['NAME']` | UPPER_SNAKE_CASE（例外：`npm_*` · 代理变量） | 拦截 |
| `ND-04` | JS 类 | PascalCase | 拦截 |
| `ND-05` | JS `let` · `const` · `var` · `function` | 禁止含小写的 snake_case → camelCase | 拦截 |
| `ND-06` | JS 文件名 | kebab-case，或取自 export 名的 camelCase · PascalCase。仅对下划线警告 | 警告 |

原文：[`references/node-naming-rules.md`](references/node-naming-rules.md)

## 使用

```bash
scripts/validate-node-naming.sh src package.json     # 文件 · 目录
scripts/validate-node-naming.sh --all .              # 整个项目
test/validate-node-naming.test.sh                    # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
