import os, re, sys, collections, unicodedata
wurzel = sys.argv[1]
endungen = tuple(sys.argv[2].split(','))
zeichen = set("→←↑↓›‹▸▾▴◂▲▼▶◀✓✗✕×⌄⌃↗↘↔↕⟳↻⚠●○◆■□▪✔☀☾⏻⌂⚡⏸◉⋯⟲⤴⤵➜➔⏵⏷⏶⌫✚＋⇄⇅⇆↺↩↪⌘⏱⏰⚙★☆♨❄✎✏⌕🔍")
treffer = collections.defaultdict(list)
for d, _, fs in os.walk(wurzel):
    if 'node_modules' in d or '.next' in d or 'Tests' in d or '.build' in d: continue
    for f in fs:
        if not f.endswith(endungen): continue
        p = os.path.join(d, f)
        try: zeilen = open(p, encoding='utf-8').read().split('\n')
        except Exception: continue
        for i, z in enumerate(zeilen, 1):
            s = z.strip()
            # Kommentare ausblenden (grob)
            kommentar = s.startswith('//') or s.startswith('*') or s.startswith('/*') or s.startswith('///') or s.startswith('{/*')
            for c in set(z) & zeichen:
                treffer[c].append((p, i, kommentar, s[:150]))
for c, l in sorted(treffer.items(), key=lambda kv: -len(kv[1])):
    code = [t for t in l if not t[2]]
    print(f"== {c} U+{ord(c):04X} {unicodedata.name(c,'?')}: {len(code)} im Code, {len(l)-len(code)} in Kommentaren")
    for p, i, k, s in code[:int(sys.argv[3]) if len(sys.argv)>3 else 6]:
        print(f"   {os.path.relpath(p, wurzel)}:{i}: {s}")
