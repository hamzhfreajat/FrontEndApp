import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  try {
    final res = await http.get(Uri.parse('https://api.sooq-com.com/api/categories'));
    final json = jsonDecode(res.body);
    // The data might be a map with a list inside, or just a map.
    List data = [];
    if (json['data'] is List) {
      data = json['data'];
    } else if (json['data'] is Map && json['data']['categories'] is List) {
      data = json['data']['categories'];
    } else if (json['data'] is Map && json['data']['data'] is List) {
      data = json['data']['data'];
    } else {
      print('Unknown data format: ${json['data'].runtimeType}');
      return;
    }
    
    final out = File('cats_output.txt');
    var sink = out.openWrite();
    for (var c in data) {
      final name = c['name'].toString();
      if (name.contains('يوم') || name.contains('شقق') || name.contains('عقار')) {
        sink.writeln('ID: ${c['id']}, Name: $name, Parent: ${c['parent_id']}');
      }
    }
    await sink.close();
    print('Done writing to cats_output.txt');
  } catch (e) {
    print('Error: $e');
  }
}
