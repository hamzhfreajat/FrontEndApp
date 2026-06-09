import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user_profile.dart';
import '../../../../verification/presentation/bloc/verification_bloc.dart';
import '../../../../verification/presentation/screens/document_selection_screen.dart';
import '../../../../verification/presentation/screens/id_capture_screen.dart';
import '../../../../verification/data/repositories/verification_repository.dart';

class ProfileCompletionWidget extends StatefulWidget {
  final UserProfile profile;

  const ProfileCompletionWidget({Key? key, required this.profile}) : super(key: key);

  @override
  State<ProfileCompletionWidget> createState() => _ProfileCompletionWidgetState();
}

class _ProfileCompletionWidgetState extends State<ProfileCompletionWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final double completionPercentage = widget.profile.completionPercentage;
    int percentageInt = (completionPercentage * 100).toInt();
    bool isComplete = percentageInt >= 100;
    
    // We conditionally take all missing points or just 3
    final allMissing = widget.profile.missingCompletionPoints;
    List<String> missingPoints = _expanded ? allMissing : allMissing.take(3).toList();
    int remainingCount = allMissing.length - missingPoints.length;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isComplete 
              ? [const Color(0xFF0F9D58).withValues(alpha: 0.1), const Color(0xFF0D946A).withValues(alpha: 0.02)] 
              : [const Color(0xFF1A73E8).withValues(alpha: 0.08), const Color(0xFF1A73E8).withValues(alpha: 0.01)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isComplete ? const Color(0xFF0F9D58).withValues(alpha: 0.3) : const Color(0xFF1A73E8).withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: completionPercentage),
                duration: const Duration(seconds: 1),
                curve: Curves.fastOutSlowIn,
                builder: (context, value, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 55,
                        height: 55,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 6,
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete ? const Color(0xFF0F9D58) : const Color(0xFF1A73E8),
                          ),
                        ),
                      ),
                      Text(
                        '${(value * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 13,
                          color: isComplete ? const Color(0xFF0F9D58) : const Color(0xFF1A73E8),
                        ),
                      ),
                    ],
                  );
                }
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete ? 'اكتمل ملفك الشخصي' : 'أكمل ملفك الشخصي',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isComplete 
                        ? 'ممتاز! ملفك جاهز وتمتلك ثقة المشترين كلياً.'
                        : 'أكمل بياناتك المتبقية لتعزيز ثقة المشترين فيك وزيادة مبيعاتك.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              )
            ],
          ),
          
          if (!isComplete && missingPoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white, thickness: 2),
            const SizedBox(height: 12),
            const Text(
              'ينقصك لتكتمل مبيعاتك:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1557B0)),
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...missingPoints.map((point) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF1A73E8)),
                        const SizedBox(width: 6),
                        Text(point, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1557B0))),
                      ],
                    ),
                  )),
                  if (remainingCount > 0)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _expanded = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        child: Text('و $remainingCount آخرين...', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ],
          
          if (!widget.profile.isIdentityVerified) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F9D58), Color(0xFF0D946A)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F9D58).withValues(alpha: 0.3),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => VerificationBloc(
                            repository: VerificationRepository(),
                          ),
                          child: const DocumentSelectionScreen(),
                        ),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'وثّق هويتك الآن',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'احصل على شارة الثقة الخضراء وضاعف مبيعاتك!',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
