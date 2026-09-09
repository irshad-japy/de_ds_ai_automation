from __future__ import annotations

import argparse

from azure.ai.projects import AIProjectClient

from ai.agent.tools import supported_metric_answer
from ai.rag.query_search import retrieve
from common.auth import get_token_credential
from common.config import Settings

def build_tool_context(mode: str, question: str) -> str:
    parts = []
    if mode in {"policy", "mixed"}:
        rows = retrieve(question, 3)
        parts.append("KNOWLEDGE TOOL (read-only Azure AI Search):\n" + "\n".join(
            f"[{r['source']}] {r['content']}" for r in rows
        ))
    if mode in {"metric", "mixed"}:
        parts.append("METRIC TOOL (read-only Gold data):\n" + supported_metric_answer(question))
    return "\n\n".join(parts)

def main() -> None:
    parser = argparse.ArgumentParser(description="Constrained read-only Data + AI Assistant")
    parser.add_argument("--mode", choices=["policy", "metric", "mixed"], required=True)
    parser.add_argument("question")
    parser.add_argument("--offline", action="store_true", help="Print tool context without calling Foundry")
    args = parser.parse_args()

    context = build_tool_context(args.mode, args.question)
    if args.offline:
        print(context)
        print("\n[SUCCESS] Read-only tool execution completed (offline synthesis mode).")
        return

    s = Settings()
    project = AIProjectClient(endpoint=s.foundry_project_endpoint, credential=get_token_credential())
    openai = project.get_openai_client()
    prompt = f"""
You are a constrained read-only Data + AI assistant. You cannot modify data or resources.
Use only the tool output below. Cite sources in square brackets. If unsupported, say so.

QUESTION: {args.question}

TOOL OUTPUT:
{context}
"""
    response = openai.responses.create(model=s.foundry_model, input=prompt)
    print(response.output_text)


if __name__ == "__main__":
    main()
