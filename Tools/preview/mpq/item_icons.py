import json
import re
import struct
import sys

dbc_path, sql_path, ids_path, list_path, items_path = sys.argv[1:6]

with open(dbc_path, "rb") as handle:
    data = handle.read()
magic, records, fields, record_size, string_size = struct.unpack_from("<4s4I", data)
assert magic == b"WDBC", magic
strings = 20 + records * record_size
icons = {}
for index in range(records):
    row = struct.unpack_from("<%dI" % fields, data, 20 + index * record_size)
    # ItemDisplayInfo 3.3.5: ID, ModelName[2], ModelTexture[2], InventoryIcon[2], ...
    offset = row[5]
    end = data.index(b"\0", strings + offset)
    icons[row[0]] = data[strings + offset:end].decode("utf-8", "replace")

wanted = set()
with open(ids_path, encoding="utf-8") as handle:
    for line in handle:
        head = line.split("\t", 1)[0]
        if head.isdigit():
            wanted.add(int(head))

row_pattern = re.compile(r"^\((\d+),\d+,\d+,-?\d+,'((?:[^'\\]|\\.)*)',(\d+),(\d+),")
items, needed = {}, set()
with open(sql_path, encoding="utf-8") as handle:
    for line in handle:
        match = row_pattern.match(line)
        if not match or int(match.group(1)) not in wanted:
            continue
        icon = icons.get(int(match.group(3)))
        if not icon:
            continue
        items[match.group(1)] = {"name": match.group(2).replace("\\'", "'"), "quality": int(match.group(4)), "icon": icon}
        needed.add(icon)

with open(list_path, "w", newline="\r\n") as handle:
    handle.write("\n".join("Interface\\Icons\\" + icon + ".blp" for icon in sorted(needed)) + "\n")
with open(items_path, "w", encoding="utf-8") as handle:
    json.dump(items, handle, ensure_ascii=False)
print("items", len(items), "of", len(wanted), "icons", len(needed))
