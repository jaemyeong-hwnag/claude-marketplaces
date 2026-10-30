# go-naming

[English](README.md) · [한국어](README.ko.md) · **简体中文**

按 Go 约定强制 Go 代码的命名 —— 包名为小写单词，函数·类型·变量·常量·字段用 MixedCaps（禁止下划线），首字母缩略词大写，getter 省略 `Get`，文件名小写，接收者用简短缩写。

形式由钩子拦截，用哪个词由 `go-name-create` 技能判断。依据为 Effective Go 的 Names 一节 · Go Code Review Comments · Go 博客文章 "Package names" · staticcheck ST1003。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install go-naming@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| go-name-create | 编写 Go 代码 · 为包 · 函数 · 类型 · 接收者命名 | 形式表与选词判断（包名重复 · `-er` 接口 · 简短局部变量 · 是否导出） |
| /go-naming-validate | 直接调用 | 校验项目中所有 `*.go`，按条款报告 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-go-naming.sh | PreToolUse (Write\|Edit) | `*.go` 编辑**新引入**违规时**拦截**，警告条款仅提示 |

## 注意事项

- 钩子比较编辑前后，**只拦截新增的违规**。修改遗留文件的其他行时不会因已有名称被拦截。已有违规用 `/go-naming-validate` 查找
- 不用语法分析器，按行读取。不检查局部变量 · 参数 · `:=`，也不检查写在一行内的结构体（`struct{ A_b int }`）的字段
- 常量同样用 MixedCaps —— `MAX_SIZE` 会被拦截（`MaxSize`）。像 cgo · syscall 常量那样必须沿用 C 名称时，放在生成文件或已有文件中
- 不检查 `vendor/` · `testdata/` · `node_modules/` 以及带 `// Code generated ... DO NOT EDIT.` 标记的文件
- 需要 `jq`

## 规则摘要

| 条款 | 对象 | 规则 | 判定 |
|---|---|---|---|
| `GO-01` | `package` 名 | 小写单词（允许 `_test` 后缀） | 拦截 |
| `GO-02` | 函数 · 方法 · 类型 · 顶层 var/const · 结构体字段 | 无下划线的 MixedCaps（允许 `_test.go` 中的 `Test*` 等） | 拦截 |
| `GO-03` | 名称中的首字母缩略词 | `userID` · `HTTPClient`（不用 `userId`） | 警告 |
| `GO-04` | 无参数的 `GetX()` 方法 | getter 不加 `Get`（`Owner()`） | 警告 |
| `GO-05` | 文件名 | 小写 · 数字 · 下划线（`order_service.go`） | 警告 |
| `GO-06` | 方法接收者 | 不用 `this` · `self` → `func (o *Order)` | 警告 |

原文：[`references/go-naming-rules.md`](references/go-naming-rules.md)

## 使用

```bash
scripts/validate-go-naming.sh ./internal     # 目录
scripts/validate-go-naming.sh --all .        # 整个项目
test/validate-go-naming.test.sh              # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
