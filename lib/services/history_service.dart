import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/history_event.dart';
import '../services/storage_service.dart';

class HistoryService {
  static Future<String> _getBaseUrl() async {
    final serverUrl = await StorageService.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('Server URL not configured');
    }
    return '$serverUrl/api/v1/mobile';
  }

  /// Get user's event history
  static Future<HistoryResponse> getHistory({
    required String userCode,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      
      final body = {
        'user_code': userCode,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      print('[HistoryService] Fetching history: $body');

      final response = await http
          .post(
            Uri.parse('$baseUrl/history'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('[HistoryService] Success: ${jsonData['data']['events'].length} events');
        return HistoryResponse.fromJson(jsonData);
      } else {
        final message = jsonData['message'] ?? 'Error fetching history';
        throw Exception(message);
      }
    } catch (e) {
      print('[HistoryService] Error: $e');
      rethrow;
    }
  }

  /// Get history for today
  static Future<HistoryResponse> getTodayHistory({
    required String userCode,
  }) async {
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    
    return getHistory(
      userCode: userCode,
      startDate: startDate.toIso8601String().split('T')[0],
      endDate: startDate.toIso8601String().split('T')[0],
    );
  }

  /// Get history for this week
  static Future<HistoryResponse> getWeekHistory({
    required String userCode,
  }) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return getHistory(
      userCode: userCode,
      startDate: startDate.toIso8601String().split('T')[0],
    );
  }

  /// Get history for this month
  static Future<HistoryResponse> getMonthHistory({
    required String userCode,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    
    return getHistory(
      userCode: userCode,
      startDate: startDate.toIso8601String().split('T')[0],
    );
  }
}
