from __future__ import annotations

import ast
import itertools
import shlex
from typing import NamedTuple, Protocol


class ShellUnit(NamedTuple):
    kind: str
    line: int
    command: str
    body: list[str]


class FindingFactory(Protocol):
    def __call__(
        self,
        line_no: int,
        assertion: str,
        pattern: str,
        target: str,
    ) -> object | None: ...


class PythonProseVisitor(ast.NodeVisitor):
    def __init__(
        self, line_offset: int, add_finding: FindingFactory, argv: dict[int, str]
    ) -> None:
        self.line_offset = line_offset
        self.add_finding = add_finding
        self.argv = argv
        self.paths: dict[str, str] = {}
        self.texts: dict[str, str] = {}
        self.lists: dict[str, list[str]] = {}
        self.loop_values: dict[str, list[str]] = {}
        self.findings: list[object] = []

    def visit_Assign(self, node: ast.Assign) -> None:
        names = [target.id for target in node.targets if isinstance(target, ast.Name)]
        values = self.literal_strings(node.value)
        source = self.read_text_source(node.value)
        path_value = self.path_value(node.value)
        for name in names:
            if values is not None:
                self.lists[name] = values
            if source is not None:
                self.texts[name] = source
            if path_value is not None:
                self.paths[name] = path_value
        self.generic_visit(node)

    def visit_For(self, node: ast.For) -> None:
        values = self.iter_values(node.iter)
        if values is None:
            self.generic_visit(node)
            return
        previous = self.bind_loop(node.target, values)
        for child in node.body:
            self.visit(child)
        self.restore_loop(previous)
        for child in node.orelse:
            self.visit(child)

    def visit_ListComp(self, node: ast.ListComp) -> None:
        previous: list[tuple[str, list[str] | None]] = []
        for generator in node.generators:
            values = self.iter_values(generator.iter)
            if values is None:
                continue
            previous.extend(self.bind_loop(generator.target, values))
            for condition in generator.ifs:
                self.visit(condition)
        self.visit(node.elt)
        self.restore_loop(previous)

    def visit_Compare(self, node: ast.Compare) -> None:
        if len(node.ops) == 1 and len(node.comparators) == 1:
            target = self.text_source(node.comparators[0])
            patterns = self.string_values(node.left)
            if target and patterns and isinstance(node.ops[0], (ast.In, ast.NotIn)):
                assertion = (
                    "absent" if isinstance(node.ops[0], ast.NotIn) else "present"
                )
                for pattern in patterns:
                    self.record(node.lineno, assertion, pattern, target)
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call) -> None:
        if isinstance(node.func, ast.Attribute) and node.func.attr == "startswith":
            target = self.text_source(node.func.value)
            if target and node.args:
                for pattern in self.string_values(node.args[0]) or []:
                    self.record(node.lineno, "present", pattern, target)
        if self.is_re_match_call(node) and len(node.args) >= 2:
            target = self.text_source(node.args[1])
            patterns = self.string_values(node.args[0])
            if target and patterns:
                for pattern in patterns:
                    self.record(node.lineno, "present", pattern, target)
        self.generic_visit(node)

    def is_re_match_call(self, node: ast.Call) -> bool:
        return (
            isinstance(node.func, ast.Attribute)
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "re"
            and node.func.attr in {"search", "match"}
        )

    def record(self, line_no: int, assertion: str, pattern: str, target: str) -> None:
        finding = self.add_finding(
            self.line_offset + line_no - 1, assertion, pattern, target
        )
        if finding is not None:
            self.findings.append(finding)

    def literal_strings(self, node: ast.AST) -> list[str] | None:
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return [node.value]
        if isinstance(node, (ast.List, ast.Tuple, ast.Set)):
            return self.collect_strings(node.elts)
        if not isinstance(node, ast.Dict):
            return None
        values = []
        for item in itertools.chain(node.keys, node.values):
            if item is None:
                continue
            nested = self.literal_strings(item)
            if nested is None:
                return None
            values.extend(nested)
        return values

    def collect_strings(self, nodes: list[ast.AST]) -> list[str] | None:
        values: list[str] = []
        for item in nodes:
            nested = self.literal_strings(item)
            if nested is None:
                return None
            values.extend(nested)
        return values

    def iter_values(self, node: ast.AST) -> list[str] | None:
        if isinstance(node, ast.Name):
            return self.lists.get(node.id) or self.loop_values.get(node.id)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            if node.func.attr in {"items", "values"} and isinstance(
                node.func.value, ast.Name
            ):
                return self.lists.get(node.func.value.id)
        return None

    def bind_loop(
        self, target: ast.AST, values: list[str]
    ) -> list[tuple[str, list[str] | None]]:
        names: list[str] = []
        if isinstance(target, ast.Name):
            names.append(target.id)
        elif isinstance(target, ast.Tuple):
            names.extend(item.id for item in target.elts if isinstance(item, ast.Name))
        previous = [(name, self.loop_values.get(name)) for name in names]
        for name in names:
            self.loop_values[name] = values
        return previous

    def restore_loop(self, previous: list[tuple[str, list[str] | None]]) -> None:
        for name, values in previous:
            if values is None:
                self.loop_values.pop(name, None)
            else:
                self.loop_values[name] = values

    def read_text_source(self, node: ast.AST) -> str | None:
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            if node.func.attr == "read_text":
                return self.path_value(node.func.value)
        return None

    def path_value(self, node: ast.AST) -> str | None:
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return node.value
        if isinstance(node, ast.Name):
            return self.paths.get(node.id, node.id)
        if isinstance(node, ast.Subscript):
            return self.argv_subscript(node)
        if isinstance(node, ast.Call) and node.args:
            return self.path_value(node.args[0])
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Div):
            left = self.path_value(node.left)
            right = self.path_value(node.right)
            if left is not None and right is not None:
                return f"{left.rstrip('/')}/{right.lstrip('/')}"
        return None

    def argv_subscript(self, node: ast.Subscript) -> str | None:
        if not (
            isinstance(node.value, ast.Attribute)
            and isinstance(node.value.value, ast.Name)
            and node.value.value.id == "sys"
            and node.value.attr == "argv"
        ):
            return None
        if isinstance(node.slice, ast.Constant) and isinstance(node.slice.value, int):
            return self.argv.get(node.slice.value)
        return None

    def text_source(self, node: ast.AST) -> str | None:
        if isinstance(node, ast.Name):
            return self.texts.get(node.id)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            return self.text_source(node.func.value)
        return None

    def string_values(self, node: ast.AST) -> list[str] | None:
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return [node.value]
        if isinstance(node, ast.Name):
            return self.loop_values.get(node.id)
        if not isinstance(node, ast.JoinedStr):
            return None
        parts: list[list[str]] = []
        for value in node.values:
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                parts.append([value.value])
            elif isinstance(value, ast.FormattedValue):
                nested = self.string_values(value.value)
                if nested is None:
                    return None
                parts.append(nested)
            else:
                return None
        return ["".join(items) for items in itertools.product(*parts)]


def python_argv(
    command: str, assignments: dict[str, str] | None = None
) -> dict[int, str]:
    assignments = assignments or {}
    try:
        words = shlex.split(command, comments=False, posix=True)
    except ValueError:
        return {}
    for index, word in enumerate(words):
        if word not in {"python", "python3"} and not word.endswith(
            ("/python", "/python3")
        ):
            continue
        args = []
        for arg in words[index + 2 :]:
            if arg.startswith("<<"):
                break
            if arg.startswith("$"):
                args.append(assignments.get(arg.strip("${}"), arg))
            else:
                args.append(arg)
        return {idx: value for idx, value in enumerate(args, start=1)}
    return {}


def python_heredoc_findings(
    unit: ShellUnit,
    add_finding: FindingFactory,
    assignments: dict[str, str] | None = None,
) -> list[object]:
    try:
        tree = ast.parse("\n".join(unit.body))
    except SyntaxError:
        return []
    visitor = PythonProseVisitor(
        unit.line, add_finding, python_argv(unit.command, assignments)
    )
    visitor.visit(tree)
    return visitor.findings
