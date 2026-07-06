void main() {
  final vals = [
    "[]",
    "['']",
    '[""]',
    [],
    [""],
    ["[]"],
  ];
  for (var val in vals) {
    String strVal;
    if (val is List) {
      if (val.isEmpty) continue;
      strVal = val.join('، ');
    } else {
      strVal = val.toString();
    }
    strVal = strVal.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "").trim();
    print('Original: $val -> Final: "$strVal", isEmpty: ${strVal.isEmpty}, isNotEmpty: ${strVal.isNotEmpty}');
  }
}
