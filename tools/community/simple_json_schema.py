#!/usr/bin/env python3
"""Small JSON Schema validator for installed standard-chain runtimes."""

from __future__ import annotations

import re
from datetime import datetime


class SimpleValidationError(ValueError):
    """Raised when a canonical artifact violates the bundled schema subset."""


class SimpleSchemaValidator:
    """Validate the JSON Schema subset used by standard-chain canonical schemas."""

    def __init__(self, schemas: dict[str, dict]):
        self.schemas = schemas

    def validate(self, instance: object, schema: dict) -> None:
        root_id = str(schema.get("$id", ""))
        self._validate(instance, schema, "$", root_id)

    def _validate(self, instance: object, schema: dict, path: str, root_id: str) -> None:
        if "$ref" in schema:
            target, target_root_id = self._resolve_ref(str(schema["$ref"]), root_id)
            self._validate(instance, target, path, target_root_id)
        for subschema in schema.get("allOf", []):
            self._validate(instance, subschema, path, root_id)
        if "anyOf" in schema:
            options = schema["anyOf"]
            if not isinstance(options, list) or not options:
                raise SimpleValidationError(f"{path}: anyOf must contain at least one schema")
            if not any(self._matches(instance, subschema, path, root_id) for subschema in options):
                raise SimpleValidationError(f"{path}: does not match anyOf")
        if "not" in schema and self._matches(instance, schema["not"], path, root_id):
            raise SimpleValidationError(f"{path}: matches forbidden schema")
        if "if" in schema and self._matches(instance, schema["if"], path, root_id):
            self._validate(instance, schema.get("then", {}), path, root_id)
        if "const" in schema and instance != schema["const"]:
            raise SimpleValidationError(f"{path}: expected const {schema['const']!r}")
        if "enum" in schema and instance not in schema["enum"]:
            raise SimpleValidationError(f"{path}: value not in enum")
        if "type" in schema:
            self._validate_type(instance, schema["type"], path)
        if isinstance(instance, dict):
            self._validate_object(instance, schema, path, root_id)
        if isinstance(instance, list):
            self._validate_array(instance, schema, path, root_id)
        if isinstance(instance, str):
            self._validate_string(instance, schema, path)
        if isinstance(instance, (int, float)) and not isinstance(instance, bool):
            self._validate_number(instance, schema, path)

    def _matches(self, instance: object, schema: dict, path: str, root_id: str) -> bool:
        try:
            self._validate(instance, schema, path, root_id)
        except SimpleValidationError:
            return False
        return True

    def _resolve_ref(self, ref: str, root_id: str) -> tuple[dict, str]:
        base, _, pointer = ref.partition("#")
        if not base:
            base = root_id
        if base not in self.schemas:
            raise SimpleValidationError(f"unknown schema ref: {ref}")
        target: object = self.schemas[base]
        if pointer:
            for token in pointer.strip("/").split("/"):
                if not token:
                    continue
                token = _decode_pointer_token(token)
                if isinstance(target, dict) and token in target:
                    target = target[token]
                elif isinstance(target, list) and token.isdigit() and int(token) < len(target):
                    target = target[int(token)]
                else:
                    raise SimpleValidationError(f"unknown schema pointer: {ref}")
        if not isinstance(target, dict):
            raise SimpleValidationError(f"schema ref is not an object: {ref}")
        return target, base

    def _validate_type(self, instance: object, expected: object, path: str) -> None:
        allowed = expected if isinstance(expected, list) else [expected]
        checks = {
            "object": lambda value: isinstance(value, dict),
            "array": lambda value: isinstance(value, list),
            "string": lambda value: isinstance(value, str),
            "integer": lambda value: isinstance(value, int) and not isinstance(value, bool),
            "number": lambda value: isinstance(value, (int, float)) and not isinstance(value, bool),
            "boolean": lambda value: isinstance(value, bool),
        }
        if not any(checks[name](instance) for name in allowed if name in checks):
            raise SimpleValidationError(f"{path}: expected type {expected}")

    def _validate_object(self, instance: dict, schema: dict, path: str, root_id: str) -> None:
        for field in schema.get("required", []):
            if field not in instance:
                raise SimpleValidationError(f"{path}: missing required field {field}")
        properties = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        extra = sorted(set(instance) - set(properties))
        if additional is False:
            if extra:
                raise SimpleValidationError(f"{path}: extra fields {extra}")
        elif isinstance(additional, dict):
            for field in extra:
                self._validate(instance[field], additional, f"{path}.{field}", root_id)
        for field, subschema in properties.items():
            if field in instance:
                self._validate(instance[field], subschema, f"{path}.{field}", root_id)

    def _validate_array(self, instance: list, schema: dict, path: str, root_id: str) -> None:
        if len(instance) < int(schema.get("minItems", 0)):
            raise SimpleValidationError(f"{path}: fewer items than minItems")
        if "maxItems" in schema and len(instance) > int(schema["maxItems"]):
            raise SimpleValidationError(f"{path}: more items than maxItems")
        if schema.get("uniqueItems") is True:
            seen = set()
            for item in instance:
                marker = repr(item)
                if marker in seen:
                    raise SimpleValidationError(f"{path}: duplicate array item")
                seen.add(marker)
        contains_schema = schema.get("contains")
        if isinstance(contains_schema, dict):
            match_count = sum(
                1
                for index, item in enumerate(instance)
                if self._matches(item, contains_schema, f"{path}[{index}]", root_id)
            )
            min_contains = int(schema.get("minContains", 1))
            if match_count < min_contains:
                raise SimpleValidationError(f"{path}: fewer items than minContains")
            if "maxContains" in schema and match_count > int(schema["maxContains"]):
                raise SimpleValidationError(f"{path}: more items than maxContains")
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, item in enumerate(instance):
                self._validate(item, item_schema, f"{path}[{index}]", root_id)

    def _validate_string(self, instance: str, schema: dict, path: str) -> None:
        if len(instance) < int(schema.get("minLength", 0)):
            raise SimpleValidationError(f"{path}: shorter than minLength")
        if "pattern" in schema and not re.search(str(schema["pattern"]), instance):
            raise SimpleValidationError(f"{path}: pattern mismatch")
        if schema.get("format") == "date-time":
            try:
                datetime.fromisoformat(instance.replace("Z", "+00:00"))
            except ValueError as exc:
                raise SimpleValidationError(f"{path}: invalid date-time") from exc

    def _validate_number(self, instance: int | float, schema: dict, path: str) -> None:
        if "minimum" in schema and instance < schema["minimum"]:
            raise SimpleValidationError(f"{path}: below minimum")
        if "maximum" in schema and instance > schema["maximum"]:
            raise SimpleValidationError(f"{path}: above maximum")


def _decode_pointer_token(token: str) -> str:
    return token.replace("~1", "/").replace("~0", "~")
