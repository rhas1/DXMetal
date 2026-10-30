# Removes what a Finder layout file (.DS_Store) records about the Mac it was made on, so it can be
# published in the disk image: the bookmark records, and the part of the background picture's alias
# that points to the disk image file Finder saw it in (with its path and this Mac's disk). Finder
# finds the background by the disk's name and the picture's path, which stay. tools/dmg-window.sh
# runs it. Usage: python3 clean-dsstore.py FILE
import plistlib
import struct
import sys

path = sys.argv[1]
data = bytearray(open(path, 'rb').read())

# The file is a buddy allocator ("Bud1") holding a B-tree of records; offsets count from byte 4.
assert data[4:8] == b'Bud1', 'not a .DS_Store file'
root_offset, root_size = struct.unpack_from('>II', data, 8)
root = data[4 + root_offset:4 + root_offset + root_size]
count = struct.unpack_from('>I', root, 0)[0]
addresses = struct.unpack_from('>%dI' % count, root, 8)
pos = 8 + 4 * ((count + 255) // 256 * 256)  # the address list is padded to 256 entries
directories = {}
entries = struct.unpack_from('>I', root, pos)[0]
pos += 4
for _ in range(entries):
    length = root[pos]
    name = bytes(root[pos + 1:pos + 1 + length]).decode()
    directories[name] = struct.unpack_from('>I', root, pos + 1 + length)[0]
    pos += 5 + length
for _ in range(32):  # free lists, one per block size
    pos += 4 + 4 * struct.unpack_from('>I', root, pos)[0]
root_used = pos


def block(number):
    address = addresses[number]
    return 4 + (address & ~0x1f), 1 << (address & 0x1f)


master_offset, _ = block(directories['DSDB'])
node, levels, records = struct.unpack_from('>III', data, master_offset)
assert levels == 0, 'expected a single-node layout'
node_offset, node_size = block(node)

# Each record: file name (UTF-16), four-letter code and type, then a value whose size the type sets.
fixed = {'long': 4, 'shor': 4, 'bool': 1, 'type': 4, 'comp': 8, 'dutc': 8}
kept = []
pos = node_offset + 8
for _ in range(struct.unpack_from('>I', data, node_offset + 4)[0]):
    start = pos
    pos += 4 + 2 * struct.unpack_from('>I', data, pos)[0]
    code, kind = bytes(data[pos:pos + 4]).decode(), bytes(data[pos + 4:pos + 8]).decode()
    pos += 8
    value_start = pos
    if kind in fixed:
        pos += fixed[kind]
    else:
        pos += 4 + struct.unpack_from('>I', data, pos)[0] * (2 if kind == 'ustr' else 1)
    if code in ('pBBk', 'pBB0'):
        continue
    record = bytes(data[start:pos])
    if code == 'icvp':
        view = plistlib.loads(bytes(data[value_start + 4:pos]))
        alias = view.get('backgroundImageAlias')
        if alias:
            assert struct.unpack_from('>H', alias, 6)[0] == 2, 'unexpected alias version'
            # An alias (version 2) has a 150-byte header, then tagged fields ending with tag -1.
            # Tag 20 is the alias of the disk image file that held the picture.
            fields, i = bytearray(alias[:150]), 150
            while True:
                tag, length = struct.unpack_from('>hH', alias, i)
                size = 4 + length + (length & 1)
                if tag != 20:
                    fields += alias[i:i + size]
                i += size
                if tag == -1:
                    break
            struct.pack_into('>H', fields, 4, len(fields))
            view['backgroundImageAlias'] = bytes(fields)
        blob = plistlib.dumps(view, fmt=plistlib.FMT_BINARY)
        record = bytes(data[start:value_start]) + struct.pack('>I', len(blob)) + blob
    kept.append(record)

node_bytes = struct.pack('>II', 0, len(kept)) + b''.join(kept)
assert len(node_bytes) <= node_size
data[node_offset:node_offset + node_size] = node_bytes.ljust(node_size, b'\0')
struct.pack_into('>I', data, master_offset + 8, len(kept))

# Free space, and the end of the allocator's own block, can still hold old copies of records, so
# blank everything else.
used = [(0, 36), (4 + root_offset, root_used)] + [block(n) for n, a in enumerate(addresses[1:], 1) if a]
cleaned = bytearray(len(data))
for offset, size in used:
    cleaned[offset:offset + size] = data[offset:offset + size]
open(path, 'wb').write(cleaned)
