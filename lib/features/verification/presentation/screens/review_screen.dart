import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/verification_bloc.dart';
import '../bloc/verification_event.dart';
import '../bloc/verification_state.dart';

class ReviewScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ReviewScreen({Key? key, required this.data}) : super(key: key);

  String _maskNationalId(String? id) {
    if (id == null || id.length < 10) return '???-????-???';
    return '${id.substring(0, 3)}-XXXX-${id.substring(id.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('مراجعة البيانات المستخرجة', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocConsumer<VerificationBloc, VerificationState>(
        listener: (context, state) {
          if (state is VerificationVerified) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم التحقق بنجاح!'), backgroundColor: Colors.green),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is VerificationRejected) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('الرفض: ${state.reason}'), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildDataRow('الاسم الكامل', data['fullName'] ?? ''),
                      const Divider(height: 30),
                      _buildDataRow('الرقم الوطني', _maskNationalId(data['nationalId'])),
                      const Divider(height: 30),
                      _buildDataRow('تاريخ الميلاد', data['dateOfBirth'] ?? ''),
                      const Divider(height: 30),
                      _buildDataRow('تاريخ الانتهاء', data['expiryDate'] ?? ''),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                if (state is VerificationPending)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)))
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      context.read<VerificationBloc>().add(SubmitVerification(data));
                    },
                    child: const Text('تأكيد وإرسال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                
                const SizedBox(height: 16),
                
                if (state is! VerificationPending)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back or completely restart flow
                    },
                    child: const Text('إعادة التقاط الصورة', style: TextStyle(color: Colors.red, fontSize: 16)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        Text(value, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
