import 'package:flutter/material.dart';
import '../services/analytics_engine.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category.dart';
import 'add_ad_details.dart';

import '../services/api_service.dart';

class AddAdMapPage extends StatefulWidget {
  final Category selectedLeafCategory;
  final String transactionType;
  final List<XFile>? images;
  final XFile? reelVideo;
  final String selectedCity;
  final String selectedRegion;
  final Map<String, dynamic>? editingAdData;

  const AddAdMapPage({
    super.key,
    required this.selectedLeafCategory,
    required this.transactionType,
    required this.selectedCity,
    required this.selectedRegion,
    this.images,
    this.reelVideo,
    this.editingAdData,
  });

  @override
  State<AddAdMapPage> createState() => _AddAdMapPageState();
}

class _AddAdMapPageState extends State<AddAdMapPage> {
  List<String> _suggestedLandmarks = [];
  final List<String> _selectedLandmarks = [];
  bool _isLoadingLandmarks = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'add_ad_map');
    _fetchLandmarks();
  }

  Future<void> _fetchLandmarks() async {
    setState(() => _isLoadingLandmarks = true);
    try {
      final landmarks = await _apiService.fetchLocationIntelligence(
        widget.selectedCity, 
        widget.selectedRegion
      );
      if (mounted) {
        setState(() {
          _suggestedLandmarks = landmarks;
        });
      }
    } catch (e) {
      debugPrint('Error fetching landmarks: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLandmarks = false);
      }
    }
  }

  void _nextStep(BuildContext context, {bool skipped = false}) {
    AnalyticsEngine().logButtonTapped(buttonName: 'next_step', location: 'add_ad_map');
          Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAdDetailsPage(
          selectedLeafCategory: widget.selectedLeafCategory,
          transactionType: widget.transactionType,
          images: widget.images,
          reelVideo: widget.reelVideo,
          selectedCity: widget.selectedCity,
          selectedRegion: widget.selectedRegion,
          mapLocation: skipped ? null : '31.9539,35.9106', // Mock coordinates for Amman
          selectedLandmarks: _selectedLandmarks,
          editingAdData: widget.editingAdData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('تحديد الموقع بدقة', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.9),
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        ),
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Simulated Map Background (since we don't have Google Maps SDK active right now)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                image: const DecorationImage(
                  // A subtle seamless dot pattern via gradient
                  image: CachedNetworkImageProvider('https://www.transparenttextures.com/patterns/cartographer.png'), // A very faint map-like texture pattern
                  repeat: ImageRepeat.repeat,
                  opacity: 0.15,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Mock map elements for feel
                  Positioned(
                    top: 200, left: 50,
                    child: Container(width: 120, height: 40, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20))),
                  ),
                  Positioned(
                    bottom: 300, right: 80,
                    child: Container(width: 200, height: 60, decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(30))),
                  ),
                  
                  // The Pin
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Text('حرك الخريطة للتحديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      // Animated pin (simulated by a shadow underneath)
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            width: 20,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Icon(Icons.location_on, size: 56, color: Color(0xFFE53935)),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Icon(Icons.circle, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // My Location Button
          Positioned(
            bottom: 140,
            right: 24,
            child: FloatingActionButton(
              onPressed: () {},
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0075FF),
              elevation: 4,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          
          // Bottom Actions Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF0075FF).withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.map_rounded, color: Color(0xFF0075FF)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الموقع الحالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${widget.selectedCity} - ${widget.selectedRegion}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Location Intelligence Section
                  if (_isLoadingLandmarks)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('نبحث عن معالم قريبة...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    )
                  else if (_suggestedLandmarks.isNotEmpty) ...[
                    const Text('معالم مجاورة مقترحة:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedLandmarks.map((landmark) {
                        final isSelected = _selectedLandmarks.contains(landmark);
                        return FilterChip(
                          label: Text(landmark, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0075FF),
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedLandmarks.add(landmark);
                              } else {
                                _selectedLandmarks.remove(landmark);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          onPressed: () => _nextStep(context, skipped: true),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: Colors.grey.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('تخطي', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _nextStep(context, skipped: false),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: const Color(0xFF0075FF),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('تأكيد الموقع', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
