import 'package:equatable/equatable.dart';

class MlDetectionItem extends Equatable {
  final String canonicalLabel;
  final List<int> bbox;
  final bool hasDisagreement;
  final bool isUncertain;
  final String yoloClassName;
  final double yoloConfidence;
  final String mobilenetClassName;
  final double mobilenetConfidence;

  const MlDetectionItem({
    required this.canonicalLabel,
    required this.bbox,
    required this.hasDisagreement,
    required this.isUncertain,
    required this.yoloClassName,
    required this.yoloConfidence,
    required this.mobilenetClassName,
    required this.mobilenetConfidence,
  });

  bool get hasLabelDiscrepancy =>
      hasDisagreement || yoloClassName.trim().toLowerCase() != mobilenetClassName.trim().toLowerCase();

  factory MlDetectionItem.fromJson(Map<String, dynamic> json) {
    final yoloName = json['yolo_class_name'] as String;
    final mobilenetName = json['mobilenet_class_name'] as String;
    return MlDetectionItem(
      canonicalLabel: json['canonical_label'] as String,
      bbox: List<int>.from(json['bbox']),
      hasDisagreement: json['has_disagreement'] as bool? ??
          (yoloName.trim().toLowerCase() != mobilenetName.trim().toLowerCase()),
      isUncertain: json['is_uncertain'] as bool? ?? false,
      yoloClassName: yoloName,
      yoloConfidence: (json['yolo_confidence'] as num).toDouble(),
      mobilenetClassName: mobilenetName,
      mobilenetConfidence: (json['mobilenet_confidence'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        canonicalLabel,
        bbox,
        hasDisagreement,
        isUncertain,
        yoloClassName,
        yoloConfidence,
        mobilenetClassName,
        mobilenetConfidence,
      ];
}

class MlPredictionResponse extends Equatable {
  final String status;
  final int detectionCount;
  final double inferenceTimeMs;
  final List<MlDetectionItem> detections;

  const MlPredictionResponse({
    required this.status,
    required this.detectionCount,
    required this.inferenceTimeMs,
    required this.detections,
  });

  factory MlPredictionResponse.fromJson(Map<String, dynamic> json) {
    return MlPredictionResponse(
      status: json['status'] as String,
      detectionCount: (json['detection_count'] as num).toInt(),
      inferenceTimeMs: (json['inference_time_ms'] as num).toDouble(),
      detections: (json['detections'] as List)
          .map((e) => MlDetectionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [status, detectionCount, inferenceTimeMs, detections];
}
