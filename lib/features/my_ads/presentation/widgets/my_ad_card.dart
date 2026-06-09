import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/my_ad_entities.dart';
import 'status_badge.dart';
import '../../../../services/api_service.dart';
import 'package:intl/intl.dart';

class MyAdCard extends StatelessWidget {
  final MyAd ad;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onActionTap;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final VoidCallback? onRepublishTap;

  const MyAdCard({
    Key? key,
    required this.ad,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onActionTap,
    required this.onLongPress,
    required this.onTap,
    this.onRepublishTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: isSelectionMode ? onTap : () {
        // Navigate to details usually, or ignore here
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F5FE) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A73E8) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRuttaImage(ad.baseAd.imageUrl),
                const SizedBox(width: 12),
                Expanded(child: _buildAdDetails(context)),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onPressed: onActionTap,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildPerformanceRow(context),
          if (ad.status == 'Active') ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            RepublishTimerButton(
              lastRepublishedAt: ad.baseAd.lastRepublishedAt ?? ad.baseAd.createdAt ?? DateTime.now().subtract(const Duration(days: 1)),
              onRepublish: onRepublishTap,
            ),
          ],
        ],
        ),
        if (isSelectionMode)
          Positioned(
            top: 8,
            right: 8,
            child: Checkbox(
              value: isSelected,
              activeColor: const Color(0xFF1A73E8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (_) => onTap(),
            ),
          ),
      ],
    ),
  ),
);
  }

  Widget _buildAdDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusBadge(status: ad.status, isBoosted: ad.isBoosted),
        const SizedBox(height: 8),
        Text(
          ad.baseAd.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          '${ad.baseAd.price} JOD',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A73E8),
            fontSize: 14,
          ),
        ),
        if (ad.baseAd.createdAt != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'تاريخ النشر: ${DateFormat('yyyy-MM-dd • hh:mm a').format(ad.baseAd.createdAt!)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (ad.baseAd.lastRepublishedAt != null && ad.baseAd.lastRepublishedAt != ad.baseAd.createdAt) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.update_rounded, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'تاريخ التحديث: ${DateFormat('yyyy-MM-dd • hh:mm a').format(ad.baseAd.lastRepublishedAt!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
        if (ad.suggestedAction != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline, size: 12, color: Colors.blue),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    ad.suggestedAction!,
                    style: TextStyle(fontSize: 11, color: Colors.blue[800]),
                  ),
                ),
              ],
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildPerformanceRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(icon: Icons.remove_red_eye_outlined, value: ad.baseAd.views.toString(), label: 'Views'),
          _Stat(icon: Icons.chat_bubble_outline, value: ad.chatsCount.toString(), label: 'Chats'),
          _Stat(icon: Icons.favorite_border, value: ad.favoritesCount.toString(), label: 'Favs'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

class ClipRuttaImage extends StatelessWidget {
  final String? url;
  const ClipRuttaImage(this.url, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 80,
        color: Colors.grey[100],
        child: url != null && url!.isNotEmpty
            ? ApiService.networkImage(url!)
            : const Icon(Icons.image, color: Colors.grey),
      ),
    );
  }
}

class ActionBottomSheet {
  static void show(BuildContext context, {required String adTitle, required String status, required Function(String action) onActionSelected}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(child: Text(adTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
              ),
              _Item(icon: Icons.edit_rounded, text: 'تعديل الإعلان', onTap: () { Navigator.pop(ctx); onActionSelected('edit'); }),
              if (status != 'Paused' && status != 'Sold' && status != 'Expired')
                _Item(icon: Icons.pause_circle_outline_rounded, text: 'إيقاف الإعلان', onTap: () { Navigator.pop(ctx); onActionSelected('pause'); }),
              if (status == 'Paused' || status == 'Expired')
                _Item(icon: Icons.play_circle_outline_rounded, text: 'تفعيل الإعلان', onTap: () { Navigator.pop(ctx); onActionSelected('resume'); }),
              if (status != 'Sold')
                _Item(icon: Icons.sell_outlined, text: 'تم البيع', onTap: () { Navigator.pop(ctx); onActionSelected('sold'); }),
              _Item(icon: Icons.delete_outline_rounded, text: 'حذف الإعلان', color: const Color(0xFFE53935), onTap: () { Navigator.pop(ctx); onActionSelected('delete'); }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final VoidCallback onTap;

  const _Item({required this.icon, required this.text, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color ?? const Color(0xFF4A4A4A), size: 24),
              const SizedBox(width: 16),
              Text(text, style: TextStyle(color: color ?? const Color(0xFF1A1A2E), fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
class RepublishTimerButton extends StatefulWidget {
  final DateTime lastRepublishedAt;
  final VoidCallback? onRepublish;

  const RepublishTimerButton({Key? key, required this.lastRepublishedAt, this.onRepublish}) : super(key: key);

  @override
  State<RepublishTimerButton> createState() => _RepublishTimerButtonState();
}

class _RepublishTimerButtonState extends State<RepublishTimerButton> {
  Timer? _timer;
  late Duration _remaining;
  bool _canRepublish = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    if (!_canRepublish) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateRemaining());
    }
  }

  @override
  void didUpdateWidget(covariant RepublishTimerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastRepublishedAt != widget.lastRepublishedAt) {
      _calculateRemaining();
    }
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final target = widget.lastRepublishedAt.add(const Duration(hours: 24));
    
    if (now.isAfter(target)) {
      if (!_canRepublish) {
        setState(() {
          _canRepublish = true;
          _remaining = Duration.zero;
        });
        _timer?.cancel();
      }
    } else {
      setState(() {
        _canRepublish = false;
        _remaining = target.difference(now);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(d.inHours);
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _canRepublish ? const Color(0xFF1A73E8) : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
          boxShadow: _canRepublish ? [
            BoxShadow(color: const Color(0xFF1A73E8).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _canRepublish ? widget.onRepublish : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _canRepublish ? Icons.refresh_rounded : Icons.access_time_rounded,
                    color: _canRepublish ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _canRepublish ? 'إعادة النشر الآن' : 'إعادة النشر متاح بعد ${_formatDuration(_remaining)}',
                    style: TextStyle(
                      color: _canRepublish ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
