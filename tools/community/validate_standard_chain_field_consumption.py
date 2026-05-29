#!/usr/bin/env python3
"""Validate standard-chain field consumption contracts."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from runtime_yaml import load_yaml

TARGET_STAGES = {
    "product-director",
    "product-manager",
    "design",
    "developer",
    "fix",
    "review",
    "verify",
    "qa",
    "delivery-owner",
}
ALLOWED_CONSUME_MODES = {"reference", "transform", "gate", "handoff"}
EXTERNAL_CONSUMERS = {
    "docs/{feature}/phase-{N}/signoff-package.json": {"user"},
}
GLOBAL_FORBIDDEN_TOKENS = (
    "product-manager-ledger.json",
    "design-ledger.json",
)
ACTIVE_LEDGER_PRODUCERS = {"product-director"}
REQUIRED_ARTIFACT_KEYS = ("path", "producer", "fields")
REQUIRED_FIELD_KEYS = (
    "producer",
    "authority",
    "consumers",
    "required_when",
    "failure_effect",
)
REQUIRED_CONSUMER_KEYS = ("consumer", "consumed_for", "consume_mode")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--standard-chain", type=Path, required=True)
    parser.add_argument("--field-consumption", type=Path, required=True)
    return parser.parse_args()


def non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def require_mapping(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{path} must be an object")
    return value


def require_keys(value: dict[str, Any], keys: tuple[str, ...], path: str) -> None:
    missing = [key for key in keys if key not in value]
    if missing:
        raise ValueError(f"{path} missing required keys: {', '.join(missing)}")


def canonical_artifact_path(artifact: str) -> str:
    if artifact.startswith("docs/"):
        return artifact
    if artifact == "brief.json":
        return "docs/{feature}/brief.json"
    return f"docs/{{feature}}/{artifact}"


def iter_strings(value: Any) -> Any:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, item in value.items():
            yield from iter_strings(key)
            yield from iter_strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from iter_strings(item)


def reject_forbidden_tokens(
    document: dict[str, Any], label: str, forbidden_tokens: tuple[str, ...]
) -> None:
    for text in iter_strings(document):
        for token in forbidden_tokens:
            if token in text:
                raise ValueError(f"{label} contains forbidden active token: {token}")


def validate_consumers(consumers: Any, path: str) -> None:
    if not isinstance(consumers, list) or not consumers:
        raise ValueError(f"{path}.consumers must be a non-empty array")
    for index, consumer in enumerate(consumers):
        consumer_path = f"{path}.consumers[{index}]"
        consumer_data = require_mapping(consumer, consumer_path)
        require_keys(consumer_data, REQUIRED_CONSUMER_KEYS, consumer_path)
        if not non_empty_string(consumer_data.get("consumer")):
            raise ValueError(f"{consumer_path}.consumer must be a non-empty string")
        if not non_empty_string(consumer_data.get("consumed_for")):
            raise ValueError(f"{consumer_path}.consumed_for must be a non-empty string")
        consume_mode = consumer_data.get("consume_mode")
        if consume_mode not in ALLOWED_CONSUME_MODES:
            allowed = ", ".join(sorted(ALLOWED_CONSUME_MODES))
            raise ValueError(f"{consumer_path}.consume_mode must be one of: {allowed}")


def validate_field(field: Any, path: str) -> set[str]:
    field_data = require_mapping(field, path)
    require_keys(field_data, REQUIRED_FIELD_KEYS, path)
    for key in ("producer", "authority", "required_when", "failure_effect"):
        if not non_empty_string(field_data.get(key)):
            raise ValueError(f"{path}.{key} must be a non-empty string")
    validate_consumers(field_data.get("consumers"), path)
    return {str(consumer["consumer"]) for consumer in field_data["consumers"]}


def validate_artifacts(contract: dict[str, Any]) -> dict[str, dict[str, set[str]]]:
    artifacts = contract.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        raise ValueError("artifacts must be a non-empty array")
    fields_by_path: dict[str, dict[str, set[str]]] = {}
    for index, artifact in enumerate(artifacts):
        artifact_path = f"artifacts[{index}]"
        artifact_data = require_mapping(artifact, artifact_path)
        require_keys(artifact_data, REQUIRED_ARTIFACT_KEYS, artifact_path)
        path = artifact_data.get("path")
        producer = artifact_data.get("producer")
        fields = artifact_data.get("fields")
        if not non_empty_string(path):
            raise ValueError(f"{artifact_path}.path must be a non-empty string")
        if not non_empty_string(producer):
            raise ValueError(f"{artifact_path}.producer must be a non-empty string")
        if not isinstance(fields, dict) or not fields:
            raise ValueError(f"{artifact_path}.fields must be a non-empty object")
        if "ledger" in str(path) and producer == "product-manager":
            raise ValueError(
                f"{artifact_path} must not declare a product-manager ledger"
            )
        field_consumers: dict[str, set[str]] = {}
        for field_name, field in fields.items():
            if not non_empty_string(field_name):
                raise ValueError(f"{artifact_path}.fields contains an empty field name")
            field_consumers[str(field_name)] = validate_field(
                field, f"{artifact_path}.fields.{field_name}"
            )
        fields_by_path[str(path)] = field_consumers
    return fields_by_path


def stage_input_consumers(standard_chain: dict[str, Any]) -> dict[str, set[str]]:
    chain = standard_chain.get("chain")
    if not isinstance(chain, list):
        raise ValueError("standard-chain chain must be an array")
    consumers_by_path: dict[str, set[str]] = {}
    for stage in chain:
        stage_data = require_mapping(stage, "chain[]")
        stage_name = stage_data.get("name")
        if not non_empty_string(stage_name):
            raise ValueError("chain[].name must be a non-empty string")
        inputs = stage_data.get("inputs", {})
        input_data = require_mapping(inputs, f"chain.{stage_name}.inputs")
        for input_group in ("required", "optional"):
            artifacts = input_data.get(input_group, [])
            if not isinstance(artifacts, list):
                raise ValueError(
                    f"chain.{stage_name}.inputs.{input_group} must be an array"
                )
            for artifact in artifacts:
                if not isinstance(artifact, str):
                    raise ValueError(
                        f"chain.{stage_name}.inputs.{input_group} contains a non-string artifact"
                    )
                artifact_name = artifact.split(" as ", 1)[0]
                consumers_by_path.setdefault(
                    canonical_artifact_path(artifact_name), set()
                ).add(str(stage_name))
        stage_inputs = input_data.get("stage_inputs", {})
        if stage_inputs is None:
            continue
        stage_input_data = require_mapping(
            stage_inputs, f"chain.{stage_name}.inputs.stage_inputs"
        )
        for substage_name, substage_inputs in stage_input_data.items():
            substage_data = require_mapping(
                substage_inputs,
                f"chain.{stage_name}.inputs.stage_inputs.{substage_name}",
            )
            for input_group in ("required", "optional"):
                artifacts = substage_data.get(input_group, [])
                if not isinstance(artifacts, list):
                    raise ValueError(
                        f"chain.{stage_name}.inputs.stage_inputs.{substage_name}.{input_group} must be an array"
                    )
                for artifact in artifacts:
                    if not isinstance(artifact, str):
                        raise ValueError(
                            f"chain.{stage_name}.inputs.stage_inputs.{substage_name}.{input_group} contains a non-string artifact"
                        )
                    artifact_name = artifact.split(" as ", 1)[0]
                    consumers_by_path.setdefault(
                        canonical_artifact_path(artifact_name), set()
                    ).add(str(stage_name))
    return consumers_by_path


def output_consumers(
    output_data: dict[str, Any], path: str, inferred: dict[str, set[str]]
) -> set[str]:
    explicit = output_data.get("consumers")
    if explicit is not None:
        if not isinstance(explicit, list) or not explicit:
            raise ValueError(f"chain output {path}.consumers must be a non-empty array")
        return {str(consumer) for consumer in explicit}
    return set(inferred.get(path, set())) | set(EXTERNAL_CONSUMERS.get(path, set()))


def validate_key_fields(stage_name: str, artifact: str, key_fields: Any) -> list[str]:
    if not isinstance(key_fields, list) or not key_fields:
        raise ValueError(
            f"chain.{stage_name}.{artifact}.key_fields must be a non-empty array"
        )
    seen: set[str] = set()
    duplicates: list[str] = []
    normalized: list[str] = []
    for field in key_fields:
        field_name = str(field)
        normalized.append(field_name)
        if field_name in seen and field_name not in duplicates:
            duplicates.append(field_name)
        seen.add(field_name)
    if duplicates:
        field_list = ", ".join(duplicates)
        raise ValueError(
            f"chain.{stage_name}.{artifact}.key_fields contains duplicate key_fields: {field_list}"
        )
    return normalized


def standard_chain_requirements(
    standard_chain: dict[str, Any],
) -> list[tuple[str, str, str, set[str]]]:
    chain = standard_chain.get("chain")
    if not isinstance(chain, list):
        raise ValueError("standard-chain chain must be an array")
    inferred = stage_input_consumers(standard_chain)
    required: list[tuple[str, str, str, set[str]]] = []
    for stage in chain:
        stage_data = require_mapping(stage, "chain[]")
        stage_name = stage_data.get("name")
        if stage_name not in TARGET_STAGES:
            continue
        outputs = stage_data.get("outputs")
        if not isinstance(outputs, list):
            raise ValueError(f"chain.{stage_name}.outputs must be an array")
        for output in outputs:
            output_data = require_mapping(output, f"chain.{stage_name}.outputs[]")
            artifact = output_data.get("artifact")
            if not non_empty_string(artifact):
                raise ValueError(
                    f"chain.{stage_name}.outputs[].artifact must be a non-empty string"
                )
            key_fields = output_data.get("key_fields")
            if key_fields is None:
                continue
            normalized_key_fields = validate_key_fields(
                str(stage_name), str(artifact), key_fields
            )
            path = canonical_artifact_path(str(artifact))
            required_consumers = output_consumers(output_data, path, inferred)
            if not required_consumers:
                continue
            for field in normalized_key_fields:
                required.append((str(stage_name), path, field, required_consumers))
    return required


def required_fields_by_path(
    requirements: list[tuple[str, str, str, set[str]]],
) -> dict[str, set[str]]:
    fields: dict[str, set[str]] = {}
    for _, path, field_name, _ in requirements:
        fields.setdefault(path, set()).add(field_name)
    return fields


def validate_active_co_creation_ledgers(standard_chain: dict[str, Any]) -> None:
    co_creation_ledgers = standard_chain.get("co_creation_ledgers", {})
    if co_creation_ledgers is None:
        return
    ledger_data = require_mapping(
        co_creation_ledgers, "standard-chain.co_creation_ledgers"
    )
    artifacts = ledger_data.get("artifacts", {})
    if artifacts is None:
        return
    artifact_data = require_mapping(
        artifacts, "standard-chain.co_creation_ledgers.artifacts"
    )
    for name, artifact in artifact_data.items():
        artifact_path = f"standard-chain.co_creation_ledgers.artifacts.{name}"
        artifact_mapping = require_mapping(artifact, artifact_path)
        producer = artifact_mapping.get("producer")
        if producer not in ACTIVE_LEDGER_PRODUCERS:
            raise ValueError(
                f"unsupported active co-creation ledger producer: {producer}"
            )


def validate(standard_chain_path: Path, field_consumption_path: Path) -> None:
    standard_chain = load_yaml(standard_chain_path)
    contract = load_yaml(field_consumption_path)
    reject_forbidden_tokens(standard_chain, "standard-chain", GLOBAL_FORBIDDEN_TOKENS)
    validate_active_co_creation_ledgers(standard_chain)
    if contract.get("version") != 1:
        raise ValueError("version must be 1")
    contract_fields = validate_artifacts(contract)
    requirements = standard_chain_requirements(standard_chain)
    required_fields = required_fields_by_path(requirements)
    for path, declared_fields in contract_fields.items():
        if path not in required_fields:
            continue
        extra_fields = sorted(set(declared_fields) - required_fields[path])
        if extra_fields:
            field_list = ", ".join(extra_fields)
            raise ValueError(
                f"field contract declares fields absent from standard-chain key_fields for {path}: {field_list}"
            )
    for stage_name, path, field_name, required_consumers in requirements:
        if path not in contract_fields:
            raise ValueError(
                f"field contract missing artifact for {stage_name}: {path}"
            )
        if field_name not in contract_fields[path]:
            raise ValueError(
                f"field contract missing {stage_name} output field: {path}.{field_name}"
            )
        declared_consumers = contract_fields[path][field_name]
        if not declared_consumers & required_consumers:
            expected = ", ".join(sorted(required_consumers))
            actual = ", ".join(sorted(declared_consumers))
            raise ValueError(
                f"field contract {stage_name} output {path}.{field_name} must declare at least one output consumer from [{expected}], got [{actual}]"
            )


def main() -> None:
    args = parse_args()
    validate(args.standard_chain, args.field_consumption)
    print("standard-chain field consumption contract PASS")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        raise SystemExit(
            f"standard-chain field consumption validation failed: {exc}"
        ) from exc
