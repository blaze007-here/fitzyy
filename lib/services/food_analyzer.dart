import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_scan.dart';

abstract class FoodAnalyzer {
  Future<FoodScan> analyze({XFile? image});
}

/// Local stand-in for the vision model. Replace this with an on-device model
/// or a secure API adapter when production recognition is connected.
class MockFoodAnalyzer implements FoodAnalyzer {
  MockFoodAnalyzer({FoodScan? result}) : result = result ?? sampleScans[0];

  final FoodScan result;

  @override
  Future<FoodScan> analyze({XFile? image}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return result.copyWith(scannedAt: DateTime.now());
  }
}

/// Calls the Supabase Edge Function that owns the vision-model API key.
/// The mobile app sends the captured image, but never contains a provider key.
class VisionFoodAnalyzer implements FoodAnalyzer {
  VisionFoodAnalyzer(this.client);

  final SupabaseClient client;

  @override
  Future<FoodScan> analyze({XFile? image}) async {
    if (image == null) {
      throw const FoodAnalyzerException('Take a food photo before analyzing.');
    }

    final bytes = await image.readAsBytes();
    final mimeType = image.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    late final FunctionResponse response;
    try {
      response = await client.functions
          .invoke(
            'analyze-food',
            body: {'imageBase64': base64Encode(bytes), 'mimeType': mimeType},
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw const FoodAnalyzerException(
              'The AI service did not respond within 45 seconds. Make sure the analyze-food Edge Function is deployed.',
            ),
          );
    } catch (error) {
      if (error is FoodAnalyzerException) rethrow;
      throw FoodAnalyzerException(
        'The AI food service rejected the photo. Deploy the latest analyze-food Edge Function, set GEMINI_MODEL to gemini-2.5-flash, and verify GEMINI_API_KEY. Details: $error',
      );
    }

    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final detail = data is Map
          ? (data['detail'] ?? data['error'] ?? 'Unknown server error')
          : data.toString();
      throw FoodAnalyzerException(
        'The AI food service returned HTTP ${response.status}: $detail',
      );
    }

    final data = response.data;
    if (data is! Map) {
      throw const FoodAnalyzerException(
        'The food analysis service returned an invalid response.',
      );
    }

    return FoodScan.fromMap({
      ...Map<String, dynamic>.from(data),
      'scanned_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

class FoodAnalyzerException implements Exception {
  const FoodAnalyzerException(this.message);

  final String message;

  @override
  String toString() => message;
}
