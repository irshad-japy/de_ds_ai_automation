import json
import logging

import azure.functions as func

from ingestion.events.schema import validate_event

app = func.FunctionApp()

@app.event_hub_message_trigger(
    arg_name="event",
    event_hub_name="shipment-events",
    connection="EventHubConnection",
)
@app.blob_output(
    arg_name="outputblob",
    path="datalake/bronze/events/{datetime:yyyy}/{datetime:MM}/{datetime:dd}/{rand-guid}.json",
    connection="ADLSConnection",
)
def shipment_event_to_bronze(event: func.EventHubEvent, outputblob: func.Out[str]) -> None:
    payload = json.loads(event.get_body().decode("utf-8"))
    validate_event(payload)
    outputblob.set(json.dumps(payload))
    logging.info("Accepted shipment event %s", payload["event_id"])
