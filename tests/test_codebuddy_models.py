import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from telegram_bot.utils.codebuddy_models import (
    discover_codebuddy_models,
    parse_env_model_list,
    resolve_available_models,
)


def test_parse_env_model_list():
    assert parse_env_model_list("a, b ,a,c") == ("a", "b", "c")
    assert parse_env_model_list("") == ()


def test_discover_codebuddy_models_from_local_storage(tmp_path: Path):
    storage = tmp_path / "local_storage"
    storage.mkdir()
    payload = [
        {
            "data": {
                "agents": [
                    {
                        "name": "cli",
                        "models": ["minimax-m3-ioa", "deepseek-v4-pro-ioa"],
                    }
                ],
                "models": [
                    {"id": "minimax-m3-ioa", "name": "MiniMax-M3"},
                    {"id": "deepseek-v4-pro-ioa", "name": "Deepseek-V4-Pro"},
                ],
            }
        }
    ]
    (storage / "entry_test.info").write_text(json.dumps(payload), encoding="utf-8")

    models, labels = discover_codebuddy_models(codebuddy_home=tmp_path)
    assert models == ("minimax-m3-ioa", "deepseek-v4-pro-ioa")
    assert labels["minimax-m3-ioa"] == "MiniMax-M3"


def test_resolve_available_models_prefers_codebuddy_cache(tmp_path: Path):
    storage = tmp_path / "local_storage"
    storage.mkdir()
    payload = [
        {
            "data": {
                "agents": [{"name": "cli", "models": ["minimax-m3-ioa", "glm-5.2-ioa"]}],
                "models": [],
            }
        }
    ]
    (storage / "entry_test.info").write_text(json.dumps(payload), encoding="utf-8")

    models, _ = resolve_available_models(
        env_models="minimax-m3-ioa",
        codebuddy_home=tmp_path,
    )
    assert models == ("minimax-m3-ioa",)


def test_resolve_available_models_uses_env_when_cache_missing(tmp_path: Path):
    models, _ = resolve_available_models(
        env_models="alpha,beta",
        codebuddy_home=tmp_path,
    )
    assert models == ("alpha", "beta")
