def summarize(text: str, max_len: int = 200) -> str:
    return (text[:max_len-3] + "...") if len(text) > max_len else text
