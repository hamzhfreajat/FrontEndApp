// frontend/lib/features/chat/presentation/screens/premium_inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui' as dart_ui;
import '../bloc/inbox_bloc.dart';
import '../bloc/inbox_event.dart';
import '../bloc/inbox_state.dart';
import '../widgets/chat_theme.dart';
import '../widgets/inbox_thread_tile.dart';

import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../data/repositories/firebase_chat_repository.dart';
import '../../domain/entities/inbox_thread.dart';
import 'premium_chat_screen.dart';
import '../../../../services/analytics_engine.dart';

class PremiumInboxScreen extends StatelessWidget {
  const PremiumInboxScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.userData?['sub']?.toString() ?? '';

    return BlocProvider(
      create: (context) => InboxBloc(
        repository: FirebaseChatRepository(),
        currentUserId: currentUserId,
      )..add(LoadInboxThreads()),
      child: const _InboxView(),
    );
  }
}

class _InboxView extends StatefulWidget {
  const _InboxView({Key? key}) : super(key: key);

  @override
  State<_InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<_InboxView> {
  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'premium_inbox_screen');
  }

  String _searchQuery = '';
  String _activeTab = 'الكل';
  Set<String> _selectedThreadIds = {};
  bool _isProcessing = false;

  bool get _isSelectionMode => _selectedThreadIds.isNotEmpty;

  void _toggleSelection(String threadId) {
    if (_isProcessing) return;
    setState(() {
      if (_selectedThreadIds.contains(threadId)) {
        _selectedThreadIds.remove(threadId);
      } else {
        _selectedThreadIds.add(threadId);
      }
    });
  }

  void _clearSelection() {
    if (_isProcessing) return;
    setState(() {
      _selectedThreadIds.clear();
    });
  }

  Future<void> _bulkDelete(String currentUserId) async {
    setState(() => _isProcessing = true);
    final repo = FirebaseChatRepository();
    for (String id in _selectedThreadIds) {
      await repo.deleteChat(id, currentUserId);
    }
    setState(() {
      _selectedThreadIds.clear();
      _isProcessing = false;
    });
  }

  Future<void> _bulkFavorite(String currentUserId, List<InboxThread> allThreads) async {
    setState(() => _isProcessing = true);
    
    final selectedThreads = allThreads.where((t) => _selectedThreadIds.contains(t.threadId)).toList();
    final allAreFavorites = selectedThreads.every((t) => t.isFavorite);
    final targetFavoriteState = !allAreFavorites;

    final repo = FirebaseChatRepository();
    for (String id in _selectedThreadIds) {
      await repo.toggleFavoriteStatus(id, currentUserId, targetFavoriteState);
    }
    
    setState(() {
      _selectedThreadIds.clear();
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: ChatTheme.scaffoldBackground(context),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: BlocBuilder<InboxBloc, InboxState>(
          builder: (context, state) {
            if (state is InboxLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is InboxError) {
              return Center(child: Text(state.message));
            }

            if (state is InboxLoaded) {
              // Apply filters
              var filteredThreads = state.threads.where((t) {
                // Search filter
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  if (!t.otherUserName.toLowerCase().contains(query) && 
                      !t.adTitle.toLowerCase().contains(query)) {
                    return false;
                  }
                }
                
                // Tab filter
                if (_activeTab == 'غير مقروءة') {
                  if (t.unreadCount == 0) return false;
                } else if (_activeTab == 'المفضلة') {
                  if (!t.isFavorite) return false;
                }
                
                return true;
              }).toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverAppBar(
                    floating: true,
                    pinned: true,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    backgroundColor: _isSelectionMode ? (isDark ? const Color(0xFF1F2C34) : Colors.blue.shade50) : (isDark ? const Color(0xFF0B141A) : Colors.white),
                    leading: _isSelectionMode ? IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
                      onPressed: _clearSelection,
                    ) : null,
                    title: _isSelectionMode 
                      ? Text('${_selectedThreadIds.length} تم التحديد', style: ChatTheme.font(context, size: 20, weight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87))
                      : Text('الرسائل', style: ChatTheme.font(context, size: 24, weight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                    actions: _isSelectionMode ? [
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          final currentUserId = authProvider.userData?['sub']?.toString() ?? '';
                          return Row(
                            children: [
                              if (_isProcessing)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: SizedBox(
                                    width: 20, height: 20, 
                                    child: CircularProgressIndicator(strokeWidth: 2)
                                  ),
                                )
                              else ...[
                                IconButton(
                                  icon: Icon(Icons.star_rounded, color: isDark ? Colors.white : Colors.black87),
                                  onPressed: () => _bulkFavorite(currentUserId, state.threads),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return Directionality(
                                          textDirection: TextDirection.rtl,
                                          child: AlertDialog(
                                            title: Text('حذف المحادثات', style: ChatTheme.font(context, size: 20, weight: FontWeight.bold)),
                                            content: Text('هل أنت متأكد أنك تريد حذف ${_selectedThreadIds.length} محادثة؟', style: ChatTheme.font(context, size: 16)),
                                            actions: [
                                              TextButton(
                                                child: Text('إلغاء', style: ChatTheme.font(context, size: 16, color: Colors.grey)),
                                                onPressed: () => Navigator.of(context).pop(),
                                              ),
                                              TextButton(
                                                child: Text('حذف', style: ChatTheme.font(context, size: 16, color: Colors.red, weight: FontWeight.bold)),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _bulkDelete(currentUserId);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ]
                            ],
                          );
                        }
                      ),
                    ] : [
                      IconButton(
                        icon: Icon(Icons.support_agent_rounded, color: isDark ? Colors.white : Colors.black87), 
                        onPressed: () {
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final currentUserId = authProvider.userData?['sub']?.toString() ?? '';
                          if (currentUserId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('يرجى تسجيل الدخول أولاً'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumChatScreen(
                            adId: 'support',
                            adTitle: 'خدمة العملاء',
                            adPrice: '',
                            adImageUrl: '',
                            currentUserId: currentUserId,
                            currentUserName: authProvider.userData?['name']?.toString() ?? 'مستخدم',
                            currentUserPhone: authProvider.userData?['phone_number']?.toString(),
                            otherUserId: 'admin',
                            otherUserName: 'فريق الدعم',
                            isSeller: false,
                          )));
                        }
                      ),
                      IconButton(icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black87), onPressed: () {}),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                Icon(Icons.search, color: Colors.grey.shade500, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    onChanged: (val) {
                                      setState(() {
                                        _searchQuery = val;
                                      });
                                    },
                                    style: ChatTheme.font(context, size: 16, weight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: 'بحث',
                                      hintStyle: ChatTheme.font(context, size: 16, weight: FontWeight.w500, color: Colors.grey.shade500),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Filter Pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              _buildFilterPill(context, 'الكل', _activeTab == 'الكل', isDark),
                              const SizedBox(width: 8),
                              _buildFilterPill(context, 'غير مقروءة', _activeTab == 'غير مقروءة', isDark, count: state.threads.where((t) => t.unreadCount > 0).length),
                              const SizedBox(width: 8),
                              _buildFilterPill(context, 'المفضلة', _activeTab == 'المفضلة', isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  if (filteredThreads.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'لا توجد نتائج', 
                          style: ChatTheme.font(context, size: 18, weight: FontWeight.w600, color: Colors.grey.shade500)
                        ),
                      )
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 8, bottom: 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final thread = filteredThreads[index];
                            return InboxThreadTile(
                              key: ValueKey(thread.threadId),
                              thread: thread, 
                              index: index,
                              isSelected: _selectedThreadIds.contains(thread.threadId),
                              isSelectionMode: _isSelectionMode,
                              onToggleSelect: () => _toggleSelection(thread.threadId),
                            );
                          },
                          childCount: filteredThreads.length,
                        ),
                      ),
                    ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
          title: Text('الرسائل', style: ChatTheme.font(context, size: 24, weight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 100, color: Colors.grey.shade300),
              const SizedBox(height: 24),
              Text('لا توجد رسائل', style: ChatTheme.font(context, size: 24, weight: FontWeight.w900, color: Colors.grey.shade800)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text('عندما تتواصل مع البائعين أو يتواصل معك المشترون، ستظهر الرسائل هنا.', 
                  textAlign: TextAlign.center,
                  style: ChatTheme.font(context, size: 15, weight: FontWeight.w600, color: Colors.grey.shade600, height: 1.5)
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(BuildContext context, String label, bool isActive, bool isDark, {int count = 0}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? null : (isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5)),
          gradient: isActive ? ChatTheme.primaryGradient(context) : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [BoxShadow(color: (isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 3))] : null
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: ChatTheme.font(context, size: 14, weight: isActive ? FontWeight.w700 : FontWeight.w600, 
                color: isActive ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withOpacity(0.2) : (isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: ChatTheme.font(context, size: 11, weight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
