import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/verification_repository.dart';
import 'verification_event.dart';
import 'verification_state.dart';

class VerificationBloc extends Bloc<VerificationEvent, VerificationState> {
  final VerificationRepository repository;

  VerificationBloc({required this.repository}) : super(VerificationInitial()) {
    on<StartVerification>((event, emit) {
      emit(VerificationCapturing());
    });

    on<CaptureFrontID>((event, emit) {
      // Temporarily hold the front image and wait for back image
      emit(VerificationFrontCaptured(event.imagePath));
    });

    on<CaptureBackID>((event, emit) async {
      emit(VerificationAnalyzingLocal());
      
      // We need to retrieve the front image from the current state
      if (state is VerificationFrontCaptured) {
        final frontPath = (state as VerificationFrontCaptured).frontImagePath;
        // Move to upload phase with both images
        add(UploadIDs(frontPath, event.imagePath));
      } else {
        emit(const VerificationOCRFailed('فقدت بيانات الوجه الأمامي! يرجى إعادة المحاولة.'));
      }
    });

    on<UploadIDs>((event, emit) async {
      emit(VerificationUploading());
      try {
        final frontUrl = await repository.getPresignedUrl();
        await repository.uploadImageToPresignedUrl(frontUrl, event.frontImagePath);
        
        final backUrl = await repository.getPresignedUrl();
        await repository.uploadImageToPresignedUrl(backUrl, event.backImagePath);
        
        add(RunDualOCR(frontUrl, backUrl)); 
      } catch (e) {
        // Log technical error purely to console
        print('Upload Technical Error: $e');
        // Show friendly bank-grade error message to user
        emit(const VerificationOCRFailed('حدث خطأ في الاتصال أثناء التحقق من هويتك. يرجى المحاولة مرة أخرى.'));
      }
    });

    on<RunDualOCR>((event, emit) async {
      emit(VerificationOCRProcessing());
      try {
        final data = await repository.extractOCRData(event.frontS3Key, event.backS3Key);
        emit(VerificationOCRSuccess(data));
      } catch (e) {
        emit(VerificationOCRFailed('فشل التعرف على هوية البطاقة، تأكد من وضوح الصورة وتصوير الوجهين.'));
      }
    });

    on<StartLiveness>((event, emit) {
      emit(VerificationLivenessProcessing());
    });

    on<FaceMatch>((event, emit) async {
      emit(VerificationLivenessProcessing());
      try {
        final success = await repository.verifyFaceMatch(event.livenessSessionId);
        if (success) {
          emit(VerificationFaceMatchSuccess());
        } else {
          emit(VerificationFaceMatchFailed());
        }
      } catch (e) {
        emit(VerificationFaceMatchFailed());
      }
    });

    on<SubmitVerification>((event, emit) async {
      emit(VerificationPending());
      try {
        final success = await repository.submitVerification(event.finalData);
        if (success) {
          emit(VerificationVerified());
        } else {
          emit(const VerificationRejected('Backend validation rejected securely.'));
        }
      } catch (e) {
        emit(VerificationRejected(e.toString()));
      }
    });
  }
}
