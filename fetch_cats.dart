import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://api.sooq-com.com/api/categories'));
  final data = jsonDecode(res.body)['data'] as List;
  for (var c in data) {
    if (c['name'].toString().contains('شقق') || c['name'].toString().contains('ستوديو')) {
      print('ID: ${c['id']}, Name: ${c['name']}, Parent: ${c['parent_id']}');
    }
  }
}
