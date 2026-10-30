# typescript-naming

[English](README.md) · [한국어](README.ko.md) · **简体中文**

按 TypeScript 惯例强制 TypeScript 源码中的标识符 —— 类型·类·enum 用 PascalCase，变量·函数用 camelCase（禁止 snake_case），对 interface 的 I 前缀·enum 成员·类型参数·class 成员给出警告。

形式由钩子拦截，用哪个词由 `typescript-name-create` 技能判断。依据为 TypeScript 团队 Coding guidelines 的 Names 一节 · TypeScript Handbook · typescript-eslint `naming-convention` 默认值 · Google TypeScript Style Guide 的 Identifiers 一节。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install typescript-naming@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| typescript-name-create | 编写 `.ts` · `.tsx` 代码 · 为 interface · type · 泛型命名 | 形式表与选词判断（类型与值重名 · `Props` 后缀 · boolean · 联合字面量 · 缩写） |
| /typescript-naming-validate | 直接调用 | 校验项目中所有 `*.ts` · `*.tsx` · `*.mts` · `*.cts`，按条款报告 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-typescript-naming.sh | PreToolUse (Write\|Edit) | `*.ts` · `*.tsx` · `*.mts` · `*.cts` 编辑**新引入**违规时**拦截**，警告条款仅提示 |

## 注意事项

- 钩子比较编辑前后，**只拦截新增的违规**。修改遗留文件的其他行时不会因已有名称被拦截。已有违规用 `/typescript-naming-validate` 查找
- 不用解析器，按行读取。解构 · 对象字面量键 · interface 和 type 的属性 · 参数不检查 —— 由技能判断
- class 成员只检查以访问修饰符（`public` · `protected` · `private`）或 `readonly` 开头的声明。有些 DTO 直接接收 API 载荷，因此只给警告
- 不检查文件名 · `package.json` · 环境变量名
- 不检查 `*.d.ts` · `*.d.mts` · `*.d.cts` 以及 `node_modules/` · `dist/` · `build/` · `out/` · `coverage/` · `.next/` · `generated/` · `__generated__/`
- 需要 `jq`

## 规则摘要

| 条款 | 对象 | 规则 | 判定 |
|---|---|---|---|
| `TS-01` | class · interface · type · enum · namespace | PascalCase | 拦截 |
| `TS-02` | interface | 无 `I` 前缀（不用 `IUser`） | 警告 |
| `TS-03` | `let` · `const` · `var` · `function` | 禁止小写 snake_case → camelCase（允许 UPPER_SNAKE · PascalCase · 前导下划线） | 拦截 |
| `TS-04` | enum 成员 | PascalCase 或 UPPER_SNAKE_CASE | 警告 |
| `TS-05` | 类型参数 | `T` · `TKey` · PascalCase | 警告 |
| `TS-06` | class 成员（访问修饰符 · `readonly`） | 禁止 snake_case → camelCase | 警告 |

原文：[`references/typescript-naming-rules.md`](references/typescript-naming-rules.md)

## 使用

```bash
scripts/validate-typescript-naming.sh src           # 目录
scripts/validate-typescript-naming.sh --all .       # 整个项目
test/validate-typescript-naming.test.sh             # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
