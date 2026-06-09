import 'package:equatable/equatable.dart';

abstract class VerificationState extends Equatable {
  const VerificationState();

  @override
  List<Object?> get props => [];
}

class VerificationInitial extends VerificationState {}

class VerificationCapturing extends VerificationState {}

class VerificationFrontCaptured extends VerificationState {
  final String frontImagePath;
  const VerificationFrontCaptured(this.frontImagePath);
  @override
  List<Object?> get props => [frontImagePath];
}

class VerificationAnalyzingLocal extends VerificationState {}

class VerificationInvalidLocal extends VerificationState {
  final String reason;
  const VerificationInvalidLocal(this.reason);
  @override
  List<Object?> get props => [reason];
}

class VerificationUploading extends VerificationState {}

class VerificationOCRProcessing extends VerificationState {}

class VerificationOCRSuccess extends VerificationState {
  final Map<String, dynamic> extractedData;
  const VerificationOCRSuccess(this.extractedData);
  @override
  List<Object?> get props => [extractedData];
}

class VerificationOCRFailed extends VerificationState {
  final String error;
  const VerificationOCRFailed(this.error);
  @override
  List<Object?> get props => [error];
}

class VerificationLivenessProcessing extends VerificationState {}

class VerificationFaceMatchSuccess extends VerificationState {}

class VerificationFaceMatchFailed extends VerificationState {}

class VerificationPending extends VerificationState {}

class VerificationVerified extends VerificationState {}

class VerificationRejected extends VerificationState {
  final String reason;
  const VerificationRejected(this.reason);
  @override
  List<Object?> get props => [reason];
}
