from __future__ import annotations

import argparse
import json
from pathlib import Path

from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.core.credentials import AzureKeyCredential

from common.config import env


def _value(field: dict | None):
    if not field:
        return None
    for key in ("valueString", "valueDate", "valueNumber", "valueCurrency", "content"):
        if key in field and field[key] not in (None, ""):
            return field[key]
    return field


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", default="data/synthetic/invoice_001.pdf")
    args = parser.parse_args()
    endpoint = env("DOCUMENTINTELLIGENCE_ENDPOINT")
    key = env("DOCUMENTINTELLIGENCE_API_KEY")
    if not endpoint or not key:
        raise RuntimeError("Set DOCUMENTINTELLIGENCE_ENDPOINT and DOCUMENTINTELLIGENCE_API_KEY")

    client = DocumentIntelligenceClient(endpoint=endpoint, credential=AzureKeyCredential(key))
    with open(args.file, "rb") as f:
        result = client.begin_analyze_document("prebuilt-invoice", body=f).result()
    data = result.as_dict()
    out = Path("output/document_intelligence")
    out.mkdir(parents=True, exist_ok=True)
    target = out / "invoice_001_result.json"
    target.write_text(json.dumps(data, indent=2, default=str), encoding="utf-8")

    fields = (data.get("documents") or [{}])[0].get("fields", {}) if data.get("documents") else {}
    print("InvoiceId:", _value(fields.get("InvoiceId")))
    print("VendorName:", _value(fields.get("VendorName")))
    print("InvoiceTotal:", _value(fields.get("InvoiceTotal")))
    print(f"[SUCCESS] Full extraction saved to {target}")


if __name__ == "__main__":
    main()
