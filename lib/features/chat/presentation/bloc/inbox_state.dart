// frontend/lib/features/chat/presentation/bloc/inbox_state.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/inbox_thread.dart';

abstract class InboxState extends Equatable {
  const InboxState();
  
  @override
  List<Object?> get props => [];
}

class InboxInitial extends InboxState {}
class InboxLoading extends InboxState {}

class InboxLoaded extends InboxState {
  final List<InboxThread> threads;

  const InboxLoaded({required this.threads});

  @override
  List<Object?> get props => [threads];
}

class InboxError extends InboxState {
  final String message;
  const InboxError(this.message);

  @override
  List<Object?> get props => [message];
}
