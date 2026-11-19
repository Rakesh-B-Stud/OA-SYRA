import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../../core/config/api_config.dart';
import '../../domain/models/ml_detection_models.dart';

class MlInferenceService {
  final http.Client _client;

  MlInferenceService({http.Client? client}) : _client = client ?? http.Client();

  MediaType _determineMediaType(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return MediaType('image', 'png');
    if (path.endsWith('.webp')) return MediaType('image', 'webp');
    if (path.endsWith('.gif')) return MediaType('image', 'gif');
    if (path.endsWith('.bmp')) return MediaType('image', 'bmp');
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return MediaType('image', 'jpeg');

    try {
      final bytes = file.readAsBytesSync();
      if (bytes.length >= 8) {
        if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
          return MediaType('image', 'png');
        }
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          return MediaType('image', 'jpeg');
        }
        if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
          return MediaType('image', 'webp');
        }
      }
    } catch (_) {}

    return MediaType('image', 'jpeg');
  }

  Future<MlPredictionResponse> predictMealImage(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.predictMealEndpoint),
      );

      final mediaType = _determineMediaType(imageFile);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: mediaType,
        ),
      );

      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MlPredictionResponse.fromJson(data as Map<String, dynamic>);
      } else {
        String errorMsg = 'Failed to analyze meal image (${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData.containsKey('detail')) {
            errorMsg = errorData['detail'].toString();
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Ensure backend server is running at ${ApiConfig.mlBaseUrl}');
    } on SocketException {
      throw Exception('Network error: Unable to connect to ${ApiConfig.mlBaseUrl}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An unexpected error occurred during image recognition: $e');
    }
  }
}
