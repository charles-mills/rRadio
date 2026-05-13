#!/usr/bin/env python3
"""Generated rRadio payload helpers.

Generated data is stored as JSON compressed with the LZMA-alone container used by
Garry's Mod util.Compress/util.Decompress, then Base64 encoded inside a small Lua
wrapper. Client send limits are measured by compressing the final Lua wrapper.
"""

from __future__ import annotations

import base64
import hashlib
import json
import lzma
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

CLIENT_SENT_LZMA_HARD_LIMIT = 64 * 1024
CLIENT_SENT_LZMA_TARGET = 60 * 1024

GENERATED_PAYLOAD_FORMAT = "rradio.generated_payload.v1"
GENERATED_PAYLOAD_ENCODING = "base64:gmod-lzma:json"

SERVER_REGISTRY_MAX_JSON_BYTES = 16 * 1024 * 1024
CLIENT_STATION_CHUNK_MAX_JSON_BYTES = 512 * 1024
LOCALE_CHUNK_MAX_JSON_BYTES = 512 * 1024

GMOD_LZMA_FILTERS = [
    {
        "id": lzma.FILTER_LZMA1,
        "dict_size": 1 << 16,
        "lc": 3,
        "lp": 0,
        "pb": 2,
        "mode": lzma.MODE_NORMAL,
        "nice_len": 32,
        "mf": lzma.MF_BT4,
    }
]


@dataclass(frozen=True)
class PayloadFile:
    text: str
    json_size: int
    payload_lzma_size: int
    lua_raw_size: int
    lua_sent_lzma_size: int
    sha256: str


@dataclass(frozen=True)
class ParsedPayloadWrapper:
    path: Path
    format: str
    encoding: str
    kind: str
    version: int
    uncompressed_bytes: int
    compressed_bytes: int
    sha256: str
    payload: dict[str, Any]


def json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=False,
    ).encode("utf-8")


def gmod_lzma_compress(data: bytes) -> bytes:
    compressed = lzma.compress(
        data,
        format=lzma.FORMAT_RAW,
        filters=GMOD_LZMA_FILTERS,
    )

    filter_options = GMOD_LZMA_FILTERS[0]
    props = (
        (int(filter_options["pb"]) * 5 + int(filter_options["lp"])) * 9
        + int(filter_options["lc"])
    )
    header = (
        bytes([props])
        + int(filter_options["dict_size"]).to_bytes(4, "little")
        + len(data).to_bytes(8, "little")
    )
    return header + compressed


def gmod_lzma_decompress(blob: bytes) -> bytes:
    if len(blob) < 13:
        raise lzma.LZMAError("input is too short for LZMA-alone header")

    props = blob[0]
    lc = props % 9
    remainder = props // 9
    lp = remainder % 5
    pb = remainder // 5
    if lc > 8 or lp > 4 or pb > 4:
        raise lzma.LZMAError("invalid LZMA properties")

    dict_size = int.from_bytes(blob[1:5], "little")
    expected_size = int.from_bytes(blob[5:13], "little")
    filters = [
        {
            "id": lzma.FILTER_LZMA1,
            "dict_size": dict_size,
            "lc": lc,
            "lp": lp,
            "pb": pb,
        }
    ]
    decoded = lzma.decompress(blob[13:], format=lzma.FORMAT_RAW, filters=filters)
    if len(decoded) != expected_size:
        raise lzma.LZMAError(
            f"uncompressed size mismatch: got {len(decoded)}, expected {expected_size}"
        )
    return decoded


def base64_inline(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def lua_long_string(value: str) -> str:
    # Base64 alphabet does not contain ], so a normal long string is safe.
    return f"[[{value}]]"


def lua_sent_lzma_size(lua_text: str) -> int:
    return len(gmod_lzma_compress(lua_text.encode("utf-8")))


def _payload_record_lines(
    *,
    kind: str,
    payload: dict[str, Any],
    indent: str,
) -> tuple[list[str], bytes, bytes, str]:
    raw_json = json_bytes(payload)
    compressed = gmod_lzma_compress(raw_json)
    encoded = base64_inline(compressed)
    digest = hashlib.sha256(raw_json).hexdigest()

    lines = [
        f'{indent}format = "{GENERATED_PAYLOAD_FORMAT}",',
        f'{indent}encoding = "{GENERATED_PAYLOAD_ENCODING}",',
        f'{indent}kind = "{kind}",',
        f"{indent}version = 1,",
        f"{indent}uncompressedBytes = {len(raw_json)},",
        f"{indent}compressedBytes = {len(compressed)},",
        f'{indent}sha256 = "{digest}",',
        f"{indent}data = {lua_long_string(encoded)}",
    ]
    return lines, raw_json, compressed, digest


def render_payload_return_file(
    *,
    header: str,
    kind: str,
    payload: dict[str, Any],
) -> PayloadFile:
    lines, raw_json, compressed, digest = _payload_record_lines(
        kind=kind,
        payload=payload,
        indent="    ",
    )
    text = "\n".join([header, "return {", *lines, "}", ""])
    return _payload_file_for_text(
        text,
        raw_json=raw_json,
        compressed=compressed,
        digest=digest,
    )


def render_server_registry_file(
    *,
    header: str,
    payload: dict[str, Any],
    label: str = "rradio/server/stations/builtin_registry.lua",
    max_bytes: int = SERVER_REGISTRY_MAX_JSON_BYTES,
) -> PayloadFile:
    lines, raw_json, compressed, digest = _payload_record_lines(
        kind="server_station_registry",
        payload=payload,
        indent="    ",
    )
    text = "\n".join(
        [
            header,
            "rRadio = rRadio or {}",
            "rRadio.generated = rRadio.generated or {}",
            "",
            "local payload = {",
            *lines,
            "}",
            "",
            "local decoded = rRadio.generatedPayload.DecodeOrError( payload, {",
            f'    label = "{label}",',
            '    kind = "server_station_registry",',
            f"    maxBytes = {max_bytes}",
            "} )",
            "",
            "rRadio.generated.serverStationCountries = decoded.countries or {}",
            "return rRadio.generated.serverStationCountries",
            "",
        ]
    )
    return _payload_file_for_text(
        text,
        raw_json=raw_json,
        compressed=compressed,
        digest=digest,
    )


def _payload_file_for_text(
    text: str,
    payload: dict[str, Any] | None = None,
    *,
    raw_json: bytes | None = None,
    compressed: bytes | None = None,
    digest: str | None = None,
) -> PayloadFile:
    if raw_json is None:
        if payload is None:
            raise ValueError("payload or raw_json is required")
        raw_json = json_bytes(payload)
    if compressed is None:
        compressed = gmod_lzma_compress(raw_json)
    if digest is None:
        digest = hashlib.sha256(raw_json).hexdigest()

    return PayloadFile(
        text=text,
        json_size=len(raw_json),
        payload_lzma_size=len(compressed),
        lua_raw_size=len(text.encode("utf-8")),
        lua_sent_lzma_size=lua_sent_lzma_size(text),
        sha256=digest,
    )


def validate_client_sent_file(
    label: str,
    rendered: PayloadFile | str,
    *,
    target: int = CLIENT_SENT_LZMA_TARGET,
    hard_limit: int = CLIENT_SENT_LZMA_HARD_LIMIT,
) -> int:
    size = rendered.lua_sent_lzma_size if isinstance(rendered, PayloadFile) else lua_sent_lzma_size(rendered)
    if size > hard_limit:
        raise ValueError(f"{label} is {size} compressed bytes, exceeding AddCSLuaFile hard limit {hard_limit}")
    if size > target:
        raise ValueError(f"{label} is {size} compressed bytes, exceeding target {target}")
    return size


def _extract_string(text: str, field: str) -> str:
    match = re.search(rf"\b{re.escape(field)}\s*=\s*\"([^\"]*)\"", text)
    if not match:
        raise ValueError(f"missing {field} field")
    return match.group(1)


def _extract_int(text: str, field: str) -> int:
    match = re.search(rf"\b{re.escape(field)}\s*=\s*(\d+)", text)
    if not match:
        raise ValueError(f"missing {field} field")
    return int(match.group(1))


def _extract_data(text: str) -> str:
    match = re.search(r"\bdata\s*=\s*\[\[([A-Za-z0-9+/=]*)\]\]", text, re.DOTALL)
    if not match:
        raise ValueError("missing data field")
    return match.group(1)


def parse_payload_lua_wrapper(path: Path) -> ParsedPayloadWrapper:
    text = path.read_text(encoding="utf-8")
    payload_format = _extract_string(text, "format")
    encoding = _extract_string(text, "encoding")
    kind = _extract_string(text, "kind")
    version = _extract_int(text, "version")
    uncompressed_bytes = _extract_int(text, "uncompressedBytes")
    compressed_bytes = _extract_int(text, "compressedBytes")
    digest = _extract_string(text, "sha256")
    encoded = _extract_data(text)

    if payload_format != GENERATED_PAYLOAD_FORMAT:
        raise ValueError(f"invalid payload format {payload_format!r}")
    if encoding != GENERATED_PAYLOAD_ENCODING:
        raise ValueError(f"invalid payload encoding {encoding!r}")
    if version != 1:
        raise ValueError(f"invalid wrapper version {version!r}")

    try:
        compressed = base64.b64decode(encoded, validate=True)
    except ValueError as exc:
        raise ValueError(f"base64 decode failed: {exc}") from exc

    if len(compressed) != compressed_bytes:
        raise ValueError(
            f"compressed byte count mismatch: got {len(compressed)}, expected {compressed_bytes}"
        )

    try:
        raw_json = gmod_lzma_decompress(compressed)
    except lzma.LZMAError as exc:
        raise ValueError(f"LZMA decompress failed: {exc}") from exc

    if len(raw_json) != uncompressed_bytes:
        raise ValueError(
            f"uncompressed byte count mismatch: got {len(raw_json)}, expected {uncompressed_bytes}"
        )

    actual_digest = hashlib.sha256(raw_json).hexdigest()
    if actual_digest != digest:
        raise ValueError(f"SHA256 mismatch: got {actual_digest}, expected {digest}")

    try:
        payload = json.loads(raw_json.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"JSON decode failed: {exc}") from exc

    if not isinstance(payload, dict):
        raise ValueError("decoded JSON payload is not an object")

    return ParsedPayloadWrapper(
        path=path,
        format=payload_format,
        encoding=encoding,
        kind=kind,
        version=version,
        uncompressed_bytes=uncompressed_bytes,
        compressed_bytes=compressed_bytes,
        sha256=digest,
        payload=payload,
    )


def parse_payload_lua_file(path: Path) -> dict[str, Any]:
    """Decode a deterministic generated payload wrapper without executing Lua."""

    return parse_payload_lua_wrapper(path).payload


def _selftest() -> None:
    payload = b'{"ok":true,"rows":[1,2,3]}'
    compressed = gmod_lzma_compress(payload)
    assert gmod_lzma_decompress(compressed) == payload

    rendered = render_payload_return_file(
        header="-- selftest",
        kind="selftest",
        payload={"version": 1, "ok": True, "rows": [1, 2, 3]},
    )
    assert rendered.payload_lzma_size > 0
    assert rendered.lua_sent_lzma_size > 0


if __name__ == "__main__":
    _selftest()
