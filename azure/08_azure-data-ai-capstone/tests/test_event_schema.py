import pytest

from ingestion.events.schema import validate_event

def test_valid_event():
    validate_event({
        "event_id": "E-1",
        "order_id": "O-1",
        "status": "PICKED_UP",
        "event_time": "2026-09-06T00:00:00Z",
        "location": "Hyderabad",
    })

def test_malformed_event_rejected():
    with pytest.raises(ValueError):
        validate_event({"event_id": "E-1"})
