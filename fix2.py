import sys

file_path = r'd:\open\classifieds-app\frontend\lib\screens\add_ad_basic_info.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import '../utils/form_analytics_tracker.dart';", "import '../utils/form_analytics_tracker.dart';\nimport '../utils/arabic_numbers_formatter.dart';")

content = content.replace(
    "keyboardType: TextInputType.number,",
    "keyboardType: TextInputType.number,\n                            inputFormatters: [ArabicNumbersFormatter()],"
)

content = content.replace(
    "keyboardType: TextInputType.phone,",
    "keyboardType: TextInputType.phone,\n                          inputFormatters: [ArabicNumbersFormatter()],"
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
