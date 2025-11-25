import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/work_schedule.dart';
import 'config_service.dart';
import 'setup_service.dart';
import 'storage_service.dart';

class ScheduleService {
  static Future<String> _getBaseUrl() async {
    final configuredUrl = await SetupService.getConfiguredServerUrl();
    if (configuredUrl != null) return configuredUrl;
    final currentUrl = await ConfigService.getCurrentServerUrl();
    if (currentUrl == null) {
      throw Exception('Server URL not configured');
    }
    return currentUrl;
  }

  static Future<WorkSchedule> getSchedule() async {
    try {
      final baseUrl = await _getBaseUrl();
      final user = await StorageService.getUser();
      
      if (user == null) {
        throw Exception('User not found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/mobile/schedule'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_code': user.code,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return WorkSchedule.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error fetching schedule');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting schedule: $e');
      rethrow;
    }
  }

  static Future<void> updateSchedule(WorkSchedule schedule) async {
    try {
      final baseUrl = await _getBaseUrl();
      final user = await StorageService.getUser();
      
      if (user == null) {
        throw Exception('User not found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/mobile/schedule/update'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_code': user.code,
          'schedule': schedule.schedule,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Error updating schedule');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating schedule: $e');
      rethrow;
    }
  }
}
