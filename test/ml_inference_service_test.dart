import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oasyara_1/features/nutrition/domain/models/ml_detection_models.dart';
import 'package:oasyara_1/features/nutrition/data/sources/ml_inference_service.dart';

void main() {
  group('MlDetectionModels & MlInferenceService Tests', () {
    test('MlPredictionResponse parses valid API JSON correctly', () {
      final jsonMap = {
        "status": "success",
        "image_size": [416, 416],
        "detection_count": 2,
        "inference_time_ms": 596.08,
        "detections": [
          {
            "canonical_label": "aloo tikki",
            "bbox": [1, 21, 140, 106],
            "yolo_class_name": "aloo tikki",
            "yolo_confidence": 0.5749,
            "mobilenet_class_name": "aloo tikki",
            "mobilenet_confidence": 0.5679
          },
          {
            "canonical_label": "daal",
            "bbox": [120, 162, 277, 253],
            "yolo_class_name": "aloo tikki",
            "yolo_confidence": 0.5573,
            "mobilenet_class_name": "daal",
            "mobilenet_confidence": 0.5375
          }
        ]
      };

      final response = MlPredictionResponse.fromJson(jsonMap);

      expect(response.status, 'success');
      expect(response.detectionCount, 2);
      expect(response.inferenceTimeMs, 596.08);
      expect(response.detections.length, 2);

      final item1 = response.detections[0];
      expect(item1.canonicalLabel, 'aloo tikki');
      expect(item1.hasLabelDiscrepancy, false);

      final item2 = response.detections[1];
      expect(item2.canonicalLabel, 'daal');
      expect(item2.hasLabelDiscrepancy, true);
    });

    test('MlInferenceService handles successful HTTP 200 response', () async {
      final mockClient = MockClient((request) async {
        final body = json.encode({
          "status": "success",
          "image_size": [300, 300],
          "detection_count": 1,
          "inference_time_ms": 120.0,
          "detections": [
            {
              "canonical_label": "chapati",
              "bbox": [0, 0, 100, 100],
              "yolo_class_name": "chapati",
              "yolo_confidence": 0.85,
              "mobilenet_class_name": "chapati",
              "mobilenet_confidence": 0.90
            }
          ]
        });
        return http.Response(body, 200);
      });

      final service = MlInferenceService(client: mockClient);
      final dummyFile = File('test_dummy_1.jpg');
      await dummyFile.writeAsBytes([1, 2, 3, 4]);

      try {
        final result = await service.predictMealImage(dummyFile);
        expect(result.status, 'success');
        expect(result.detections.first.canonicalLabel, 'chapati');
      } finally {
        try {
          if (await dummyFile.exists()) {
            await dummyFile.delete();
          }
        } catch (_) {}
      }
    });

    test('MlInferenceService handles HTTP 400 error response', () async {
      final mockClient = MockClient((request) async {
        final body = json.encode({"detail": "Uploaded file must be a valid image"});
        return http.Response(body, 400);
      });

      final service = MlInferenceService(client: mockClient);
      final dummyFile = File('test_dummy_2.jpg');
      await dummyFile.writeAsBytes([1, 2, 3, 4]);

      try {
        expect(
          () async => await service.predictMealImage(dummyFile),
          throwsA(isA<Exception>()),
        );
      } finally {
        try {
          if (await dummyFile.exists()) {
            await dummyFile.delete();
          }
        } catch (_) {}
      }
    });
  });
}
