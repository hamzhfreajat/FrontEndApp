import 'package:flutter/material.dart';
import '../models/ad.dart';
import '../services/api_service.dart';
import '../widgets/premium_real_estate_card.dart';
import 'ad_details_page.dart';

class AdsListPage extends StatefulWidget {
  final String? keyword;
  final int? categoryId;
  final String? sectionName;
  final String? userId;

  const AdsListPage({
    super.key,
    this.keyword,
    this.categoryId,
    this.sectionName,
    this.userId,
  });

  @override
  State<AdsListPage> createState() => _AdsListPageState();
}

class _AdsListPageState extends State<AdsListPage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<Ad> _ads = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _skip = 0;
  final int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchAds();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _fetchAds() async {
    setState(() {
      _isLoading = true;
      _skip = 0;
      _hasMore = true;
    });

    try {
      final results = await _apiService.fetchAds(
        search: widget.keyword,
        categoryId: widget.categoryId,
        section: widget.sectionName,
        userId: widget.userId,
        skip: _skip,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _ads = results;
          _skip += results.length;
          _hasMore = results.length == _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final results = await _apiService.fetchAds(
        search: widget.keyword,
        categoryId: widget.categoryId,
        section: widget.sectionName,
        userId: widget.userId,
        skip: _skip,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _ads.addAll(results);
          _skip += results.length;
          _hasMore = results.length == _limit;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'نتائج البحث';
    if (widget.keyword != null && widget.keyword!.isNotEmpty) {
      title = widget.keyword!;
    } else if (widget.sectionName != null && widget.sectionName!.isNotEmpty) {
      title = widget.sectionName!;
    } else if (widget.userId != null && widget.userId!.isNotEmpty) {
      title = 'إعلانات المستخدم';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ads.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchAds,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _ads.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _ads.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final ad = _ads[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PremiumRealEstateCard(
                          ad: ad,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdDetailsPage(ad: ad),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('لا توجد نتائج مطابقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          const Text('جرب كلمات مفتاحية أخرى أو تصفح الأقسام', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
