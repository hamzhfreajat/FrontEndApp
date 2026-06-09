import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../services/api_service.dart';

class VerificationRepository {
  /// Calls backend to generate an S3 presigned URL
  Future<String> getPresignedUrl() async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/verify/upload-url'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"file_type": "image/jpeg"}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // We will encode both URL and KEY in a pipe format string 
      // so it travels easily through the Bloc's simple String states,
      // or we can just fetch the key later from the url. Let's return JSON as string!
      return jsonEncode(data);
    } else {
      throw Exception('Failed to get presigned URL: ${response.body}');
    }
  }

  /// Uploads binary file to the pre-signed URL directly to Amazon S3
  Future<void> uploadImageToPresignedUrl(String uploadDataStr, String localFilePath) async {
    final uploadData = jsonDecode(uploadDataStr);
    final String uploadUrl = uploadData['upload_url'];
    
    final file = File(localFilePath);
    final bytes = await file.readAsBytes();
    
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': 'image/jpeg'},
      body: bytes,
    );
    
    if (response.statusCode != 200) {
      throw Exception('S3 Upload Failed: ${response.statusCode}');
    }
  }

  /// Hits backend POST /verify/ocr with FRONT and optionally BACK S3 Keys!
  Future<Map<String, dynamic>> extractOCRData(String frontUploadDataStr, String backUploadDataStr) async {
    final frontData = jsonDecode(frontUploadDataStr);
    String? backKey;
    
    if (backUploadDataStr != 'none') {
      final backData = jsonDecode(backUploadDataStr);
      backKey = backData['key'];
    }
    
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/verify/ocr'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "s3_key_front": frontData['key'],
        if (backKey != null) "s3_key_back": backKey
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'fullName': data['full_name'],
        'nationalId': data['national_id'],
        'dateOfBirth': data['date_of_birth'],
        'expiryDate': data['expiry_date'],
      };
    } else {
      throw Exception('OCR extraction failed: ${response.body}');
    }
  }

  /// Hits backend POST /verify/face-match
  Future<bool> verifyFaceMatch(String livenessSessionId) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/verify/face-match'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"liveness_session_id": livenessSessionId}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['liveness_passed'] == true;
    }
    return false;
  }

  /// Final submit
  Future<bool> submitVerification(Map<String, dynamic> data) async {
    // In a real app we would get the auth token and submit, but for now we simulate returning true
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}

