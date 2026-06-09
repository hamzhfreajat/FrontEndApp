import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'inbox_event.dart';
import 'inbox_state.dart';
import '../../domain/entities/inbox_thread.dart';
import '../../data/repositories/firebase_chat_repository.dart';

class InboxBloc extends Bloc<InboxEvent, InboxState> {
  final FirebaseChatRepository repository;
  final String currentUserId;
  StreamSubscription<List<InboxThread>>? _inboxSubscription;

  InboxBloc({required this.repository, required this.currentUserId}) : super(InboxInitial()) {
    on<LoadInboxThreads>(_onLoadInboxThreads);
    on<_UpdateInboxThreads>(_onUpdateInboxThreads);
    on<_InboxErrorEvent>(_onInboxErrorEvent);
  }

  Future<void> _onLoadInboxThreads(LoadInboxThreads event, Emitter<InboxState> emit) async {
    emit(InboxLoading());
    await _inboxSubscription?.cancel();
    
    _inboxSubscription = repository.getInboxThreads(currentUserId).listen(
      (threads) {
        add(_UpdateInboxThreads(threads));
      },
      onError: (error) {
        add(_InboxErrorEvent("Error loading inbox: ${error.toString()}"));
      }
    );
  }

  void _onUpdateInboxThreads(_UpdateInboxThreads event, Emitter<InboxState> emit) {
    emit(InboxLoaded(threads: event.threads));
  }

  void _onInboxErrorEvent(_InboxErrorEvent event, Emitter<InboxState> emit) {
    emit(InboxError(event.message));
  }

  @override
  Future<void> close() {
    _inboxSubscription?.cancel();
    return super.close();
  }
}

class _UpdateInboxThreads extends InboxEvent {
  final List<InboxThread> threads;
  const _UpdateInboxThreads(this.threads);
  @override
  List<Object> get props => [threads];
}

class _InboxErrorEvent extends InboxEvent {
  final String message;
  const _InboxErrorEvent(this.message);
  @override
  List<Object> get props => [message];
}
