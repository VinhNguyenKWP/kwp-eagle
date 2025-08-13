import os
def get_device(has_cuda: bool = False) -> str:
    want = os.getenv("KWPAI_DEVICE", "").lower()
    if want in {"cpu","gpu","cuda"}:
        return "cuda" if want in {"gpu","cuda"} and has_cuda else "cpu"
    return "cuda" if has_cuda else "cpu"
