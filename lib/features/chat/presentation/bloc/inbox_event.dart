// frontend/lib/features/chat/presentation/bloc/inbox_event.dart
import 'package:equatable/equatable.dart';

abstract class InboxEvent extends Equatable {
  const InboxEvent();

  @override
  List<Object?> get props => [];
}

class LoadInboxThreads extends InboxEvent {}
