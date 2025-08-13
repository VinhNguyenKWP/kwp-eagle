import os
try:
    from openai import OpenAI
    _client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
except Exception:
    _client = None

def call_llm(prompt: str) -> str:
    if _client is None:
        # fallback đơn giản để demo
        return prompt[:400]
    resp = _client.chat.completions.create(
        model=os.getenv("KWP_LLM","gpt-4o-mini"),
        messages=[{"role":"user","content":prompt}],
        temperature=0.2,
    )
    return resp.choices[0].message.content.strip()
