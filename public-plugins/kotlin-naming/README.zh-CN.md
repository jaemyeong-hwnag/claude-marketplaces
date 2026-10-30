# kotlin-naming

[English](README.md) · [한국어](README.ko.md) · **简体中文**

按 Kotlin 约定强制 Kotlin 代码的命名 —— 包名小写，类型 UpperCamelCase，只有一个类的文件与文件名一致，const val SCREAMING_SNAKE_CASE，函数·属性 lowerCamelCase。

形式由钩子拦截，用哪个词由 `kotlin-name-create` 技能判断。依据为 Kotlin 官方 Coding conventions 的 Naming rules 一节，Android Kotlin style guide 仅作参考。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install kotlin-naming@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| kotlin-name-create | 编写 Kotlin 代码 · 为 data class · 扩展函数 · 属性命名 | 形式表与选词判断（扩展函数 · Boolean · Flow · suspend · 工厂 · 测试名） |
| /kotlin-naming-validate | 直接调用 | 校验项目中所有 `*.kt`，按条款报告 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-kotlin-naming.sh | PreToolUse (Write\|Edit) | `*.kt` 编辑**新引入**违规时**拦截**，警告条款仅提示 |

## 注意事项

- 钩子比较编辑前后，**只拦截新增的违规**。修改遗留文件的其他行时不会因已有名称被拦截。已有违规用 `/kotlin-naming-validate` 查找
- 不检查 `*.kts`（`build.gradle.kts` 等）
- `val` · `var` 只拦截以小写字母开头的 snake_case。SCREAMING_SNAKE_CASE 是否为深度不可变值、UpperCamelCase 是否为单例引用，机器无法判断
- 以大写字母开头的函数只允许 `@Composable` 和返回类型与名称相同的工厂函数。测试路径中的函数名允许下划线
- 参数 · enum 常量 · lambda 参数由技能判断
- 不检查 `build/` · `target/` · `out/` · `.gradle/` · `generated/` · `node_modules/`
- 需要 `jq`

## 规则摘要

| 条款 | 对象 | 规则 | 判定 |
|---|---|---|---|
| `KN-01` | 包 | 各段以小写开头（允许 camelCase），无下划线 | 大写开头拦截 · 下划线警告 |
| `KN-02` | class · interface · object · enum / annotation / data / sealed / value class · fun interface · typealias | UpperCamelCase | 拦截 |
| `KN-03` | 文件名 | 顶层声明只有一个类时用其名称，否则 UpperCamelCase | 只有一个时拦截 · 其他警告 |
| `KN-04` | `const val` | SCREAMING_SNAKE_CASE | 拦截 |
| `KN-05` | `fun` | lowerCamelCase（例外：反引号 · `@Composable` · 工厂 · 测试下划线） | 拦截 |
| `KN-06` | `val` · `var` | 禁止以小写开头的 snake_case（允许 `_name` · SCREAMING · UpperCamel） | 拦截 |
| `KN-07` | 类型名中的缩写 | `HttpClient`（不用 `HTTPClient`，`IOStream` 可以） | 警告 |

原文：[`references/kotlin-naming-rules.md`](references/kotlin-naming-rules.md)

## 使用

```bash
scripts/validate-kotlin-naming.sh src/main/kotlin   # 目录
scripts/validate-kotlin-naming.sh --all .           # 整个项目
test/validate-kotlin-naming.test.sh                 # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
