from __future__ import annotations

import binascii
import hashlib
import re
import struct
import unittest
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = (
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "assets"
    / "2026-08-03--one-human-agent-team-operating-architecture-l0"
)
SVG_PATH = ASSET_DIR / "one-human-agent-team-architecture-map.svg"
PNG_PATH = ASSET_DIR / "one-human-agent-team-architecture-map.png"
README_PATH = ASSET_DIR / "README.md"
CANONICAL_SPEC = (
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "2026-08-03--one-human-agent-team-operating-architecture-l0--design.md"
)
CANONICAL_POINTERS = (
    ROOT / "docs" / "product-dirrctor-session.md",
    ROOT
    / "docs"
    / "superpowers"
    / "plans"
    / "2026-07-30--one-human-agent-operating-architecture-visual-redesign.md",
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md",
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md",
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "2026-07-30--product-director-decision-case--design.md",
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "assets"
    / "2026-07-30--one-human-agent-team-operating-architecture-v1.2"
    / "README.md",
)

STAGES = (
    ("stage-product-definition", "1", "product-director", 130.0),
    ("stage-verification-planning", "2", "tech-lead", 472.0),
    ("stage-development-delivery", "3", "development-owner", 814.0),
    ("stage-independent-quality", "4", "quality-owner", 1156.0),
    ("stage-production-closeout", "5", "product-director", 1498.0),
)
LAYER_GEOMETRY = {
    "human-governance": ("governance-layer", "human-governance-layer", (60.0, 118.0, 1800.0, 164.0)),
    "agent-team": ("agent-team", "agent-team-container", (60.0, 302.0, 1800.0, 592.0)),
    "shared-foundation": (
        "cross-cutting-foundation",
        "shared-foundation-layer",
        (60.0, 914.0, 1800.0, 202.0),
    ),
    "accountable-return-safe-stop": (
        "return-stop-law",
        "return-stop-layer",
        (60.0, 1134.0, 1800.0, 46.0),
    ),
}
GATES = (
    ("test-deployment", "3-4", 1131.0, 1001.0),
    ("production-deployment", "4-5", 1473.0, 1343.0),
)
PROFESSIONAL_OWNERS = {
    "product-director",
    "product-manager",
    "impact-owner",
    "ux-owner",
    "architecture-owner",
    "test-design-owner",
    "tech-lead",
    "development-owner",
    "quality-owner",
    "delivery-assurance-owner",
}
EXECUTORS = {
    "developer",
    "verifier",
    "code-reviewer",
    "repair-capability",
    "qa-executor",
}
ROLE_STAGE_REQUIREMENTS = {
    "product-director": {"stage-product-definition", "stage-production-closeout"},
    "product-manager": {"stage-product-definition"},
    "impact-owner": {"stage-product-definition"},
    "ux-owner": {"stage-product-definition"},
    "architecture-owner": {"stage-product-definition"},
    "test-design-owner": {"stage-verification-planning"},
    "tech-lead": {"stage-verification-planning"},
    "development-owner": {"stage-development-delivery"},
    "developer": {"stage-development-delivery"},
    "verifier": {"stage-development-delivery"},
    "code-reviewer": {"stage-development-delivery"},
    "repair-capability": {"stage-development-delivery"},
    "quality-owner": {"stage-independent-quality", "stage-production-closeout"},
    "qa-executor": {"stage-independent-quality"},
}
FINAL_FACTS = {
    "production-verification": "quality-owner",
    "business-acceptance": "human",
    "product-director-recommendation": "product-director",
    "phase-demand-disposition": "human",
}
HUMAN_ACTIONS = {
    "human-co-creation",
    "human-route-authorization",
    "human-deployment-control",
    "human-business-disposition",
    "human-non-responsibilities",
}
FORWARD_FACTS = (
    ("forward-producer-go", "1"),
    ("forward-integrator-route", "2"),
    ("forward-human-authorize", "3"),
    ("forward-recipient-accept", "4"),
)
FOUNDATION_FACTS = {
    "delivery-control-record",
    "minimum-sufficient-context",
    "permission-context-isolation",
    "agent-workflow-evaluation",
}
RETURN_FACTS = (
    ("return-finding-custody", "1"),
    ("return-earliest-owner", "2"),
    ("return-corrective-accept", "3"),
    ("return-independent-reverify", "4"),
    ("return-safe-stop", "5"),
)
CONCEPT_VISIBLE_TOKENS = {
    "map-header": (
        "一人 + Agent Team 架构",
        "人掌握关键决策与外部动作",
        "M0 manual learning mode · not runtime-active",
    ),
    "human-governance": ("人类治理层", "业务最终责任与关键行动"),
    "human-co-creation": ("共创与裁决", "产品方向", "重大架构取舍"),
    "human-route-authorization": ("授权与触发", "审阅决策视图", "手动触发下一 Owner"),
    "human-deployment-control": ("部署控制", "授权、执行并如实记录", "测试 / 生产部署动作"),
    "human-business-disposition": ("业务终局", "业务验收", "Phase / Demand 最终处置"),
    "human-non-responsibilities": ("人不负责任务编排", "上下文拼装", "技术归因"),
    "forward-control-law": ("专业 Owner GO", "阶段整合者推荐下一 Owner", "接收方 ACCEPT"),
    "forward-producer-go": ("专业 Owner GO",),
    "forward-integrator-route": ("阶段整合者推荐下一 Owner", "准备视图"),
    "forward-human-authorize": ("人工 AUTHORIZE / 触发",),
    "forward-recipient-accept": ("接收方 ACCEPT",),
    "agent-team": ("一个可替换的 Agent Team", "5 个专业交付阶段", "不是 5 个 Team"),
    "stage-product-definition": ("01 产品定义收敛", "从模糊需求收敛", "产品定义就绪"),
    "stage-verification-planning": ("02 验证与计划", "证明方案", "验证与计划就绪"),
    "stage-development-delivery": ("03 开发交付", "TDD 实施", "可提测发布身份"),
    "stage-independent-quality": ("04 独立质量验收", "Quality 不修改代码", "独立质量结论"),
    "stage-production-closeout": ("05 生产验证与产品阶段决策", "真实业务结果", "产品阶段决策"),
    "product-definition-convergence": (
        "Product Director ↔ Product Manager ↔ Impact Owner",
        "按需 UX / Architecture",
    ),
    "proof-before-implementation-plan": ("先定义证明义务", "再形成实施与部署计划"),
    "specialist-accountability-rule": ("不得覆盖专业 Owner 结论",),
    "behavior-obligation-trace": (
        "目标行为 · 保留行为 · 禁止副作用",
        "证明设计",
        "独立质量",
        "生产验证",
    ),
    "test-deployment": ("人工测试部署边界", "Quality 核验实际身份", "未知 → 停止"),
    "production-deployment": ("人工生产部署边界", "部署 ≠ 生产验证 ≠ 业务成功", "未知 → 停止"),
    "shared-foundation": ("共享协调与保障底座", "不是第六阶段"),
    "delivery-control-record": ("交付控制记录", "当前阶段与 Owner", "证据有效性", "回流目标"),
    "minimum-sufficient-context": ("最小充分上下文", "Owner 权威成果", "接收方视图", "接收校验"),
    "permission-context-isolation": ("权限与独立性", "最小权限", "独立角色使用新上下文"),
    "agent-workflow-evaluation": ("Delivery Assurance Owner", "独立检查路由", "安全停止"),
    "accountable-return-safe-stop": ("最早的具体责任 Owner 接责", "安全停止并升级", "不得伪装成功"),
    "return-finding-custody": ("保留证据",),
    "return-earliest-owner": ("最早的具体责任 Owner 接责",),
    "return-corrective-accept": ("修正后",),
    "return-independent-reverify": ("原独立方复验",),
    "return-safe-stop": ("安全停止并升级", "不得伪装成功"),
    "production-verification": ("Quality Owner", "生产验证事实"),
    "business-acceptance": ("Human", "业务验收"),
    "product-director-recommendation": ("Product Director", "收口建议"),
    "phase-demand-disposition": ("Human", "Phase / Demand 最终处置"),
}
KIND_MANIFEST = {
    "governance-layer": {"human-governance"},
    "agent-team": {"agent-team"},
    "delivery-stage": {concept for concept, _, _, _ in STAGES},
    "deployment-boundary": {name for name, _, _, _ in GATES},
    "cross-cutting-foundation": {"shared-foundation"},
    "return-stop-law": {"accountable-return-safe-stop"},
}
ROLE_INSTANCE_VISIBLE_TOKENS = {
    ("product-director", "stage-product-definition"): ("Product Director", "产品定义整合"),
    ("product-director", "stage-production-closeout"): ("Product Director", "产品收口整合"),
    ("product-manager", "stage-product-definition"): ("Product Manager", "业务流程与产品行为"),
    ("impact-owner", "stage-product-definition"): ("Impact Owner", "影响与保留义务"),
    ("ux-owner", "stage-product-definition"): ("UX Owner", "按需"),
    ("architecture-owner", "stage-product-definition"): ("Architecture Owner", "按需"),
    ("test-design-owner", "stage-verification-planning"): ("Test Design Owner", "先定义证明义务"),
    ("tech-lead", "stage-verification-planning"): ("Tech Lead", "验证与计划整合"),
    ("development-owner", "stage-development-delivery"): ("Development Owner", "开发交付整合"),
    ("developer", "stage-development-delivery"): ("Developer",),
    ("verifier", "stage-development-delivery"): ("Verifier",),
    ("code-reviewer", "stage-development-delivery"): ("Code Reviewer",),
    ("repair-capability", "stage-development-delivery"): ("修复能力", "开发域内"),
    ("quality-owner", "stage-independent-quality"): ("Quality Owner", "质量验收整合"),
    ("quality-owner", "stage-production-closeout"): ("Quality Owner", "生产验证事实"),
    ("qa-executor", "stage-independent-quality"): ("QA Executor",),
    ("delivery-assurance-owner", None): ("Delivery Assurance Owner", "横向交付保障"),
}
FORBIDDEN_VISIBLE_PATTERNS = (
    re.compile(r"\b(?:F|R|IR)[-_]?\d+\b", re.IGNORECASE),
    re.compile(r"\b(?:flow|route)[-_ ]?(?:id|\d+|[A-Z])\b", re.IGNORECASE),
)
FORBIDDEN_CANONICAL_PATTERNS = (
    re.compile(r"(?:f|r|ir)\d+", re.IGNORECASE),
    re.compile(r"(?:flow|route)id", re.IGNORECASE),
)
FORBIDDEN_CANONICAL_FRAGMENTS = {
    "taskpacket",
    "schema",
    "statemachine",
    "findingtype",
    "retry",
    "incident",
    "automation",
    "prompt",
    "token",
    "persistence",
    "dependencyalgorithm",
    "deploymentcommand",
    "providerspecific",
    "providerbehavior",
    "ownerprocedure",
    "skillinstruction",
    "runtimeorchestration",
    "flowid",
    "routeid",
    "codex",
    "claude",
    "portfolio",
    "roadmap",
    "activationchecklist",
    "budget",
    "runbook",
    "fieldname",
    "任务包",
    "字段结构",
    "字段名",
    "状态机",
    "缺陷类型",
    "重试",
    "事故子流程",
    "自动编排",
    "提示词",
    "持久化",
    "依赖算法",
    "部署命令",
    "供应商特定",
    "供应商行为",
    "角色内部流程",
    "运行时编排",
    "流程编号",
    "路由编号",
    "组合规划",
    "路线图",
    "激活清单",
    "预算",
    "恢复手册",
    "qfttenants",
    "全局协调器",
    "端到端协调器",
}


def local_name(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def numeric(element: ET.Element, attribute: str) -> float:
    return float(element.attrib[attribute])


def compact_text(value: str) -> str:
    return re.sub(r"\s+", "", value)


def canonical_forbidden_text(value: str) -> str:
    return "".join(character.casefold() for character in value if character.isalnum())


def style_properties(element: ET.Element) -> dict[str, str]:
    properties = {}
    for declaration in element.attrib.get("style", "").split(";"):
        if ":" in declaration:
            name, value = declaration.split(":", 1)
            properties[name.strip().lower()] = value.strip()
    return properties


def parse_number(value: str) -> float:
    match = re.fullmatch(r"-?(?:\d+(?:\.\d+)?|\.\d+)", value.strip())
    if match is None:
        raise AssertionError(f"expected unitless numeric SVG value, got {value!r}")
    return float(value)


def markdown_targets(source: Path) -> list[Path]:
    targets = []
    for raw_target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", source.read_text(encoding="utf-8")):
        destination = raw_target.strip().strip("<>").split("#", 1)[0]
        if (
            not destination
            or destination.startswith("/")
            or re.match(r"^[a-z][a-z0-9+.-]*:", destination, re.IGNORECASE)
        ):
            continue
        target = (source.parent / destination).resolve()
        if not target.is_relative_to(ROOT.resolve()):
            continue
        targets.append(target)
    return targets


class OneHumanAgentTeamArchitectureMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not SVG_PATH.is_file():
            raise AssertionError(f"missing canonical SVG projection: {SVG_PATH}")
        cls.tree = ET.parse(SVG_PATH)
        cls.root = cls.tree.getroot()
        cls.elements = list(cls.root.iter())
        cls.source_text = SVG_PATH.read_text(encoding="utf-8")
        cls.parent = {
            child: parent for parent in cls.elements for child in list(parent)
        }

    @classmethod
    def concept(cls, name: str) -> ET.Element:
        matches = [
            element
            for element in cls.elements
            if element.attrib.get("data-concept") == name
        ]
        if len(matches) != 1:
            raise AssertionError(f"expected one concept {name!r}, found {len(matches)}")
        return matches[0]

    @classmethod
    def is_inside(cls, node: ET.Element, ancestor: ET.Element) -> bool:
        parent = cls.parent.get(node)
        while parent is not None:
            if parent is ancestor:
                return True
            parent = cls.parent.get(parent)
        return False

    @classmethod
    def stage_ancestor(cls, node: ET.Element) -> str | None:
        parent = cls.parent.get(node)
        while parent is not None:
            if parent.attrib.get("data-kind") == "delivery-stage":
                return parent.attrib.get("data-concept")
            parent = cls.parent.get(parent)
        return None

    @classmethod
    def ancestors_inclusive(cls, node: ET.Element) -> list[ET.Element]:
        result = [node]
        parent = cls.parent.get(node)
        while parent is not None:
            result.append(parent)
            parent = cls.parent.get(parent)
        return result

    @classmethod
    def property_value(cls, node: ET.Element, name: str) -> str | None:
        for current in cls.ancestors_inclusive(node):
            inline = style_properties(current)
            if name in inline:
                return inline[name]
            if name in current.attrib:
                return current.attrib[name]
        return None

    @classmethod
    def is_structurally_visible(cls, node: ET.Element) -> bool:
        for current in cls.ancestors_inclusive(node):
            if local_name(current) == "defs":
                return False
            display = style_properties(current).get("display", current.attrib.get("display", ""))
            visibility = style_properties(current).get(
                "visibility", current.attrib.get("visibility", "")
            )
            if display.strip().lower() == "none":
                return False
            if visibility.strip().lower() in {"hidden", "collapse"}:
                return False
            for name in ("opacity", "fill-opacity", "stroke-opacity"):
                value = style_properties(current).get(name, current.attrib.get(name))
                if value is not None and parse_number(value) <= 0.0:
                    return False
        return True

    @classmethod
    def is_renderable_text(cls, node: ET.Element) -> bool:
        if local_name(node) != "text" or not cls.is_structurally_visible(node):
            return False
        if not "".join(node.itertext()).strip():
            return False
        required = {name: node.attrib.get(name) for name in ("x", "y", "font-size", "fill")}
        if any(value is None for value in required.values()):
            return False
        x = parse_number(required["x"] or "")
        y = parse_number(required["y"] or "")
        font_size = parse_number(required["font-size"] or "")
        fill = (required["fill"] or "").strip().lower()
        return 0.0 <= x <= 1920.0 and 0.0 <= y <= 1200.0 and font_size >= 14.0 and fill not in {
            "none",
            "transparent",
        }

    @classmethod
    def drawable_points(cls, node: ET.Element) -> list[tuple[float, float]]:
        name = local_name(node)
        if name == "rect":
            x, y, width, height = (numeric(node, key) for key in ("x", "y", "width", "height"))
            if width <= 0.0 or height <= 0.0:
                return []
            return [(x, y), (x + width, y + height)]
        if name == "line":
            return [
                (numeric(node, "x1"), numeric(node, "y1")),
                (numeric(node, "x2"), numeric(node, "y2")),
            ]
        if name == "circle":
            cx, cy, radius = numeric(node, "cx"), numeric(node, "cy"), numeric(node, "r")
            return [] if radius <= 0.0 else [(cx - radius, cy - radius), (cx + radius, cy + radius)]
        if name in {"path", "polyline"}:
            source = node.attrib.get("d", "") if name == "path" else node.attrib.get("points", "")
            numbers = [float(value) for value in re.findall(r"-?(?:\d+(?:\.\d+)?|\.\d+)", source)]
            return list(zip(numbers[0::2], numbers[1::2])) if len(numbers) >= 4 and len(numbers) % 2 == 0 else []
        return []

    @classmethod
    def is_renderable_drawable(cls, node: ET.Element) -> bool:
        if local_name(node) not in {"rect", "path", "line", "polyline", "circle"}:
            return False
        if not cls.is_structurally_visible(node):
            return False
        fill = (cls.property_value(node, "fill") or "").strip().lower()
        stroke = (cls.property_value(node, "stroke") or "").strip().lower()
        if fill in {"", "none", "transparent"} and stroke in {"", "none", "transparent"}:
            return False
        points = cls.drawable_points(node)
        if len(points) < 2 or len(set(points)) < 2:
            return False
        return all(0.0 <= x <= 1920.0 and 0.0 <= y <= 1200.0 for x, y in points)

    def rendered_text(self, element: ET.Element) -> str:
        return " ".join(
            " ".join("".join(node.itertext()).split())
            for node in element.iter()
            if self.is_renderable_text(node)
        )

    def assert_visible_tokens(
        self,
        element: ET.Element,
        tokens: tuple[str, ...],
        label: str,
    ) -> None:
        visible = compact_text(self.rendered_text(element))
        for token in tokens:
            self.assertIn(compact_text(token), visible, f"{label} missing visible token {token!r}")

    def assert_rendered_group(
        self,
        element: ET.Element,
        label: str,
        tokens: tuple[str, ...] = (),
    ) -> None:
        self.assertEqual(local_name(element), "g", label)
        self.assertTrue(self.is_structurally_visible(element), label)
        self.assertTrue(
            any(self.is_renderable_text(node) for node in element.iter()),
            f"{label} needs renderable text",
        )
        self.assertTrue(
            any(self.is_renderable_drawable(node) for node in element.iter()),
            f"{label} needs a painted, non-zero, on-canvas drawable",
        )
        self.assert_visible_tokens(element, tokens, label)

    def visual_rect(self, group: ET.Element, marker: str) -> tuple[float, float, float, float]:
        matches = [
            node
            for node in group.iter()
            if local_name(node) == "rect" and node.attrib.get("data-visual") == marker
        ]
        self.assertEqual(len(matches), 1, marker)
        rect = matches[0]
        self.assertTrue(self.is_renderable_drawable(rect), marker)
        return tuple(numeric(rect, key) for key in ("x", "y", "width", "height"))

    def visible_text(self) -> str:
        return self.rendered_text(self.root)

    def assert_inside_rect(
        self,
        geometry: tuple[float, float, float, float],
        container: tuple[float, float, float, float],
        label: str,
    ) -> None:
        x, y, width, height = geometry
        cx, cy, cwidth, cheight = container
        self.assertGreater(width, 0.0, label)
        self.assertGreater(height, 0.0, label)
        self.assertGreaterEqual(x, cx, label)
        self.assertGreaterEqual(y, cy, label)
        self.assertLessEqual(x + width, cx + cwidth, label)
        self.assertLessEqual(y + height, cy + cheight, label)

    def assert_horizontal_non_overlap(
        self,
        geometries: list[tuple[float, float, float, float]],
        container: tuple[float, float, float, float],
        label: str,
    ) -> None:
        for geometry in geometries:
            self.assert_inside_rect(geometry, container, label)
        for left, right in zip(geometries, geometries[1:]):
            self.assertLessEqual(left[0] + left[2] + 4.0, right[0], label)

    @staticmethod
    def rectangles_overlap(
        left: tuple[float, float, float, float],
        right: tuple[float, float, float, float],
    ) -> bool:
        lx, ly, lw, lh = left
        rx, ry, rw, rh = right
        return not (
            lx + lw <= rx or rx + rw <= lx or ly + lh <= ry or ry + rh <= ly
        )

    def test_root_declares_exact_baseline_and_fixed_canvas(self) -> None:
        self.assertEqual(self.root.attrib.get("data-architecture"), "one-human-agent-team")
        self.assertEqual(self.root.attrib.get("data-baseline"), "L0-R3")
        self.assertEqual(
            self.root.attrib.get("data-status"),
            "m0-manual-not-runtime-active",
        )
        self.assertEqual(self.root.attrib.get("viewBox"), "0 0 1920 1200")
        self.assertEqual(self.root.attrib.get("width"), "1920")
        self.assertEqual(self.root.attrib.get("height"), "1200")
        self.assertRegex(self.root.attrib.get("data-png-sha256", ""), r"^[0-9a-f]{64}$")
        header = self.concept("map-header")
        self.assertIs(self.parent.get(header), self.root)
        self.assert_rendered_group(header, "map-header", CONCEPT_VISIBLE_TOKENS["map-header"])

    def test_semantic_markers_are_rendered_and_not_hidden(self) -> None:
        forbidden_elements = {
            "a",
            "foreignObject",
            "image",
            "script",
            "use",
            "switch",
            "clipPath",
            "mask",
            "filter",
            "feImage",
        }
        self.assertFalse(any(local_name(element) in forbidden_elements for element in self.elements))
        self.assertFalse(any("transform" in element.attrib for element in self.elements))
        source_casefold = self.source_text.casefold()
        for forbidden_declaration in ("<?xml-stylesheet", "<!doctype", "<!entity"):
            self.assertNotIn(forbidden_declaration, source_casefold)
        style_source = " ".join(
            "".join(element.itertext())
            for element in self.elements
            if local_name(element) == "style"
        ).casefold()
        for external_css in ("@import", "@font-face", "http://", "https://", "data:", "file:"):
            self.assertNotIn(external_css, style_source)
        for reference in re.findall(r"url\(([^)]+)\)", style_source, re.IGNORECASE):
            self.assertTrue(reference.strip(" '\"").startswith("#"), reference)
        normalized_style = re.sub(r"\s+", "", style_source)
        for concealed_css in (
            "display:none",
            "visibility:hidden",
            "visibility:collapse",
            "opacity:0",
            "fill-opacity:0",
            "stroke-opacity:0",
            "font-size:0",
            "clip-path:",
            "mask:",
            "filter:",
        ):
            self.assertNotIn(concealed_css, normalized_style)

        for element in self.elements:
            for attribute, value in element.attrib.items():
                attribute_name = attribute.rsplit("}", 1)[-1].lower()
                self.assertFalse(attribute_name.startswith("on"), attribute_name)
                if attribute_name == "href":
                    self.assertTrue(value.startswith("#"), value)
                for reference in re.findall(r"url\(([^)]+)\)", value, re.IGNORECASE):
                    self.assertTrue(reference.strip(" '\"").startswith("#"), reference)
            if local_name(element) == "text":
                self.assertTrue(self.is_renderable_text(element), ET.tostring(element, encoding="unicode"))

        concepts = [
            element.attrib["data-concept"]
            for element in self.elements
            if "data-concept" in element.attrib
        ]
        self.assertEqual(len(concepts), len(CONCEPT_VISIBLE_TOKENS))
        self.assertEqual(set(concepts), set(CONCEPT_VISIBLE_TOKENS))
        for concept, tokens in CONCEPT_VISIBLE_TOKENS.items():
            self.assert_rendered_group(self.concept(concept), concept, tokens)

        kinds: dict[str, set[str | None]] = {}
        for element in self.elements:
            if "data-kind" in element.attrib:
                kinds.setdefault(element.attrib["data-kind"], set()).add(
                    element.attrib.get("data-concept")
                )
        self.assertEqual(kinds, KIND_MANIFEST)

    def test_layers_stages_and_gates_use_the_real_left_to_right_geometry(self) -> None:
        for concept, (kind, visual, expected_geometry) in LAYER_GEOMETRY.items():
            group = self.concept(concept)
            self.assertEqual(group.attrib.get("data-kind"), kind)
            self.assertIs(self.parent.get(group), self.root, concept)
            self.assertEqual(self.visual_rect(group, visual), expected_geometry)

        agent_team = self.concept("agent-team")
        teams = [
            element
            for element in self.elements
            if element.attrib.get("data-kind") == "agent-team"
        ]
        self.assertEqual(len(teams), 1)

        delivery_stages = [
            element
            for element in self.elements
            if element.attrib.get("data-kind") == "delivery-stage"
        ]
        self.assertEqual(len(delivery_stages), 5)
        self.assertEqual(
            {element.attrib.get("data-concept") for element in delivery_stages},
            {concept for concept, _, _, _ in STAGES},
        )

        stage_x_positions = []
        for concept, order, integrator, expected_x in STAGES:
            stage = self.concept(concept)
            self.assertEqual(stage.attrib.get("data-kind"), "delivery-stage")
            self.assertEqual(stage.attrib.get("data-order"), order)
            self.assertEqual(stage.attrib.get("data-integrator"), integrator)
            self.assertIs(self.parent.get(stage), agent_team, concept)
            geometry = self.visual_rect(stage, "stage-card")
            self.assertEqual(geometry, (expected_x, 378.0, 292.0, 438.0))
            stage_x_positions.append(geometry[0])
        self.assertEqual(stage_x_positions, sorted(stage_x_positions))
        self.assertEqual(len(set(stage_x_positions)), 5)

        stage_geometries = {
            concept: self.visual_rect(self.concept(concept), "stage-card")
            for concept, _, _, _ in STAGES
        }
        for name, between, line_x, callout_x in GATES:
            boundary = self.concept(name)
            self.assertEqual(boundary.attrib.get("data-kind"), "deployment-boundary")
            self.assertEqual(boundary.attrib.get("data-controlled-by"), "human")
            self.assertEqual(boundary.attrib.get("data-between"), between)
            self.assertIs(self.parent.get(boundary), agent_team, name)
            gate_lines = [
                node
                for node in boundary.iter()
                if local_name(node) == "line" and node.attrib.get("data-visual") == "deployment-gate"
            ]
            self.assertEqual(len(gate_lines), 1, name)
            self.assertEqual(numeric(gate_lines[0], "x1"), line_x)
            self.assertEqual(numeric(gate_lines[0], "x2"), line_x)
            self.assertEqual(
                self.visual_rect(boundary, "deployment-callout"),
                (callout_x, 310.0, 260.0, 60.0),
            )
        self.assertLess(
            stage_geometries["stage-development-delivery"][0] + 292.0,
            1131.0,
        )
        self.assertLess(1131.0, stage_geometries["stage-independent-quality"][0])
        self.assertLess(
            stage_geometries["stage-independent-quality"][0] + 292.0,
            1473.0,
        )
        self.assertLess(1473.0, stage_geometries["stage-production-closeout"][0])

    def test_role_types_conditions_and_assurance_placement_are_explicit(self) -> None:
        by_role: dict[str, list[ET.Element]] = {}
        for element in self.elements:
            role_id = element.attrib.get("data-role-id")
            if role_id:
                by_role.setdefault(role_id, []).append(element)

        self.assertEqual(set(by_role), PROFESSIONAL_OWNERS | EXECUTORS)
        for role_id, stage_concepts in ROLE_STAGE_REQUIREMENTS.items():
            nodes = by_role[role_id]
            expected_type = "professional-owner" if role_id in PROFESSIONAL_OWNERS else "executor"
            self.assertEqual(len(nodes), len(stage_concepts), role_id)
            self.assertTrue(all(node.attrib.get("data-role-type") == expected_type for node in nodes))
            self.assertEqual({self.stage_ancestor(node) for node in nodes}, stage_concepts)
            for node in nodes:
                stage_concept = self.stage_ancestor(node)
                self.assert_rendered_group(
                    node,
                    f"{role_id}@{stage_concept}",
                    ROLE_INSTANCE_VISIBLE_TOKENS[(role_id, stage_concept)],
                )
        for role_id in ("ux-owner", "architecture-owner"):
            self.assertEqual(by_role[role_id][0].attrib.get("data-activation"), "conditional")

        self.assertEqual(len(by_role["delivery-assurance-owner"]), 1)
        assurance = by_role["delivery-assurance-owner"][0]
        self.assertEqual(assurance.attrib.get("data-role-type"), "professional-owner")
        self.assertEqual(assurance.attrib.get("data-placement"), "cross-cutting")
        self.assertEqual(assurance.attrib.get("data-team-membership"), "agent-team")
        self.assertIsNone(self.stage_ancestor(assurance))
        self.assertTrue(self.is_inside(assurance, self.concept("shared-foundation")))
        self.assert_rendered_group(
            assurance,
            "delivery-assurance-owner",
            ROLE_INSTANCE_VISIBLE_TOKENS[("delivery-assurance-owner", None)],
        )

    def test_forward_convergence_foundation_return_and_final_facts_remain_distinct(self) -> None:
        human = self.concept("human-governance")
        for concept in HUMAN_ACTIONS:
            self.assertTrue(self.is_inside(self.concept(concept), human), concept)
        forward = self.concept("forward-control-law")
        self.assertTrue(self.is_inside(forward, human))
        forward_geometries = []
        for concept, order in FORWARD_FACTS:
            fact = self.concept(concept)
            self.assertTrue(self.is_inside(fact, forward), concept)
            self.assertEqual(fact.attrib.get("data-order"), order)
            forward_geometries.append(self.visual_rect(fact, "forward-fact"))
        self.assert_horizontal_non_overlap(
            forward_geometries,
            LAYER_GEOMETRY["human-governance"][2],
            "forward facts",
        )

        stage_one = self.concept("stage-product-definition")
        convergence = self.concept("product-definition-convergence")
        self.assertEqual(convergence.attrib.get("data-flow"), "iterative")
        self.assertTrue(self.is_inside(convergence, stage_one))
        convergence_paths = {
            node.attrib["data-relation"]: node
            for node in convergence.iter()
            if local_name(node) == "path" and node.attrib.get("data-relation")
        }
        self.assertEqual(set(convergence_paths), {"reopen-forward", "reopen-return"})
        self.assertEqual(
            len(
                [
                    node
                    for node in convergence.iter()
                    if local_name(node) == "path" and node.attrib.get("data-relation")
                ]
            ),
            2,
        )
        convergence_endpoints = {}
        stage_one_geometry = self.visual_rect(stage_one, "stage-card")
        for relation, path in convergence_paths.items():
            self.assertTrue(self.is_renderable_drawable(path), relation)
            points = self.drawable_points(path)
            self.assertGreaterEqual(len(points), 2, relation)
            self.assertNotEqual(points[0], points[-1], relation)
            for point in points:
                self.assert_inside_rect((point[0], point[1], 0.1, 0.1), stage_one_geometry, relation)
            convergence_endpoints[relation] = (points[0], points[-1])
        forward_start, forward_end = convergence_endpoints["reopen-forward"]
        return_start, return_end = convergence_endpoints["reopen-return"]
        self.assertLess(forward_start[0], forward_end[0])
        self.assertGreater(return_start[0], return_end[0])
        self.assertGreaterEqual(
            min(abs(forward_start[1] - return_start[1]), abs(forward_end[1] - return_end[1])),
            8.0,
        )
        self.assertTrue(
            self.is_inside(self.concept("proof-before-implementation-plan"), self.concept("stage-verification-planning"))
        )
        agent_team = self.concept("agent-team")
        self.assertTrue(self.is_inside(self.concept("specialist-accountability-rule"), agent_team))
        self.assertTrue(self.is_inside(self.concept("behavior-obligation-trace"), agent_team))

        foundation = self.concept("shared-foundation")
        for concept in FOUNDATION_FACTS:
            self.assertTrue(self.is_inside(self.concept(concept), foundation), concept)

        return_law = self.concept("accountable-return-safe-stop")
        return_geometries = []
        for concept, order in RETURN_FACTS:
            fact = self.concept(concept)
            self.assertTrue(self.is_inside(fact, return_law), concept)
            self.assertEqual(fact.attrib.get("data-order"), order)
            return_geometries.append(self.visual_rect(fact, "return-fact"))
        self.assert_horizontal_non_overlap(
            return_geometries,
            LAYER_GEOMETRY["accountable-return-safe-stop"][2],
            "return facts",
        )

        stage_five = self.concept("stage-production-closeout")
        stage_five_geometry = self.visual_rect(stage_five, "stage-card")
        final_geometries = []
        for concept, owner in FINAL_FACTS.items():
            fact = self.concept(concept)
            self.assertTrue(self.is_inside(fact, stage_five), concept)
            self.assertEqual(fact.attrib.get("data-owner"), owner)
            geometry = self.visual_rect(fact, "final-fact")
            self.assert_inside_rect(geometry, stage_five_geometry, concept)
            final_geometries.append(geometry)
        self.assertEqual(len({(geometry[2], geometry[3]) for geometry in final_geometries}), 1)
        for index, left in enumerate(final_geometries):
            for right in final_geometries[index + 1 :]:
                self.assertFalse(self.rectangles_overlap(left, right), "final facts overlap")

    def test_svg_is_self_contained_and_excludes_deferred_detail(self) -> None:
        visible_text = self.visible_text()
        self.assertIn("M0 manual learning mode · not runtime-active", visible_text)
        for pattern in FORBIDDEN_VISIBLE_PATTERNS:
            self.assertIsNone(pattern.search(visible_text), pattern.pattern)
        forbidden_text = canonical_forbidden_text(visible_text)
        for pattern in FORBIDDEN_CANONICAL_PATTERNS:
            self.assertIsNone(pattern.search(forbidden_text), pattern.pattern)
        for fragment in FORBIDDEN_CANONICAL_FRAGMENTS:
            self.assertNotIn(fragment.casefold(), forbidden_text, fragment)

    def test_png_is_complete_decodable_and_bound_to_the_svg(self) -> None:
        payload = PNG_PATH.read_bytes()
        self.assertEqual(payload[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(hashlib.sha256(payload).hexdigest(), self.root.attrib["data-png-sha256"])

        offset = 8
        chunks: list[tuple[bytes, bytes]] = []
        while offset < len(payload):
            self.assertGreaterEqual(len(payload) - offset, 12)
            length = struct.unpack(">I", payload[offset : offset + 4])[0]
            chunk_type = payload[offset + 4 : offset + 8]
            chunk_end = offset + 12 + length
            self.assertLessEqual(chunk_end, len(payload))
            chunk_data = payload[offset + 8 : offset + 8 + length]
            recorded_crc = struct.unpack(">I", payload[offset + 8 + length : chunk_end])[0]
            calculated_crc = binascii.crc32(chunk_type + chunk_data) & 0xFFFFFFFF
            self.assertEqual(recorded_crc, calculated_crc, chunk_type)
            chunks.append((chunk_type, chunk_data))
            offset = chunk_end
            if chunk_type == b"IEND":
                break

        self.assertEqual(offset, len(payload))
        self.assertEqual(chunks[0][0], b"IHDR")
        self.assertEqual(chunks[-1], (b"IEND", b""))
        ihdr = chunks[0][1]
        self.assertEqual(len(ihdr), 13)
        width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
            ">IIBBBBB", ihdr
        )
        self.assertEqual((width, height), (1920, 1200))
        self.assertEqual(bit_depth, 8)
        self.assertIn(color_type, {2, 6})
        self.assertEqual((compression, filtering, interlace), (0, 0, 0))
        compressed = b"".join(data for chunk_type, data in chunks if chunk_type == b"IDAT")
        self.assertTrue(compressed)
        decoded = zlib.decompress(compressed)
        channels = {2: 3, 6: 4}[color_type]
        self.assertEqual(len(decoded), height * (1 + width * channels))

    def test_canonical_and_historical_links_resolve_without_a_second_semantic_source(self) -> None:
        canonical = CANONICAL_SPEC.resolve()
        self.assertTrue(CANONICAL_SPEC.is_file())
        self.assertFalse(CANONICAL_SPEC.is_symlink())
        for pointer in CANONICAL_POINTERS:
            self.assertTrue(pointer.is_file(), pointer)
            self.assertFalse(pointer.is_symlink(), pointer)
            self.assertIn(canonical, markdown_targets(pointer), pointer)

        if "Projection status: `APPROVED" not in README_PATH.read_text(encoding="utf-8"):
            return
        canonical_targets = markdown_targets(CANONICAL_SPEC)
        for asset in (SVG_PATH, PNG_PATH):
            self.assertTrue(asset.is_file(), asset)
            self.assertFalse(asset.is_symlink(), asset)
            self.assertIn(asset.resolve(), canonical_targets, asset)


if __name__ == "__main__":
    unittest.main(verbosity=2)
