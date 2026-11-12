import '../services/tflite_service.dart';

class StableFrameTracker {
  StableFrameTracker({
    required this.requiredFrames,
    required this.minimumConfidence,
  });

  final int requiredFrames;
  final double minimumConfidence;

  int _matchedFrames = 0;
  String? _label;
  LivePrediction? _best;

  int get matchedFrames => _matchedFrames;

  LivePrediction? add(LivePrediction prediction) {
    final best = prediction.best;

    if (best.confidence < minimumConfidence) {
      reset();
      return null;
    }

    if (best.value != _label) {
      _label = best.value;
      _matchedFrames = 1;
      _best = prediction;
      return null;
    }

    _matchedFrames += 1;
    if (_best == null || best.confidence > _best!.best.confidence) {
      _best = prediction;
    }

    if (_matchedFrames < requiredFrames) {
      return null;
    }

    return _best;
  }

  void reset() {
    _matchedFrames = 0;
    _label = null;
    _best = null;
  }
}
