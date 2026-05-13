#!/usr/bin/env python3
"""Shared packing helpers.

New generated runtime artifacts are constrained by compressed AddCSLuaFile send
size; raw-byte helpers remain for legacy unpack/validation code paths.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Generic, Iterable, Sequence, TypeVar

from generated_payloads import (
    CLIENT_SENT_LZMA_HARD_LIMIT,
    CLIENT_SENT_LZMA_TARGET,
    lua_sent_lzma_size,
)

PACK_SIZE_LIMIT = 63 * 1024

T = TypeVar("T")


@dataclass(frozen=True)
class PackedBin(Generic[T]):
    """A packed bin with payload size accounting, excluding fixed wrapper bytes."""

    items: tuple[T, ...]
    payload_size: int
    remaining: int


def utf8_size(text: str) -> int:
    return len(text.encode("utf-8"))


def require_size_at_most(label: str, text: str, limit: int = PACK_SIZE_LIMIT) -> int:
    size = utf8_size(text)
    if size > limit:
        raise ValueError(f"{label} is {size} bytes, exceeding {limit} byte limit")
    return size


def require_lua_sent_lzma_at_most(
    label: str,
    text: str,
    *,
    target: int = CLIENT_SENT_LZMA_TARGET,
    hard_limit: int = CLIENT_SENT_LZMA_HARD_LIMIT,
) -> int:
    size = lua_sent_lzma_size(text)
    if size > hard_limit:
        raise ValueError(
            f"{label} is {size} compressed bytes, exceeding AddCSLuaFile hard limit {hard_limit}"
        )
    if size > target:
        raise ValueError(f"{label} is {size} compressed bytes, exceeding target {target}")
    return size


def best_fit_decreasing(
    items: Sequence[T],
    *,
    capacity: int,
    size_of: Callable[[T], int],
    separator_size: int = 0,
    sort_key: Callable[[T], object] | None = None,
    can_share_bin: Callable[[T, Sequence[T]], bool] | None = None,
) -> list[PackedBin[T]]:
    """Pack items with Best-Fit Decreasing and exact byte costs.

    capacity is the available payload capacity after fixed wrapper bytes.
    separator_size is charged before each non-first item in a bin.
    can_share_bin may reject otherwise-fitting placements, for example to keep
    two fragments from the same logical group out of one chunk.
    """

    if capacity < 0:
        raise ValueError(f"packing capacity cannot be negative: {capacity}")
    if separator_size < 0:
        raise ValueError(f"separator size cannot be negative: {separator_size}")

    def order(item: T) -> tuple[int, object]:
        secondary = sort_key(item) if sort_key else ""
        return (-size_of(item), secondary)

    mutable_bins: list[tuple[list[T], int]] = []
    for item in sorted(items, key=order):
        item_size = size_of(item)
        if item_size > capacity:
            raise ValueError(
                f"item is {item_size} bytes, exceeding {capacity} byte packing capacity"
            )

        best_index: int | None = None
        best_remaining: int | None = None
        best_payload_size: int | None = None

        for index, (bin_items, payload_size) in enumerate(mutable_bins):
            if can_share_bin and not can_share_bin(item, bin_items):
                continue

            placement_cost = item_size + (separator_size if bin_items else 0)
            next_payload_size = payload_size + placement_cost
            if next_payload_size > capacity:
                continue

            remaining = capacity - next_payload_size
            if best_remaining is None or remaining < best_remaining:
                best_index = index
                best_remaining = remaining
                best_payload_size = next_payload_size

        if best_index is None:
            mutable_bins.append(([item], item_size))
        else:
            mutable_bins[best_index][0].append(item)
            mutable_bins[best_index] = (mutable_bins[best_index][0], best_payload_size or 0)

    return [
        PackedBin(
            items=tuple(bin_items),
            payload_size=payload_size,
            remaining=capacity - payload_size,
        )
        for bin_items, payload_size in mutable_bins
    ]


def flatten_bins(bins: Iterable[PackedBin[T]]) -> list[T]:
    return [item for packed_bin in bins for item in packed_bin.items]
