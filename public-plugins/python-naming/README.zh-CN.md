# python-naming

[English](README.md) · [한국어](README.ko.md) · **简体中文**

按 PEP 8 强制 Python 代码的命名 —— 模块文件小写 snake_case，类 CapWords，函数·方法 snake_case，参数·变量 mixedCase 警告，异常类 Error 后缀。

形式由钩子拦截，用哪个词由 `python-name-create` 技能判断。依据为 PEP 8 的 Naming Conventions 一节和 pep8-naming（flake8 插件）的 `N8xx` 规则。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install python-naming@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| python-name-create | 编写 Python 代码 · 为模块 · 类 · 函数 · 变量命名 | 形式表与选词判断（缩写 · 遮蔽内置名 · 下划线前缀 · boolean · 集合 · TypeVar） |
| /python-naming-validate | 直接调用 | 校验项目中所有 `*.py`，按条款报告 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-python-naming.sh | PreToolUse (Write\|Edit) | `*.py` 编辑**新引入**违规时**拦截**，警告条款仅提示 |

## 注意事项

- 钩子比较编辑前后，**只拦截新增的违规**。修改遗留文件的其他行时不会因已有名称被拦截。已有违规用 `/python-naming-validate` 查找
- 行尾带 `# noqa` 或 `# noqa: N8xx` 的行不检查（与 pep8-naming 相同的豁免方式）。unittest 的 `setUp` 系列 · `visit_X` · `do_GET` · 带 `@override` 的方法不拦截
- 不是语法树，而是按行读取。参数 · 变量 · 异常类可能误报，因此只给警告
- 不检查 `venv/` · `.venv/` · `site-packages/` · `__pycache__/` · `build/` · `dist/` · `.tox/` · `.eggs/` · `node_modules/` · `migrations/` · `alembic/versions/`
- 需要 `jq`

## 规则摘要

| 条款 | 对象 | 规则 | 判定 |
|---|---|---|---|
| `PY-01` | 模块文件名 | 小写 snake_case（允许 `__init__.py`） | 拦截 |
| `PY-02` | `class` | CapWords（允许前导下划线） | 拦截 |
| `PY-03` | `def` · `async def` | snake_case（允许前导下划线 · dunder · unittest · `visit_X`） | 拦截 |
| `PY-04` | 参数 | snake_case —— mixedCase 警告 | 警告 |
| `PY-05` | 赋值目标 | mixedCase 警告（允许 UPPER_SNAKE 常量） | 警告 |
| `PY-06` | 异常类 | 以 `Error` 结尾 | 警告 |

原文：[`references/python-naming-rules.md`](references/python-naming-rules.md)

## 使用

```bash
scripts/validate-python-naming.sh app             # 目录
scripts/validate-python-naming.sh --all .         # 整个项目
test/validate-python-naming.test.sh               # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
