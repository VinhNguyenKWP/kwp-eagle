from .retriever import get_retriever
from ..llm.compose import call_llm_with_context

def rag_answer(question: str, top_k: int = 5) -> dict:
    retriever = get_retriever()
    hits = retriever.search(question, top_k=top_k)   # [(doc_id, score, meta)]
    context = "\n\n".join(h["text"] for _,_,h in hits)
    answer = call_llm_with_context(question, context)
    return {"answer": answer, "sources": [h for _,_,h in hits]}
