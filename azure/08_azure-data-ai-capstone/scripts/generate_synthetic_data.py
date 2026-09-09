from __future__ import annotations

import csv
import json
from pathlib import Path

ORDERS = [
    ["O-1001", "2026-09-01", "C-001", "Laptop Stand", 1, 45.0, "SHIPPED"],
    ["O-1002", "2026-09-01", "C-002", "USB-C Hub", 2, 32.5, "SHIPPED"],
    ["O-1003", "2026-09-02", "C-001", "Keyboard", 1, 75.0, "PROCESSING"],
    ["O-1004", "2026-09-02", "C-003", "Webcam", 1, 80.0, "DELIVERED"],
    ["O-1005", "2026-09-03", "C-004", "Headset", 2, 55.0, "PROCESSING"],
    ["O-1006", "2026-09-03", "C-002", "Mouse", 1, 28.0, "DELIVERED"],
    ["O-1007", "2026-09-04", "C-003", "USB-C Hub", 1, 32.5, "SHIPPED"],
    ["O-1008", "2026-09-04", "C-005", "Monitor Arm", 1, 120.0, "PROCESSING"],
    ["O-1009", "2026-09-05", "C-001", "Mouse Pad", 3, 15.0, "DELIVERED"],
    ["O-1010", "2026-09-05", "C-004", "Keyboard", 1, 75.0, "SHIPPED"],
]

POLICIES = [
    {
        "id": "POL-RET-01",
        "title": "Retail Return Policy",
        "category": "policy",
        "source": "policy-return.md",
        "content": "Unused items may be returned within 30 days of delivery with proof of purchase. Opened electronics are accepted within 14 days unless defective.",
    },
    {
        "id": "POL-SHIP-01",
        "title": "Shipment Delay Policy",
        "category": "policy",
        "source": "policy-shipping.md",
        "content": "A shipment is considered delayed when it misses the promised delivery date by more than 24 hours. Customer support should proactively notify the customer for delays above 48 hours.",
    },
]

EVENTS = [
    {"event_id": "E-001", "order_id": "O-1001", "status": "IN_TRANSIT", "event_time": "2026-09-06T08:00:00Z", "location": "Hyderabad"},
    {"event_id": "E-002", "order_id": "O-1002", "status": "OUT_FOR_DELIVERY", "event_time": "2026-09-06T08:05:00Z", "location": "Bengaluru"},
    {"event_id": "E-003", "order_id": "O-1003", "status": "PICKED_UP", "event_time": "2026-09-06T08:10:00Z", "location": "Pune"},
]

def main() -> None:
    out = Path("data/synthetic")
    out.mkdir(parents=True, exist_ok=True)
    with (out / "orders_001.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["order_id", "order_date", "customer_id", "product", "quantity", "unit_price", "status"])
        writer.writerows(ORDERS)
    (out / "policies.json").write_text(json.dumps(POLICIES, indent=2), encoding="utf-8")
    with (out / "shipment_events.jsonl").open("w", encoding="utf-8") as f:
        for event in EVENTS:
            f.write(json.dumps(event) + "\n")
    print(f"Generated synthetic files in {out}")


if __name__ == "__main__":
    main()
