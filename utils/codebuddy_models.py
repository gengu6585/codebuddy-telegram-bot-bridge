"""Resolve CodeBuddy model lists for the /model picker."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Iterable

logger = logging.getLogger(__name__)

DEFAULT_MODELS: tuple[str, ...] = ("minimax-m3-ioa",)


def _dedupe_preserve_order(items: Iterable[str]) -> tuple[str, ...]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        name = item.strip()
        if not name or name in seen:
            continue
        seen.add(name)
        out.append(name)
    return tuple(out)


def _parse_models_json(path: Path) -> tuple[str, ...]:
    if not path.is_file():
        return ()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        logger.debug("Skipping unreadable models.json at %s: %s", path, exc)
        return ()

    ids: list[str] = []
    available = data.get("availableModels")
    if isinstance(available, list):
        ids.extend(str(item).strip() for item in available if str(item).strip())

    models = data.get("models")
    if isinstance(models, list):
        for item in models:
            if isinstance(item, dict):
                model_id = str(item.get("id", "")).strip()
                if model_id:
                    ids.append(model_id)

    return _dedupe_preserve_order(ids)


def _parse_local_storage_entry(path: Path) -> tuple[list[str], dict[str, str]]:
    """Return (cli model ids, id -> display name) from a CodeBuddy cache entry."""
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        logger.debug("Skipping unreadable CodeBuddy cache %s: %s", path, exc)
        return [], {}

    if not isinstance(payload, list):
        return [], {}

    model_ids: list[str] = []
    labels: dict[str, str] = {}

    for entry in payload:
        if not isinstance(entry, dict):
            continue
        data = entry.get("data")
        if not isinstance(data, dict):
            continue

        agents = data.get("agents")
        if isinstance(agents, list):
            for agent in agents:
                if not isinstance(agent, dict):
                    continue
                if agent.get("name") != "cli":
                    continue
                models = agent.get("models")
                if isinstance(models, list):
                    model_ids.extend(str(item).strip() for item in models if str(item).strip())

        catalog = data.get("models")
        if isinstance(catalog, list):
            for item in catalog:
                if not isinstance(item, dict):
                    continue
                model_id = str(item.get("id", "")).strip()
                if not model_id:
                    continue
                display = str(item.get("name") or model_id).strip()
                labels[model_id] = display

    return model_ids, labels


def discover_codebuddy_models(
    codebuddy_home: Path | None = None,
    project_root: Path | None = None,
) -> tuple[tuple[str, ...], dict[str, str]]:
    """Load model IDs from CodeBuddy cache and optional models.json files."""
    home = codebuddy_home or (Path.home() / ".codebuddy")
    labels: dict[str, str] = {}
    ids: list[str] = []

    storage_dir = home / "local_storage"
    if storage_dir.is_dir():
        for path in sorted(storage_dir.glob("entry_*.info")):
            if path.name.startswith("._"):
                continue
            entry_ids, entry_labels = _parse_local_storage_entry(path)
            ids.extend(entry_ids)
            labels.update(entry_labels)

    ids.extend(_parse_models_json(home / "models.json"))
    if project_root is not None:
        ids.extend(_parse_models_json(project_root / ".codebuddy" / "models.json"))

    return _dedupe_preserve_order(ids), labels


def parse_env_model_list(raw: str | None) -> tuple[str, ...]:
    if not raw or not raw.strip():
        return ()
    return _dedupe_preserve_order(raw.split(","))


def resolve_available_models(
    *,
    env_models: str | None = None,
    codebuddy_home: Path | None = None,
    project_root: Path | None = None,
    default_models: tuple[str, ...] = DEFAULT_MODELS,
) -> tuple[tuple[str, ...], dict[str, str]]:
    """Resolve /model picker entries.

    Priority:
    1. CodeBuddy cache / models.json (full enterprise catalog)
    2. BOT_KNOWN_MODELS env (explicit override when discovery is empty)
    3. Built-in defaults
    """
    discovered, labels = discover_codebuddy_models(codebuddy_home, project_root)
    configured = parse_env_model_list(env_models)

    if discovered:
        if configured:
            allow = set(configured)
            filtered = tuple(model_id for model_id in discovered if model_id in allow)
            if filtered:
                return filtered, labels
        return discovered, labels

    if configured:
        return configured, labels

    return default_models, labels
