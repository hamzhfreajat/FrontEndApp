import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/public/trust_summary_card.dart';
import '../widgets/public/review_tags_section.dart';
import '../widgets/public/seller_stats_row.dart';
import '../widgets/public/seller_policy_card.dart';
import '../widgets/public/ads_preview_section.dart';
import '../widgets/shared/verification_badges.dart';
import '../../../../widgets/shimmer_loading.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String initialName;

  const PublicProfileScreen({
    Key? key,
    required this.userId,
    this.initialName = 'المعلن',
  }) : super(key: key);

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(LoadProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.loading && state.profile == null) {
            return const ShimmerList();
          }

          if (state.status == ProfileStatus.error && state.profile == null) {
            return Center(child: Text(state.errorMessage ?? 'حدث خطأ غير متوقع'));
          }

          final profile = state.profile;
          if (profile == null) return const SizedBox.shrink();

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ProfileBloc>().add(LoadProfile());
              await context.read<ProfileBloc>().stream.firstWhere((s) => s.status != ProfileStatus.loading);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                _buildSliverAppBar(context, profile),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        _buildHeaderInfo(profile),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: VerificationBadges(
                            isEmailVerified: profile.isEmailVerified,
                            isPhoneVerified: profile.isPhoneVerified,
                            isIdentityVerified: profile.isIdentityVerified,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TrustSummaryCard(profile: profile),
                        ),
                        const SizedBox(height: 24),
                        SellerStatsRow(profile: profile),
                        const SizedBox(height: 32),
                        ReviewTagsSection(tags: profile.reviewTags),
                        const SizedBox(height: 32),
                        SellerPolicyCard(profile: profile),
                        SizedBox(height: profile.isBusiness ? 32 : 0),
                        AdsPreviewSection(title: 'إعلانات ${profile.name}', ads: state.ads, userId: profile.id),
                        const SizedBox(height: 120), // Bottom padding
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildActionRow(),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, profile) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      title: Text(
        profile.name,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHeaderInfo(profile) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
                ),
              ),
              child: profile.coverImage.isNotEmpty
                  ? Image.network(profile.coverImage, fit: BoxFit.cover)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 20, left: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 100, height: 35),
                  const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isIdentityVerified)
                          const Icon(Icons.verified_rounded, color: Colors.blue, size: 22),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.grey.shade500, size: 14),
                        const SizedBox(width: 4),
                        Text(profile.location, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: Colors.green.shade500, size: 14),
                        const SizedBox(width: 4),
                        Text(profile.replyTimeLabel, style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    Positioned(
          top: 120 - 45, // Cover height minus half avatar
          right: 20,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
              ],
              image: DecorationImage(image: CachedNetworkImageProvider(profile.avatar), fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          top: 120 + 12,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: profile.isBusiness ? Colors.amber.shade100 : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              profile.isBusiness ? 'حساب أعمال' : 'بائع شخصي',
              style: TextStyle(
                color: profile.isBusiness ? Colors.amber.shade900 : Colors.blue.shade900,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        final profile = state.profile;
        if (profile == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(20).copyWith(bottom: MediaQuery.of(context).padding.bottom + 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: profile.isBotOrScraper ? 1 : 2,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('محادثة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              if (!profile.isBotOrScraper) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone_rounded),
                    label: const Text('اتصال'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A2E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => context.read<ProfileBloc>().add(ToggleFollow()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: state.isFollowing ? const Color(0xFF1A73E8).withValues(alpha: 0.1) : Colors.white,
                      border: Border.all(color: state.isFollowing ? const Color(0xFF1A73E8) : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      state.isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                      color: state.isFollowing ? const Color(0xFF1A73E8) : const Color(0xFF1A1A2E),
                    ),
                  ),
                )
              ],
            ],
          ),
        );
      },
    );
  }
}
