import sys

file_path = r'd:\open\classifieds-app\frontend\lib\screens\add_ad_details.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'add_ad_basic_info.dart';", "import 'add_ad_basic_info.dart';\nimport '../utils/arabic_numbers_formatter.dart';")

content = content.replace(
    "keyboardType: const TextInputType.numberWithOptions(decimal: true),",
    "keyboardType: const TextInputType.numberWithOptions(decimal: true),\n            inputFormatters: [ArabicNumbersFormatter()],"
)

content = content.replace(
    "keyboardType: keyboardType,",
    "keyboardType: keyboardType,\n            inputFormatters: (keyboardType == TextInputType.number || keyboardType == const TextInputType.numberWithOptions(decimal: true) || keyboardType == TextInputType.phone) ? [ArabicNumbersFormatter()] : null,"
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
