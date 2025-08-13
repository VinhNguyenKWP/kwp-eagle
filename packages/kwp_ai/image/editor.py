from PIL import Image
def thumbnail(src: str, dst: str, size=(512,512)):
    im = Image.open(src); im.thumbnail(size); im.save(dst); return dst
