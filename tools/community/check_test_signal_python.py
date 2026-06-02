from __future__ import annotations

import ast
import itertools
import re
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
        self,
        line_offset: int,
        add_finding: FindingFactory,
        argv: dict[int, str],
        *,
        track_collections: bool = True,
        collection_filter: str = "all",
    ) -> None:
        self.line_offset = line_offset
        self.add_finding = add_finding
        self.argv = argv
        self.track_collections = track_collections
        self.collection_filter = collection_filter
        self.paths: dict[str, str] = {}
        self.texts: dict[str, str] = {}
        self.line_lists: dict[str, str] = {}
        self.lists: dict[str, list[str]] = {}
        self.loop_values: dict[str, list[str]] = {}
        self.loop_texts: dict[str, str] = {}
        self.functions: dict[str, ast.FunctionDef] = {}
        self.active_functions: set[str] = set()
        self.findings: list[object] = []

    def visit_Assign(self, node: ast.Assign) -> None:
        names = [target.id for target in node.targets if isinstance(target, ast.Name)]
        values = self.literal_strings(node.value)
        source = self.read_text_source(node.value)
        line_source = self.read_text_lines_source(node.value)
        path_value = self.path_value(node.value)
        for name in names:
            if values is not None and self.track_collections:
                filtered_values = self.filter_collection_values(name, values)
                if filtered_values:
                    self.lists[name] = filtered_values
            if source is not None:
                self.texts[name] = source
            if line_source is not None:
                self.line_lists[name] = line_source
            if path_value is not None:
                self.paths[name] = path_value
        self.generic_visit(node)

    def visit_For(self, node: ast.For) -> None:
        line_source = self.iter_text_source(node.iter)
        if line_source is not None:
            previous_texts = self.bind_text_loop(node.target, line_source)
            for child in node.body:
                self.visit(child)
            self.restore_text_loop(previous_texts)
            for child in node.orelse:
                self.visit(child)
            return
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
        self._visit_comprehension_expr(node.generators, node.elt)

    def visit_GeneratorExp(self, node: ast.GeneratorExp) -> None:
        self._visit_comprehension_expr(node.generators, node.elt)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        self.functions[node.name] = node

    def _visit_comprehension_expr(
        self, generators: list[ast.comprehension], element: ast.AST
    ) -> None:
        previous: list[tuple[str, list[str] | None]] = []
        previous_texts: list[tuple[str, str | None]] = []
        for generator in generators:
            line_source = self.iter_text_source(generator.iter)
            if line_source is not None:
                previous_texts.extend(self.bind_text_loop(generator.target, line_source))
            values = self.iter_values(generator.iter)
            if values is not None:
                previous.extend(self.bind_loop(generator.target, values))
            for condition in generator.ifs:
                self.visit(condition)
        self.visit(element)
        self.restore_loop(previous)
        self.restore_text_loop(previous_texts)

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
            substring_predicate = self.substring_predicate(node)
            if substring_predicate is not None:
                assertion, predicate_patterns, predicate_target = substring_predicate
                for pattern in predicate_patterns:
                    self.record(node.lineno, assertion, pattern, predicate_target)
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call) -> None:
        if (
            isinstance(node.func, ast.Name)
            and node.func.id in self.functions
            and node.func.id not in self.active_functions
        ):
            self.visit_user_function_call(node, self.functions[node.func.id])
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

    def visit_user_function_call(self, node: ast.Call, function: ast.FunctionDef) -> None:
        previous_lists = dict(self.lists)
        previous_texts = dict(self.texts)
        previous_line_lists = dict(self.line_lists)
        previous_paths = dict(self.paths)
        self.active_functions.add(function.name)
        try:
            arguments_by_name = {
                parameter.arg: argument
                for parameter, argument in zip(function.args.args, node.args)
            }
            arguments_by_name.update(
                {
                    keyword.arg: keyword.value
                    for keyword in node.keywords
                    if keyword.arg is not None
                }
            )
            for name, argument in arguments_by_name.items():
                values = self.string_values(argument) or self.literal_strings(argument)
                text_source = self.text_source(argument) or self.read_text_source(argument)
                line_source = self.iter_text_source(argument) or self.read_text_lines_source(argument)
                path_value = self.path_value(argument)
                if values:
                    self.lists[name] = values
                if text_source:
                    self.texts[name] = text_source
                if line_source:
                    self.line_lists[name] = line_source
                if path_value:
                    self.paths[name] = path_value
            for child in function.body:
                self.visit(child)
        finally:
            self.active_functions.discard(function.name)
            self.lists = previous_lists
            self.texts = previous_texts
            self.line_lists = previous_line_lists
            self.paths = previous_paths

    def is_re_match_call(self, node: ast.Call) -> bool:
        return (
            isinstance(node.func, ast.Attribute)
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "re"
            and node.func.attr in {"search", "match"}
        )

    def substring_predicate(
        self, node: ast.Compare
    ) -> tuple[str, list[str], str] | None:
        call = node.left
        comparator = node.comparators[0]
        op = node.ops[0]
        if not (
            isinstance(call, ast.Call)
            and isinstance(call.func, ast.Attribute)
            and call.func.attr in {"find", "count"}
            and call.args
        ):
            if not (
                isinstance(comparator, ast.Call)
                and isinstance(comparator.func, ast.Attribute)
                and comparator.func.attr in {"find", "count"}
                and comparator.args
                and isinstance(call, ast.Constant)
                and isinstance(call.value, int)
            ):
                return None
            call, comparator = comparator, call
            op = self.reverse_compare_op(op)
        target = self.text_source(call.func.value)
        patterns = self.string_values(call.args[0])
        if not target or not patterns:
            return None
        if not isinstance(comparator, ast.Constant) or not isinstance(
            comparator.value, int
        ):
            return None
        threshold = comparator.value
        return self.substring_predicate_for_call(call, op, threshold, patterns, target)

    def reverse_compare_op(self, op: ast.cmpop) -> ast.cmpop:
        if isinstance(op, ast.Gt):
            return ast.Lt()
        if isinstance(op, ast.GtE):
            return ast.LtE()
        if isinstance(op, ast.Lt):
            return ast.Gt()
        if isinstance(op, ast.LtE):
            return ast.GtE()
        return op

    def substring_predicate_for_call(
        self,
        call: ast.Call,
        op: ast.cmpop,
        threshold: int,
        patterns: list[str],
        target: str,
    ) -> tuple[str, list[str], str] | None:
        if call.func.attr == "find":
            if isinstance(op, (ast.Gt, ast.GtE)) and threshold in {-1, 0}:
                return "present", patterns, target
            if isinstance(op, ast.NotEq) and threshold == -1:
                return "present", patterns, target
            if isinstance(op, ast.Eq) and threshold == -1:
                return "absent", patterns, target
            if isinstance(op, ast.Eq) and threshold == 0:
                return "present", patterns, target
            if isinstance(op, ast.Lt) and threshold == 0:
                return "absent", patterns, target
        if call.func.attr == "count":
            if isinstance(op, (ast.Gt, ast.GtE)) and threshold in {0, 1}:
                return "present", patterns, target
            if isinstance(op, ast.NotEq) and threshold == 0:
                return "present", patterns, target
            if isinstance(op, ast.Eq) and threshold == 0:
                return "absent", patterns, target
        return None

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

    def filter_collection_values(self, name: str, values: list[str]) -> list[str]:
        if self.collection_filter == "all":
            return values
        if self.collection_filter != "prose":
            return []
        if re.search(r"(phrase|term|pattern)s?$", name):
            return values
        return [value for value in values if collection_prose_literal(value)]

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
            return self.loop_values.get(node.id) or self.lists.get(node.id)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id in {"sorted", "list", "tuple", "set"} and node.args:
                return self.iter_values(node.args[0])
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            if node.func.attr in {"items", "values"} and isinstance(
                node.func.value, ast.Name
            ):
                return self.lists.get(node.func.value.id)
        return None

    def iter_text_source(self, node: ast.AST) -> str | None:
        if isinstance(node, ast.Name):
            return self.line_lists.get(node.id)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id == "enumerate" and node.args:
                return self.iter_text_source(node.args[0])
        return self.read_text_lines_source(node)

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

    def bind_text_loop(
        self, target: ast.AST, source: str
    ) -> list[tuple[str, str | None]]:
        names: list[str] = []
        if isinstance(target, ast.Name):
            names.append(target.id)
        elif isinstance(target, ast.Tuple):
            names.extend(item.id for item in target.elts if isinstance(item, ast.Name))
        previous = [(name, self.loop_texts.get(name)) for name in names]
        for name in names:
            self.loop_texts[name] = source
        return previous

    def restore_text_loop(self, previous: list[tuple[str, str | None]]) -> None:
        for name, source in previous:
            if source is None:
                self.loop_texts.pop(name, None)
            else:
                self.loop_texts[name] = source

    def read_text_source(self, node: ast.AST) -> str | None:
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            if node.func.attr == "read_text":
                return self.path_value(node.func.value)
        return None

    def read_text_lines_source(self, node: ast.AST) -> str | None:
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            if node.func.attr == "splitlines":
                return self.read_text_source(node.func.value) or self.text_source(
                    node.func.value
                )
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
            return self.loop_texts.get(node.id) or self.texts.get(node.id)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            return self.text_source(node.func.value)
        return None

    def string_values(self, node: ast.AST) -> list[str] | None:
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return [node.value]
        if isinstance(node, ast.Name):
            return self.loop_values.get(node.id) or self.lists.get(node.id)
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
    *,
    track_collections: bool = True,
    collection_filter: str = "all",
) -> list[object]:
    try:
        tree = ast.parse("\n".join(unit.body))
    except SyntaxError:
        return []
    visitor = PythonProseVisitor(
        unit.line,
        add_finding,
        python_argv(unit.command, assignments),
        track_collections=track_collections,
        collection_filter=collection_filter,
    )
    visitor.visit(tree)
    return visitor.findings


def python_file_findings(
    lines: list[str],
    add_finding: FindingFactory,
    *,
    line_offset: int = 1,
    track_collections: bool = True,
    collection_filter: str = "all",
) -> list[object]:
    try:
        tree = ast.parse("\n".join(lines))
    except SyntaxError:
        return []
    visitor = PythonProseVisitor(
        line_offset,
        add_finding,
        {},
        track_collections=track_collections,
        collection_filter=collection_filter,
    )
    visitor.visit(tree)
    return visitor.findings


def collection_prose_literal(value: str) -> bool:
    letters = re.findall(r"[A-Za-z一-鿿]", value)
    cjk_count = len(re.findall(r"[一-鿿]", value))
    return (
        len(letters) >= 45
        or cjk_count >= 18
        or bool(
            re.search(
                r"(正文|措辞|句子|原文|wording|prose|sentence|preserve|remain|exact|frozen)",
                value,
                re.IGNORECASE,
            )
        )
        or bool(re.search(r"决策方", value))
    )
