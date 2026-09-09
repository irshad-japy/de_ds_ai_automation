from __future__ import annotations

import argparse
from pathlib import Path

from common.config import env

PROFILES = {
    "local": [],
    "adls": ["ADLS_FILE_SYSTEM"],
    "events": ["EVENTHUB_NAME"],
    "documents": ["DOCUMENTINTELLIGENCE_ENDPOINT", "DOCUMENTINTELLIGENCE_API_KEY"],
    "search": ["AZURE_SEARCH_ENDPOINT", "AZURE_SEARCH_INDEX"],
    "embeddings": ["AZURE_OPENAI_ENDPOINT", "AZURE_OPENAI_EMBEDDING_DEPLOYMENT"],
    "foundry": ["FOUNDRY_PROJECT_ENDPOINT", "FOUNDRY_MODEL_DEPLOYMENT"],
}

def present(name: str) -> bool:
    return bool(env(name))

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=[*PROFILES, "all"], default="local")
    args = parser.parse_args()

    if not Path(".env").exists():
        print("[WARN] .env not found. Local-only commands can still run.")

    profiles = list(PROFILES) if args.profile == "all" else [args.profile]
    failed = False
    for profile in profiles:
        required = PROFILES[profile]
        print(f"\n[{profile.upper()}]")
        if not required:
            print("  OK - no Azure settings required")
            continue
        for name in required:
            ok = present(name)
            print(f"  {'OK' if ok else 'MISSING'} - {name}")
            failed |= not ok

        if profile == "adls":
            auth_ok = present("ADLS_ACCOUNT_URL") or present("AZURE_STORAGE_CONNECTION_STRING")
            print(f"  {'OK' if auth_ok else 'MISSING'} - ADLS_ACCOUNT_URL or connection string")
            failed |= not auth_ok
        if profile == "events":
            auth_ok = present("EVENTHUB_FULLY_QUALIFIED_NAMESPACE") or present("EVENTHUB_CONNECTION_STRING")
            print(f"  {'OK' if auth_ok else 'MISSING'} - namespace or connection string")
            failed |= not auth_ok

    if failed:
        print("\n[FAILED] Fill missing values in .env for the selected profile.")
        return 2
    print("\n[SUCCESS] Configuration check passed for selected profile(s).")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
