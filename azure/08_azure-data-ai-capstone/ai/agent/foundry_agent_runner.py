from __future__ import annotations

import argparse

from azure.ai.projects import AIProjectClient

from common.auth import get_token_credential
from common.config import Settings

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("question", nargs="?", default="What is the return policy?")
    args = parser.parse_args()
    s = Settings()
    if not s.foundry_agent_name:
        raise RuntimeError("Create a Foundry agent first and set FOUNDRY_AGENT_NAME")
    project = AIProjectClient(endpoint=s.foundry_project_endpoint, credential=get_token_credential())
    client = project.get_openai_client(agent_name=s.foundry_agent_name)
    response = client.responses.create(input=args.question)
    print(response.output_text)
    if response.model_extra:
        print("agent_session_id:", response.model_extra.get("agent_session_id"))

if __name__ == "__main__":
    main()
