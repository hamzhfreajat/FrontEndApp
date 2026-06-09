import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/verification/presentation/screens/document_selection_screen.dart';
import '../bloc/verification_bloc.dart';
import '../bloc/verification_event.dart';
import '../bloc/verification_state.dart';
import 'id_capture_screen.dart';
import 'review_screen.dart';

class CaptureInstructionScreen extends StatelessWidget {
  final DocumentType documentType;
  final bool isFront;
  final String? frontImagePath; // Used when we are on the 'back' instruction step
  final String title;

  const CaptureInstructionScreen({
    Key? key,
    required this.documentType,
    required this.isFront,
    this.frontImagePath,
    required this.title,
  }) : super(key: key);

  void _openCamera(BuildContext context) async {
    // Cache the bloc before the asynchronous gap
    final verificationBloc = context.read<VerificationBloc>();

    // Navigate to the pure camera capture screen
    final imagePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => IdCaptureScreen(isFrontMode: isFront),
      ),
    );

    if (imagePath != null && context.mounted) {
      if (documentType == DocumentType.passport || !isFront) {
        // We have completely finished capturing.
        // Passport only needs Front. Else, we are already on Back.
        verificationBloc.add(UploadIDs(
          frontImagePath ?? imagePath, 
          isFront ? 'none' : imagePath, // Passport backend handles 'none' safely, or upload identical
        ));
      } else {
        // We just captured the front of a 2-sided document.
        // Navigate to the instruction screen for the BACK side!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (ctx) => BlocProvider.value(
              value: verificationBloc,
              child: CaptureInstructionScreen(
                documentType: documentType,
                isFront: false,
                frontImagePath: imagePath,
                title: title,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String instructionTitle = isFront ? 'تصوير الجهة الأمامية' : 'تصوير الجهة الخلفية';
    String instructionDesc = isFront 
      ? 'يرجى وضع الجهة الأمامية للوثيقة في إطار الكاميرا والتأكد من وضوح النصوص والإضاءة.' 
      : 'عظيم! الآن يرجى قلب الوثيقة وتصوير الجهة الخلفية بوضوح.';

    if (documentType == DocumentType.passport) {
      instructionTitle = 'تصوير جواز السفر';
      instructionDesc = 'يرجى فتح صفحة البيانات في جواز السفر ووضعها في الإطار والتأكد من وضوح جميع النصوص.';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: isFront ? IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ) : null, // Prevent going back from the back-capture screen smoothly without aborting completely
      ),
      body: BlocConsumer<VerificationBloc, VerificationState>(
        listener: (context, state) {
          if (state is VerificationOCRSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم استخراج البيانات بنجاح!'), backgroundColor: Colors.green),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<VerificationBloc>(),
                  child: ReviewScreen(data: state.extractedData),
                ),
              ),
            );
          } else if (state is VerificationOCRFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          final isProcessing = state is VerificationUploading || state is VerificationOCRProcessing;

          if (isProcessing) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Color(0xFF1A73E8)),
                  SizedBox(height: 24),
                  Text(
                    'جاري الرفع وتحليل البيانات سحابياً...\nيرجى الانتظار لحين الانتهاء',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  isFront ? Icons.credit_card : Icons.credit_card_outlined, 
                  size: 100, 
                  color: const Color(0xFF1A73E8)
                ),
                const SizedBox(height: 32),
                Text(
                  instructionTitle,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  instructionDesc,
                  style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _openCamera(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('ابدأ التصوير', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
