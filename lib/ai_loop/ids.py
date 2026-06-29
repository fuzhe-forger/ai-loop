"""Identifier validation helpers."""

from __future__ import annotations

import re

_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


def validate_id(value: str, *, field: str = "id") -> str:
    if not _ID_PATTERN.fullmatch(value):
        raise ValueError(f"{field} must match {_ID_PATTERN.pattern}")
    return value
