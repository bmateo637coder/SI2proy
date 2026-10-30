import pytest

import start_render


def test_migration_runs_before_uvicorn(monkeypatch):
    calls = []
    monkeypatch.setenv("PORT", "10000")
    monkeypatch.setattr(start_render, "migrate", lambda: calls.append("migrated"))
    monkeypatch.setattr(start_render.os, "execv", lambda executable, arguments: calls.append(arguments))
    start_render.main()
    assert calls[0] == "migrated"
    assert calls[1][-2:] == ["--port", "10000"]
    assert "main:app" in calls[1]


def test_failed_migration_does_not_start_server(monkeypatch):
    def fail():
        raise RuntimeError("Migration failed")
    monkeypatch.setattr(start_render, "migrate", fail)
    monkeypatch.setattr(start_render.os, "execv", lambda *_: pytest.fail("No debe arrancar sin migración"))
    with pytest.raises(RuntimeError, match="Migration failed"):
        start_render.main()
