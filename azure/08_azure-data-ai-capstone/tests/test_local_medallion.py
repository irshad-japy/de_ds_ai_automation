from pathlib import Path

from lakehouse.local_medallion import run_pipeline

def test_local_medallion(tmp_path):
    summary = run_pipeline(Path("data/synthetic/orders_001.csv"), tmp_path)
    assert summary["total_orders"] == 10
    assert summary["total_revenue"] > 0
    assert (tmp_path / "gold" / "customer_metrics.csv").exists()
