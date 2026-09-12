#!/usr/bin/env python3
"""Correct the array item types in the readme generator's JSON Schema output.

The generator's `[array]` modifier always emits `items: {"type": "string"}`,
whatever the array actually holds, so every array of objects ends up rejecting
its own default value. The item type is taken from the default instead, and the
constraint is dropped when the default is empty and the item type is therefore
unknown.

Null defaults are a separate trap: the generator cannot infer a type for them
and Helm's JSON Schema has no `nullable` keyword, so values.yaml uses typed
empty values (`""`, `{}`, `[]`) rather than nulls. Keep it that way.

Usage: schema-postprocess.py <schema.json> <values.json>
"""
import json
import sys

JSON_TYPES = {
    bool: "boolean",
    int: "integer",
    float: "number",
    str: "string",
    dict: "object",
    list: "array",
}


def item_type(values):
    """The JSON Schema type shared by every element, or None if not uniform."""
    types = {JSON_TYPES.get(type(value)) for value in values}
    return types.pop() if len(types) == 1 else None


def fix(node, actual):
    if not isinstance(node, dict):
        return

    if node.get("type") == "array" and isinstance(actual, list):
        inferred = item_type(actual)
        if inferred:
            node["items"] = {"type": inferred}
        else:
            node.pop("items", None)

    for name, child in node.get("properties", {}).items():
        fix(child, actual.get(name) if isinstance(actual, dict) else None)


def main():
    schema_path, values_path = sys.argv[1], sys.argv[2]
    schema = json.load(open(schema_path))
    values = json.load(open(values_path)) or {}

    fix(schema, values)

    with open(schema_path, "w") as handle:
        json.dump(schema, handle, indent=4)
        handle.write("\n")


if __name__ == "__main__":
    main()
