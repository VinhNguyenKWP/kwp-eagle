from .providers import call_llm

PROMPT = "Use the context to answer.\nContext:\n{ctx}\n\nQ: {q}\nA:"

def call_llm_with_context(question: str, context: str) -> str:
    return call_llm(PROMPT.format(ctx=context, q=question))
