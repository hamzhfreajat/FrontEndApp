import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/verification_bloc.dart';
import '../bloc/verification_event.dart';
import '../bloc/verification_state.dart';
import 'review_screen.dart';

class LivenessScreen extends StatefulWidget {
  final Map<String, dynamic> ocrData;
  const LivenessScreen({Key? key, required this.ocrData}) : super(key: key);

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> {
  // Normally AWS Amplify `FaceLivenessDetector` goes here.
  // We mock the flow for the initial integration.
  
  @override
  void initState() {
    super.initState();
    // Simulate AWS Amplify Face Liveness flow completing successfully
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        context.read<VerificationBloc>().add(const FaceMatch('mock-session-123'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<VerificationBloc, VerificationState>(
        listener: (context, state) {
          if (state is VerificationFaceMatchSuccess) {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(
                builder: (_) => ReviewScreen(data: widget.ocrData)
              )
            );
          } else if (state is VerificationFaceMatchFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('فشل التعرف على الوجه. يرجى المحاولة مرة أخرى.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
            );
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Simulated AWS Oval Outline
                Container(
                  width: 250,
                  height: 350,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(150),
                    border: Border.all(color: const Color(0xFF1A73E8), width: 5),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_outline, size: 100, color: Colors.white54),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                const Text(
                  'انظر إلى الكاميرا مباشرة وتحرك ببطء للاقتراب',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                if (state is VerificationLivenessProcessing)
                  const CircularProgressIndicator(color: Color(0xFF1A73E8)),
                  
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}
