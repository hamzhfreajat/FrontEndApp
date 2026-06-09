import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:classifieds_frontend/features/verification/presentation/bloc/verification_bloc.dart';
import 'capture_instruction_screen.dart';

enum DocumentType { nationalId, drivingLicense, passport }

class DocumentSelectionScreen extends StatelessWidget {
  const DocumentSelectionScreen({Key? key}) : super(key: key);

  void _onSelect(BuildContext context, DocumentType type, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => BlocProvider.value(
          value: context.read<VerificationBloc>(),
          child: CaptureInstructionScreen(
            documentType: type,
            isFront: true,
            frontImagePath: null,
            title: title,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('نوع الوثيقة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر نوع الوثيقة لتوثيق هويتك',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            const Text(
              'اختر وثيقة رسمية سارية المفعول لتتمكن من إتمام عملية التوثيق بشكل صحيح.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 32),
            _buildOptionCard(
              context,
              title: 'الهوية الشخصية (الوطنية)',
              icon: Icons.badge_outlined,
              type: DocumentType.nationalId,
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              title: 'رخصة القيادة',
              icon: Icons.drive_eta_outlined,
              type: DocumentType.drivingLicense,
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              title: 'جواز السفر',
              icon: Icons.menu_book_outlined,
              type: DocumentType.passport,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {required String title, required IconData icon, required DocumentType type}) {
    return InkWell(
      onTap: () => _onSelect(context, type, title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_back_ios, size: 16, color: Colors.grey.shade400),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1A73E8), size: 28),
            ),
          ],
        ),
      ),
    );
  }
}
