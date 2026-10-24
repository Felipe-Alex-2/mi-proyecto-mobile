import 'package:flutter/foundation.dart';

/// Requests already sent may finish after logout disposes the session scope.
/// Their results must never notify a discarded session's listeners.
class SesionNotifier extends ChangeNotifier {
  bool _sessionDisposed = false;

  @override
  void notifyListeners() {
    if (!_sessionDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _sessionDisposed = true;
    super.dispose();
  }
}
