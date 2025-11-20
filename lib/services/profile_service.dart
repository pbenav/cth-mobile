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

      final url = Uri.parse('$baseUrl/mobile/profile/update');
      
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
}
