import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: child,
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  const ShimmerList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return ShimmerLoading(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 120, // Approximate list item height
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

class ShimmerRealEstateList extends StatelessWidget {
  final int itemCount;
  const ShimmerRealEstateList({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Image Section Shimmer
              ShimmerLoading(
                child: Container(
                  height: 200,
                  color: Colors.white,
                ),
              ),
              // 2. Info Section Shimmer
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Price Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerLoading(child: Container(width: double.infinity, height: 16, color: Colors.white)),
                              const SizedBox(height: 8),
                              ShimmerLoading(child: Container(width: 150, height: 16, color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ShimmerLoading(child: Container(width: 80, height: 20, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Attributes Row (Bedrooms, Bathrooms, Area)
                    Row(
                      children: [
                        ShimmerLoading(child: Container(width: 50, height: 12, color: Colors.white)),
                        const SizedBox(width: 16),
                        ShimmerLoading(child: Container(width: 50, height: 12, color: Colors.white)),
                        const SizedBox(width: 16),
                        ShimmerLoading(child: Container(width: 50, height: 12, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Location Row
                    Row(
                      children: [
                        ShimmerLoading(child: Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))),
                        const SizedBox(width: 6),
                        ShimmerLoading(child: Container(width: 120, height: 12, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    // Owner Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ShimmerLoading(child: Container(width: 24, height: 24, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))),
                            const SizedBox(width: 8),
                            ShimmerLoading(child: Container(width: 100, height: 12, color: Colors.white)),
                          ],
                        ),
                        ShimmerLoading(child: Container(width: 40, height: 12, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class ShimmerCategoryGrid extends StatelessWidget {
  final int itemCount;
  const ShimmerCategoryGrid({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: GridView.builder(
         shrinkWrap: true,
         physics: const NeverScrollableScrollPhysics(),
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
         ),
         itemCount: itemCount,
         itemBuilder: (context, index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 10,
                  color: Colors.white,
                ),
              ],
            );
         },
      ),
    );
  }
}

class ShimmerHomeScreen extends StatelessWidget {
  const ShimmerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
     return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              // 1. Quick Actions Gateways (3 large vertical cards)
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                child: Row(
                  children: [
                    Expanded(child: _shimmerBox(double.infinity, 120)),
                    const SizedBox(width: 10),
                    Expanded(child: _shimmerBox(double.infinity, 120)),
                    const SizedBox(width: 10),
                    Expanded(child: _shimmerBox(double.infinity, 120)),
                  ],
                ),
              ),

              // 2. Promo Banner Carousel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: ShimmerLoading(
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              
              // 3. Saved Activity Banner Placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ShimmerLoading(
                  child: Container(
                    height: 70,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              // 4. Premium Category Grids (Title + 2x2 Grid)
              const SizedBox(height: 12),
              _buildShimmerPremiumGrid(),
              const SizedBox(height: 24),
              _buildShimmerPremiumGrid(),
              
              const SizedBox(height: 30),
           ]
        ),
     );
  }
  
  Widget _buildShimmerPremiumGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerLoading(
                child: Container(width: 120, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ),
              ShimmerLoading(
                child: Container(width: 60, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ShimmerLoading(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShimmerLoading(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ShimmerLoading(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShimmerLoading(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _shimmerBox(double width, double height) {
     return ShimmerLoading(
        child: Container(
           width: width,
           height: height,
           margin: const EdgeInsets.symmetric(horizontal: 5),
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(20),
           )
        )
     );
  }
}
