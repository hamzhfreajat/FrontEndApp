import sys, re, json

filepaths = [
    r'd:\open\classifieds-app\frontend\lib\screens\home_page.dart',
    r'd:\open\classifieds-app\frontend\lib\screens\root_screen.dart',
]

strings = []
for filepath in filepaths:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = r"(['\"])([^'\"]*[\u0600-\u06FF]+[^'\"]*)\1"
    matches = re.findall(pattern, content)
    strings.extend([m[1] for m in matches])

strings = list(set(strings))
out = {}
for s in strings:
    out[s] = ''

with open('ar_strings.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=2)

print(f'Extracted {len(strings)} strings to ar_strings.json')
