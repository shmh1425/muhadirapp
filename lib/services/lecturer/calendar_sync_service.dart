import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Realtime notifier for calendar-related backend changes.
/// Emits whenever academic calendar, terms, weeks, or exceptions change.
class CalendarSyncService {
  CalendarSyncService._();
  static final CalendarSyncService instance = CalendarSyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  bool _started = false;
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<void> watchChanges() {
    _ensureStarted();
    return _changes.stream;
  }

  void _ensureStarted() {
    if (_started) return;
    _started = true;

    _subscriptions.add(
      _firestore
          .collection('academic_calendar')
          .doc('current')
          .snapshots()
          .listen(_onAnyChange, onError: _onError),
    );

    _subscriptions.add(
      _firestore
          .collection('academic_terms')
          .snapshots()
          .listen(_onAnyChange, onError: _onError),
    );

    _subscriptions.add(
      _firestore
          .collectionGroup('calendar_exceptions')
          .snapshots()
          .listen(_onAnyChange, onError: _onError),
    );

    _subscriptions.add(
      _firestore
          .collectionGroup('weeks')
          .snapshots()
          .listen(_onAnyChange, onError: _onError),
    );
  }

  void _onAnyChange(dynamic _) {
    final now = DateTime.now();
    if (now.difference(_lastEmit).inMilliseconds < 250) {
      return;
    }
    _lastEmit = now;
    debugPrint('[CalendarSyncService] calendar backend change detected');
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    debugPrint('[CalendarSyncService] listener error: $error');
  }
}
