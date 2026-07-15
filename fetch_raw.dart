import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://api.sooq-com.com/api/categories'));
  File('raw_cats.txt').writeAsStringSync(res.body);
  print('Done');
}
