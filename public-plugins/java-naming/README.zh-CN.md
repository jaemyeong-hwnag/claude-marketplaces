# java-naming

[English](README.md) · [한국어](README.ko.md) · **简体中文**

按 Java 约定强制 Java 代码的命名 —— 包名小写，类型 UpperCamelCase，public 类型与文件名一致，常量 UPPER_SNAKE_CASE，方法·字段 lowerCamelCase。

形式由钩子拦截，用哪个词由 `java-name-create` 技能判断。依据为 Google Java Style Guide 第 5 章 · Oracle Code Conventions 第 9 章。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install java-naming@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| java-name-create | 编写 Java 代码 · 为类 · 方法 · 变量命名 | 形式表与选词判断（缩写 · 角色后缀 · boolean · 集合） |
| /java-naming-validate | 直接调用 | 校验项目中所有 `*.java`，按条款报告 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-java-naming.sh | PreToolUse (Write\|Edit) | `*.java` 编辑**新引入**违规时**拦截**，警告条款仅提示 |

## 注意事项

- 钩子比较编辑前后，**只拦截新增的违规**。修改遗留文件的其他行时不会因已有名称被拦截。已有违规用 `/java-naming-validate` 查找
- 成员只检查以访问修饰符（`public` · `protected` · `private`）开头的声明。局部变量 · 参数 · enum 常量由技能判断
- `static final` 中只有基本类型 · `String` 判定为常量。`Logger` · 集合是否为常量，机器无法判断
- 不检查 `build/` · `target/` · `out/` · `.gradle/` · `generated/` · `node_modules/` · `vendor/`
- 需要 `jq`

## 规则摘要

| 条款 | 对象 | 规则 | 判定 |
|---|---|---|---|
| `JN-01` | 包 | 小写，无下划线 | 大写拦截 · 下划线警告 |
| `JN-02` | 类 · 接口 · enum · record · 注解 | UpperCamelCase | 拦截 |
| `JN-03` | public 顶层类型 | 与文件名相同 | 拦截 |
| `JN-04` | `static final` 基本类型 · `String` | UPPER_SNAKE_CASE | 拦截 |
| `JN-05` | 方法 · 字段 | lowerCamelCase（测试路径中的方法允许下划线） | 拦截 |
| `JN-06` | 类型名中的缩写 | `HttpClient`（不用 `HTTPClient`） | 警告 |

原文：[`references/java-naming-rules.md`](references/java-naming-rules.md)

## 使用

```bash
scripts/validate-java-naming.sh src/main/java     # 目录
scripts/validate-java-naming.sh --all .           # 整个项目
test/validate-java-naming.test.sh                 # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
