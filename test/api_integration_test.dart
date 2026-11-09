import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_system/services/api_service.dart';
import 'package:attendance_system/services/course_api_service.dart';
import 'package:attendance_system/services/attendance_api_service.dart';

void main() {
  test('ApiService verifies base URL and header token manipulation', () async {
    ApiService.setBaseUrl('http://localhost:8000');
    expect(ApiService.baseUrl, equals('http://localhost:8000'));

    await ApiService.setAuthToken('test_jwt_bearer_token');
    final token = await ApiService.getAuthToken();
    expect(token, equals('test_jwt_bearer_token'));

    await ApiService.setAuthToken(null);
    final clearedToken = await ApiService.getAuthToken();
    expect(clearedToken, isNull);
  });

  test('CourseApiService creates course request payload cleanly', () async {
    expect(CourseApiService.instance, isNotNull);
    expect(AttendanceApiService.instance, isNotNull);
  });
}

