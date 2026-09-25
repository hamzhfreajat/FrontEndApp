import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/category.dart';
import 'add_ad_details.dart';

class EditAdImagesPage extends StatefulWidget {
  final Category selectedLeafCategory;
  final String transactionType;
  final String selectedCity;
  final String selectedRegion;
  final Map<String, dynamic> editingAdData;

  const EditAdImagesPage({
    super.key,
    required this.selectedLeafCategory,
    required this.transactionType,
    required this.selectedCity,
    required this.selectedRegion,
    required this.editingAdData,
  });

  @override
  State<EditAdImagesPage> createState() => _EditAdImagesPageState();
}

class _EditAdImagesPageState extends State<EditAdImagesPage> {
  final List<String> _existingUrls = [];
  final List<XFile> _newImages = [];
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    if (widget.editingAdData['image_urls'] != null) {
      _existingUrls.addAll(List<String>.from(widget.editingAdData['image_urls']));
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) {
        List<XFile> validImages = [];
        bool hasLargeImages = false;

        for (var file in picked) {
          final bytes = await file.length();
          if (bytes > 5 * 1024 * 1024) { // 5MB limit
            hasLargeImages = true;
          } else {
            validImages.add(file);
          }
        }

        if (hasLargeImages && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم استبعاد بعض الصور لأن حجمها يتجاوز 5 ميجابايت.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }

        setState(() {
          _newImages.addAll(validImages);
          if (_existingUrls.length + _newImages.length > 20) {
            final toRemove = (_existingUrls.length + _newImages.length) - 20;
            if (toRemove <= _newImages.length) {
              _newImages.removeRange(_newImages.length - toRemove, _newImages.length);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _nextStep() async {
    if (_existingUrls.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار صور للإعلان'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_newImages.isNotEmpty) {
      setState(() {
        _isUploading = true;
        _uploadStatus = 'جاري رفع الصور...';
      });

      List<String> uploadedUrls = [];
      for (int i = 0; i < _newImages.length; i++) {
        setState(() {
          _uploadStatus = 'جاري رفع صورة ${i + 1} من ${_newImages.length}...';
        });
        try {
          final url = await ApiService().uploadSingleMedia(_newImages[i]);
          uploadedUrls.add(url);
        } catch (e) {
          debugPrint('Failed to upload image $i: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('فشل رفع الصورة ${i + 1}'), backgroundColor: Colors.red),
            );
          }
          setState(() {
            _isUploading = false;
          });
          return;
        }
      }

      _existingUrls.addAll(uploadedUrls);
      _newImages.clear();
      
      setState(() {
        _isUploading = false;
        _uploadStatus = '';
      });
    }

    widget.editingAdData['image_urls'] = _existingUrls;
    if (_existingUrls.isNotEmpty) {
      widget.editingAdData['image_url'] = _existingUrls.first;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddAdDetailsPage(
            selectedLeafCategory: widget.selectedLeafCategory,
            transactionType: widget.transactionType,
            selectedCity: widget.selectedCity,
            selectedRegion: widget.selectedRegion,
            editingAdData: widget.editingAdData,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل صور الإعلان', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade50,
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_uploadStatus, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الصور الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_existingUrls.isEmpty)
                    const Text('لا توجد صور حالية.', style: TextStyle(color: Colors.grey)),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _existingUrls.length,
                    itemBuilder: (context, index) {
                      final url = _existingUrls[index];
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(url.startsWith('http') ? url : 'https://api.sooqcom.app$url'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('الصور الجديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_newImages.isEmpty)
                    const Text('لم تقم بإضافة صور جديدة.', style: TextStyle(color: Colors.grey)),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _newImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(File(_newImages[index].path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeNewImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_existingUrls.length + _newImages.length < 20)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('إضافة صور'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue,
                          elevation: 0,
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isUploading ? null : _nextStep,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF0075FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('التالي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
