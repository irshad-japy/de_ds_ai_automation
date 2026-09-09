from __future__ import annotations

import argparse
import json
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from azure.eventhub import EventHubConsumerClient

from common.adls import upload_file
from common.auth import get_token_credential
from common.config import Settings
from ingestion.events.schema import validate_event

def build_consumer() -> EventHubConsumerClient:
    s = Settings()
    if s.eventhub_connection_string:
        return EventHubConsumerClient.from_connection_string(
            conn_str=s.eventhub_connection_string,
            consumer_group=s.eventhub_consumer_group,
            eventhub_name=s.eventhub_name,
        )
    return EventHubConsumerClient(
        fully_qualified_namespace=s.eventhub_namespace,
        eventhub_name=s.eventhub_name,
        consumer_group=s.eventhub_consumer_group,
        credential=get_token_credential(),
    )

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-events", type=int, default=3)
    args = parser.parse_args()
    received: list[dict] = []
    client = build_consumer()

    def on_event(partition_context, event):
        try:
            payload = json.loads(event.body_as_str())
            validate_event(payload)
            received.append(payload)
            print(f"Received {payload['event_id']} from partition {partition_context.partition_id}")
        except Exception as exc:
            print(f"Rejected malformed event: {exc}")
        if len(received) >= args.max_events:
            client.close()

    try:
        with client:
            client.receive(on_event=on_event, starting_position="-1")
    except Exception as exc:
        if len(received) < args.max_events:
            raise
        print(f"Receiver closed after reaching target count: {exc.__class__.__name__}")

    if not received:
        raise RuntimeError("No events were received")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    with tempfile.TemporaryDirectory() as tmp:
        local = Path(tmp) / f"shipment_events_{stamp}.jsonl"
        local.write_text("\n".join(json.dumps(x) for x in received) + "\n", encoding="utf-8")
        upload_file(local, f"bronze/events/{local.name}")
    print(f"[SUCCESS] Wrote {len(received)} events to ADLS bronze/events")


if __name__ == "__main__":
    main()
