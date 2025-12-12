import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';
import 'storage_service.dart';
import '../models/user.dart';

class ProfileService {
  /// Update user profile on the server
  static Future<bool> updateProfile({
    required String userCode,
    required String name,
    String? familyName1,
    String? familyName2,
  }) async {
    try {
      final baseUrl = await ConfigService.getCurrentServerUrl();
      if (baseUrl == null) {
        throw Exception('Server URL not configured');
      }

      final url = Uri.parse('$baseUrl/api/v1/profile/update');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'user_code': userCode,
          'name': name,
          'family_name1': familyName1,
          'family_name2': familyName2,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Update local storage with new data
          final currentUser = await StorageService.getUser();
          if (currentUser != null) {
            final updatedUser = User(
              id: currentUser.id,
              code: userCode,
              name: name,
              familyName1: familyName1,
              familyName2: familyName2,
            );
            await StorageService.saveUser(updatedUser);
          }
          return true;
        }
      }
      
      throw Exception('Failed to update profile: ${response.body}');
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  /// Switch user's current team by selecting a work center
  /// This updates the user's current_team_id on the server
  static Future<Map<String, dynamic>> switchTeam({
    required String userCode,
    required String workCenterCode,
  }) async {
    try {
      final baseUrl = await ConfigService.getCurrentServerUrl();
      if (baseUrl == null) {
        throw Exception('Server URL not configured');
      }

      final url = Uri.parse('$baseUrl/api/v1/team/switch');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'user_code': userCode,
          'work_center_code': workCenterCode,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? {};
        }
      }
      
      // Handle error responses
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to switch team');
    } catch (e) {
      throw Exception('Error switching team: $e');
    }
  }
}
