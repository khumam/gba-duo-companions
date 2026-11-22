"""GBA BIOS LZ77 (type 0x10) decompression, strict enough to scan a ROM for blocks: returns None when the header
or a back-reference doesn't make sense. Same format as the pack API's lz77() and gfx.decode{ lz77 = true }."""


def lz77(rom, a, limit=0x20000):
    if a + 4 > len(rom) or rom[a] != 0x10:
        return None
    size = rom[a + 1] | rom[a + 2] << 8 | rom[a + 3] << 16
    if size == 0 or size > limit or size % 32:
        return None
    out = bytearray()
    p = a + 4
    try:
        while len(out) < size:
            flags = rom[p]
            p += 1
            for b in range(8):
                if len(out) >= size:
                    break
                if flags & (0x80 >> b):
                    x = rom[p] << 8 | rom[p + 1]
                    p += 2
                    n, disp = (x >> 12) + 3, (x & 0xFFF) + 1
                    if disp > len(out):
                        return None
                    for _ in range(n):
                        out.append(out[-disp])
                else:
                    out.append(rom[p])
                    p += 1
    except IndexError:
        return None
    return bytes(out[:size])
