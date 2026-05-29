from __future__ import annotations

import ast
import itertools
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
    def __init__(self, line_offset: int, add_finding: FindingFactory) -> None:
        self.line_offset = line_offset
        self.add_finding = add_finding
        self.paths: dict[str, str] = {}
        self.texts: dict[str, str] = {}
        self.lists: dict[str, list[str]] = {}
        self.loop_values: dict[str, list[str]] = {}
        self.findings: list[object] = []

    def visit_Assign(self, node: ast.Assign) -> None:
        names = [target.id for target in node.targets if isinstance(target, ast.Name)]
        values = self.literal_list(node.value)
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
        if not isinstance(node.target, ast.Name) or not isinstance(node.iter, ast.Name):
            self.generic_visit(node)
            return
        values = self.lists.get(node.iter.id)
        if values is None:
            self.generic_visit(node)
            return
        previous = self.loop_values.get(node.target.id)
        self.loop_values[node.target.id] = values
        for child in node.body:
            self.visit(child)
        if previous is None:
            self.loop_values.pop(node.target.id, None)
        else:
            self.loop_values[node.target.id] = previous
        for child in node.orelse:
            self.visit(child)

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
        self.generic_visit(node)

    def record(self, line_no: int, assertion: str, pattern: str, target: str) -> None:
        finding = self.add_finding(
            self.line_offset + line_no - 1, assertion, pattern, target
        )
        if finding is not None:
            self.findings.append(finding)

    def literal_list(self, node: ast.AST) -> list[str] | None:
        if not isinstance(node, (ast.List, ast.Tuple)):
            return None
        values: list[str] = []
        for item in node.elts:
            if not isinstance(item, ast.Constant) or not isinstance(item.value, str):
                return None
            values.append(item.value)
        return values

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
        if isinstance(node, ast.Call) and node.args:
            return self.path_value(node.args[0])
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Div):
            left = self.path_value(node.left)
            right = self.path_value(node.right)
            if left is not None and right is not None:
                return f"{left.rstrip('/')}/{right.lstrip('/')}"
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


def python_heredoc_findings(
    unit: ShellUnit, add_finding: FindingFactory
) -> list[object]:
    try:
        tree = ast.parse("\n".join(unit.body))
    except SyntaxError:
        return []
    visitor = PythonProseVisitor(unit.line, add_finding)
    visitor.visit(tree)
    return visitor.findings
