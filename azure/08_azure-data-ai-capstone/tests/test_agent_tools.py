from pathlib import Path

from ai.agent.tools import supported_metric_answer
from lakehouse.local_medallion import run_pipeline

def test_metric_tool_is_read_only(tmp_path, monkeypatch):
    run_pipeline(Path("data/synthetic/orders_001.csv"), Path("output"))
    answer = supported_metric_answer("What is total revenue?")
    assert "total_revenue=" in answer
    assert "source=" in answer
