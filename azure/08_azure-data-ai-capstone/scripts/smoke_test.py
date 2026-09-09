from __future__ import annotations

import json
from pathlib import Path

from lakehouse.local_medallion import run_pipeline

def main() -> int:
    orders = Path("data/synthetic/orders_001.csv")
    if not orders.exists():
        raise FileNotFoundError("Synthetic orders file missing. Run scripts.generate_synthetic_data")
    summary = run_pipeline(orders, Path("output"))
    assert summary["total_orders"] > 0
    assert summary["total_revenue"] > 0
    print(json.dumps(summary, indent=2))
    print("[SUCCESS] Local batch -> Bronze -> Silver -> Gold smoke test passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
