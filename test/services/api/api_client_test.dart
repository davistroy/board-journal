import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/services/api/api_client.dart';

void main() {
  group('ApiResult', () {
    group('success factory', () {
      test('creates successful result with data', () {
        final result = ApiResult.success(
          {'key': 'value'},
          statusCode: 200,
        );

        expect(result.success, isTrue);
        expect(result.data, {'key': 'value'});
        expect(result.statusCode, 200);
        expect(result.error, isNull);
        expect(result.isNetworkError, isFalse);
        expect(result.isConflict, isFalse);
      });

      test('creates successful result without status code', () {
        final result = ApiResult.success({'data': 'test'});

        expect(result.success, isTrue);
        expect(result.data, {'data': 'test'});
        expect(result.statusCode, isNull);
      });
    });

    group('failure factory', () {
      test('creates failure result with error message', () {
        final result = ApiResult<Map<String, dynamic>>.failure(
          'Something went wrong',
          statusCode: 500,
        );

        expect(result.success, isFalse);
        expect(result.data, isNull);
        expect(result.error, 'Something went wrong');
        expect(result.statusCode, 500);
        expect(result.isNetworkError, isFalse);
        expect(result.isConflict, isFalse);
      });

      test('creates network error result', () {
        final result = ApiResult<Map<String, dynamic>>.failure(
          'Network error: Connection refused',
          isNetworkError: true,
        );

        expect(result.success, isFalse);
        expect(result.error, 'Network error: Connection refused');
        expect(result.isNetworkError, isTrue);
        expect(result.isConflict, isFalse);
      });

      test('creates conflict error result', () {
        final result = ApiResult<Map<String, dynamic>>.failure(
          'Conflict detected',
          statusCode: 409,
          isConflict: true,
        );

        expect(result.success, isFalse);
        expect(result.error, 'Conflict detected');
        expect(result.statusCode, 409);
        expect(result.isConflict, isTrue);
        expect(result.isNetworkError, isFalse);
      });

      test('creates 401 unauthorized result', () {
        final result = ApiResult<Map<String, dynamic>>.failure(
          'Authentication failed. Please sign in again.',
          statusCode: 401,
        );

        expect(result.success, isFalse);
        expect(result.statusCode, 401);
        expect(result.error, contains('Authentication failed'));
      });

      test('creates timeout result', () {
        final result = ApiResult<Map<String, dynamic>>.failure(
          'Request timed out after 30 seconds',
          isNetworkError: true,
        );

        expect(result.success, isFalse);
        expect(result.error, contains('timed out'));
        expect(result.isNetworkError, isTrue);
      });
    });

    group('result properties', () {
      test('success result has correct boolean values', () {
        final result = ApiResult.success({'test': true});

        expect(result.success, isTrue);
        expect(result.isNetworkError, isFalse);
        expect(result.isConflict, isFalse);
      });

      test('failure result defaults', () {
        final result = ApiResult<String>.failure('error');

        expect(result.success, isFalse);
        expect(result.isNetworkError, isFalse);
        expect(result.isConflict, isFalse);
        expect(result.statusCode, isNull);
      });
    });
  });

  group('ApiClient', () {
    // Note: Full integration tests would require mocking http.Client
    // These tests verify the class structure and factories exist

    test('ApiResult generic type works with different types', () {
      final mapResult = ApiResult<Map<String, dynamic>>.success({'key': 'value'});
      expect(mapResult.data, isA<Map<String, dynamic>>());

      final listResult = ApiResult<List<String>>.success(['a', 'b', 'c']);
      expect(listResult.data, isA<List<String>>());

      final stringResult = ApiResult<String>.success('hello');
      expect(stringResult.data, 'hello');
    });

    test('ApiResult handles null data in failure', () {
      final result = ApiResult<Map<String, dynamic>>.failure('error');

      expect(result.success, isFalse);
      expect(result.data, isNull);
    });

    test('ApiResult handles empty map in success', () {
      final result = ApiResult<Map<String, dynamic>>.success({});

      expect(result.success, isTrue);
      expect(result.data, isEmpty);
    });
  });
}
