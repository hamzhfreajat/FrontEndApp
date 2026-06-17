import 'package:flutter/material.dart';
import '../services/analytics_engine.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category.dart';
import 'add_ad_region.dart';

class AddAdCityPage extends StatefulWidget {
  final Category selectedLeafCategory;
  final String transactionType;
  final List<XFile>? images;
  final XFile? reelVideo;
  final Map<String, dynamic>? editingAdData;

  const AddAdCityPage({
    super.key,
    required this.selectedLeafCategory,
    required this.transactionType,
    this.images,
    this.reelVideo,
    this.editingAdData,
  });

  @override
  State<AddAdCityPage> createState() => _AddAdCityPageState();
}

class _AddAdCityPageState extends State<AddAdCityPage> {

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'add_ad_city');
  }

  final List<String> _allCities = [
    'عمان',
    'إربد',
    'الزرقاء',
    'السلط',
    'مادبا',
    'العقبة',
    'جرش',
    'عجلون',
    'المفرق',
    'الكرك',
    'الطفيلة',
    'معان',
  ];

  String _searchQuery = '';

  List<String> get _filteredCities {
    if (_searchQuery.isEmpty) return _allCities;
    return _allCities.where((city) => city.contains(_searchQuery)).toList();
  }

  void _selectCity(String city) {
    AnalyticsEngine().logButtonTapped(buttonName: 'next_step', location: 'add_ad_city');
          Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAdRegionPage(
          selectedLeafCategory: widget.selectedLeafCategory,
          transactionType: widget.transactionType,
          images: widget.images,
          reelVideo: widget.reelVideo,
          selectedCity: city,
          editingAdData: widget.editingAdData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار المحافظة', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Header Area
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 24, 
              right: 24, 
              bottom: 32, 
              top: MediaQuery.of(context).padding.top + 60
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0075FF).withValues(alpha: 0.05), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أين يقع إعلانك؟ 📍',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'اختر المحافظة حتى يتمكن المشترون في منطقتك من العثور على إعلانك بكل سهولة.',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 28),
                
                // Premium Floating Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن المحافظة...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0075FF)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _filteredCities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('لم نتمكن من العثور على "$_searchQuery"', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24).copyWith(bottom: 120),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: _filteredCities.length,
                    itemBuilder: (context, index) {
                      final city = _filteredCities[index];
                      return _buildCityCard(city);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: widget.editingAdData != null && widget.editingAdData!['location'] != null
        ? Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _selectCity(widget.editingAdData!['location']),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: Text('متابعة بنفس المحافظة (${widget.editingAdData!['location']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF0075FF),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          )
        : null,
    );
  }

  Widget _buildCityCard(String city) {
    IconData icon;
    Color color;
    
    switch (city) {
      case 'عمان': icon = Icons.location_city_rounded; color = const Color(0xFF0075FF); break;
      case 'إربد': icon = Icons.eco_rounded; color = const Color(0xFF10B981); break;
      case 'الزرقاء': icon = Icons.factory_rounded; color = const Color(0xFFF59E0B); break;
      case 'العقبة': icon = Icons.sailing_rounded; color = const Color(0xFF06B6D4); break;
      case 'السلط': icon = Icons.landscape_rounded; color = const Color(0xFF8B5CF6); break;
      case 'جرش': icon = Icons.account_balance_rounded; color = const Color(0xFFEC4899); break;
      case 'عجلون': icon = Icons.park_rounded; color = const Color(0xFF14B8A6); break;
      case 'كم': icon = Icons.map_rounded; color = const Color(0xFF6366F1); break;
      case 'الكرك': icon = Icons.castle_rounded; color = const Color(0xFFEAB308); break;
      case 'مادبا': icon = Icons.museum_rounded; color = const Color(0xFFF43F5E); break;
      case 'المفرق': icon = Icons.route_rounded; color = const Color(0xFFF97316); break;
      case 'الطفيلة': icon = Icons.terrain_rounded; color = const Color(0xFF84CC16); break;
      case 'معان': icon = Icons.wb_sunny_rounded; color = const Color(0xFFEF4444); break;
      default: icon = Icons.map_rounded; color = const Color(0xFF64748B); break;
    }

    final bool isSelected = widget.editingAdData != null && widget.editingAdData!['location'] == city;

    return InkWell(
      onTap: () => _selectCity(city),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade100, 
            width: isSelected ? 3 : 2
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              city,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
