import 'package:equatable/equatable.dart';

abstract class VerificationEvent extends Equatable {
  const VerificationEvent();

  @override
  List<Object?> get props => [];
}

class StartVerification extends VerificationEvent {}

class CaptureFrontID extends VerificationEvent {
  final String imagePath;
  const CaptureFrontID(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

class CaptureBackID extends VerificationEvent {
  final String imagePath;
  const CaptureBackID(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

class UploadIDs extends VerificationEvent {
  final String frontImagePath;
  final String backImagePath;
  const UploadIDs(this.frontImagePath, this.backImagePath);

  @override
  List<Object?> get props => [frontImagePath, backImagePath];
}

class RunDualOCR extends VerificationEvent {
  final String frontS3Key;
  final String backS3Key;
  const RunDualOCR(this.frontS3Key, this.backS3Key);

  @override
  List<Object?> get props => [frontS3Key, backS3Key];
}

class StartLiveness extends VerificationEvent {}

class FaceMatch extends VerificationEvent {
  final String livenessSessionId;
  const FaceMatch(this.livenessSessionId);

  @override
  List<Object?> get props => [livenessSessionId];
}

class SubmitVerification extends VerificationEvent {
  final Map<String, dynamic> finalData;
  const SubmitVerification(this.finalData);

  @override
  List<Object?> get props => [finalData];
}
