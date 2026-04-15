import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'session.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ReverseGeocodeResult {
  const ReverseGeocodeResult({required this.city, required this.displayName});

  final String city;
  final String displayName;
}

class OtpVerifyResult {
  const OtpVerifyResult({
    required this.requiresProfile,
    required this.isNewUser,
  });

  final bool requiresProfile;
  final bool isNewUser;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    return Uri.parse(
      '$base$normalized',
    ).replace(queryParameters: query?.isEmpty ?? true ? null : query);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    bool auth = false,
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
    bool retried = false,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Accept'] = 'application/json';

    if (headers != null) {
      request.headers.addAll(headers);
    }

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    if (auth) {
      final session = await TokenStore.read();
      if (session == null) {
        throw const ApiException('You are not logged in', statusCode: 401);
      }
      request.headers['Authorization'] = 'Bearer ${session.access}';
    }

    http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } on http.ClientException catch (error) {
      throw ApiException(
        'Cannot connect to ${AppConfig.baseUrl}. Start Django server and check network access. (${error.message})',
      );
    } catch (error) {
      throw ApiException(
        'Network error while calling ${AppConfig.baseUrl}: $error',
      );
    }
    final decoded = _decodeBody(response.body);

    if (auth && response.statusCode == 401 && !retried) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        return _request(
          method,
          path,
          auth: auth,
          body: body,
          query: query,
          headers: headers,
          retried: true,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      _extractErrorMessage(
        decoded,
        fallback: 'Request failed (${response.statusCode})',
      ),
      statusCode: response.statusCode,
    );
  }

  dynamic _decodeBody(String text) {
    if (text.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  String _extractErrorMessage(
    dynamic decoded, {
    String fallback = 'Request failed',
  }) {
    if (decoded is Map<String, dynamic>) {
      const knownKeys = <String>[
        'error',
        'detail',
        'message',
        'non_field_errors',
      ];
      for (final key in knownKeys) {
        final val = decoded[key];
        if (val is String && val.trim().isNotEmpty) {
          return val;
        }
        if (val is List && val.isNotEmpty) {
          return val.first.toString();
        }
      }
      for (final value in decoded.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
      }
    }
    if (decoded is String && decoded.trim().isNotEmpty) {
      final message = decoded.trim();
      final lower = message.toLowerCase();
      if (lower.contains('<!doctype html') || lower.contains('<html')) {
        return fallback;
      }
      return message.length > 280 ? '${message.substring(0, 280)}...' : message;
    }
    return fallback;
  }

  bool _looksLikeHtml(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('<!doctype html') ||
        normalized.contains('<html') ||
        normalized.contains('</html>') ||
        normalized.contains('<body');
  }

  Future<bool> _refreshToken() async {
    final session = await TokenStore.read();
    if (session == null) {
      return false;
    }

    final req = http.Request('POST', _uri('/api/token/refresh/'));
    req.headers['Content-Type'] = 'application/json';
    req.headers['Accept'] = 'application/json';
    req.body = jsonEncode({'refresh': session.refresh});

    final resp = await http.Response.fromStream(await _client.send(req));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      await TokenStore.clear();
      return false;
    }

    final body = _decodeBody(resp.body);
    if (body is! Map<String, dynamic>) {
      await TokenStore.clear();
      return false;
    }

    final access = body['access']?.toString();
    if (access == null || access.isEmpty) {
      await TokenStore.clear();
      return false;
    }

    await TokenStore.save(access: access, refresh: session.refresh);
    return true;
  }

  Future<void> sendLoginOtp(String phone) async {
    await _request(
      'POST',
      '/api/accounts/auth/otp/send/',
      body: {'phone': phone},
    );
  }

  Future<OtpVerifyResult> verifyLoginOtp({
    required String phone,
    required String otp,
    String? fullName,
    String? email,
    String? gender,
    String? role,
    String? city,
    List<int>? services,
  }) async {
    final payload = <String, dynamic>{'phone': phone, 'otp': otp};
    if (fullName != null && fullName.trim().isNotEmpty) {
      payload['full_name'] = fullName.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim();
    }
    if (gender != null && gender.trim().isNotEmpty) {
      payload['gender'] = gender.trim().toUpperCase();
    }
    if (role != null && role.trim().isNotEmpty) {
      payload['role'] = role.trim().toUpperCase();
    }
    if (city != null && city.trim().isNotEmpty) {
      payload['city'] = city.trim();
    }
    if (services != null) {
      payload['services'] = services;
    }
    final body = await _request(
      'POST',
      '/api/accounts/auth/otp/verify/',
      body: payload,
    );

    if (body is! Map<String, dynamic>) {
      throw const ApiException('Invalid OTP response');
    }

    final requiresProfile = body['requires_profile'] == true;
    if (requiresProfile) {
      return const OtpVerifyResult(requiresProfile: true, isNewUser: true);
    }

    final access = body['access']?.toString();
    final refresh = body['refresh']?.toString();
    if (access == null || refresh == null) {
      throw const ApiException('OTP verification failed');
    }

    await TokenStore.save(access: access, refresh: refresh);
    return OtpVerifyResult(
      requiresProfile: false,
      isNewUser: body['is_new_user'] == true,
    );
  }

  Future<UserProfile> fetchProfile() async {
    final body = await _request('GET', '/api/accounts/me/', auth: true);
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Invalid profile response');
    }
    return UserProfile.fromJson(body);
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
  }) async {
    await _request(
      'POST',
      '/api/accounts/me/update/',
      auth: true,
      body: {'full_name': fullName, 'email': email},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _request(
      'POST',
      '/api/accounts/me/change-password/',
      auth: true,
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
  }

  Future<void> logout() => TokenStore.clear();

  Future<List<ServiceCategory>> fetchCategories({bool auth = true}) async {
    final body = await _request(
      'GET',
      auth ? '/api/services/categories/' : '/api/services/categories/public/',
      auth: auth,
    );

    if (body is! List<dynamic>) return <ServiceCategory>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(ServiceCategory.fromJson)
        .toList();
  }

  Future<List<ProviderItem>> fetchProviders({
    required int serviceId,
    String? city,
  }) async {
    final query = <String, String>{};
    if (city != null && city.trim().isNotEmpty) {
      query['city'] = city.trim();
    }

    final body = await _request(
      'GET',
      '/api/services/$serviceId/providers/',
      auth: true,
      query: query,
    );

    if (body is! List<dynamic>) return <ProviderItem>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(ProviderItem.fromJson)
        .toList();
  }

  Future<void> saveCustomerCity(String city) async {
    await _request(
      'POST',
      '/api/accounts/me/customer-city/',
      auth: true,
      body: {'city': city},
    );
    await TokenStore.saveCity(city);
  }

  Future<ReverseGeocodeResult> reverseGeocode({
    required double lat,
    required double lon,
  }) async {
    final body = await _request(
      'GET',
      '/api/accounts/geo/reverse/',
      query: <String, String>{'lat': lat.toString(), 'lon': lon.toString()},
    );
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Invalid reverse geocode response');
    }
    final city = body['city']?.toString().trim() ?? '';
    final displayName = body['display_name']?.toString().trim() ?? '';
    if (_looksLikeHtml(city) || _looksLikeHtml(displayName)) {
      throw const ApiException('Reverse geocode service returned invalid data');
    }
    return ReverseGeocodeResult(city: city, displayName: displayName);
  }

  Future<List<ServiceItem>> fetchProviderServicesForBooking(
    int providerId,
  ) async {
    final body = await _request(
      'GET',
      '/api/bookings/provider-services/$providerId/',
      auth: true,
    );
    if (body is! List<dynamic>) return <ServiceItem>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(ServiceItem.fromJson)
        .toList();
  }

  Future<int> createBooking({
    required int service,
    int? provider,
    required String scheduledDate,
    required String timeSlot,
    required String address,
    required List<int> serviceIds,
  }) async {
    final payload = <String, dynamic>{
      'service': service,
      'scheduled_date': scheduledDate,
      'time_slot': timeSlot,
      'address': address,
      'service_ids': serviceIds,
    };
    if (provider != null) {
      payload['provider'] = provider;
    }
    final body = await _request(
      'POST',
      '/api/bookings/create/',
      auth: true,
      body: payload,
    );

    if (body is! Map<String, dynamic>) {
      throw const ApiException('Invalid booking response');
    }
    return int.tryParse(body['booking_id']?.toString() ?? '') ?? 0;
  }

  Future<List<BookingItem>> fetchCustomerBookings() async {
    final body = await _request('GET', '/api/bookings/my/', auth: true);
    if (body is! List<dynamic>) return <BookingItem>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(BookingItem.fromJson)
        .toList();
  }

  Future<void> submitReview({
    required int bookingId,
    required int rating,
    required String comment,
  }) async {
    await _request(
      'POST',
      '/api/bookings/review/$bookingId/',
      auth: true,
      body: {'rating': rating, 'comment': comment},
    );
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final body = await _request(
      'GET',
      '/api/accounts/notifications/',
      auth: true,
    );
    if (body is! List<dynamic>) return <AppNotification>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _request(
      'POST',
      '/api/accounts/notifications/read/$notificationId/',
      auth: true,
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _request('POST', '/api/accounts/notifications/read-all/', auth: true);
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _request(
      'POST',
      '/api/accounts/notifications/device/register/',
      auth: true,
      body: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterDeviceToken({required String token}) async {
    await _request(
      'POST',
      '/api/accounts/notifications/device/unregister/',
      auth: true,
      body: {'token': token},
    );
  }

  Future<List<SupportTicket>> fetchSupportTickets() async {
    final body = await _request(
      'GET',
      '/api/accounts/support/tickets/',
      auth: true,
    );
    if (body is! List<dynamic>) return <SupportTicket>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(SupportTicket.fromJson)
        .toList();
  }

  Future<SupportTicket> createSupportTicket({
    required String issueType,
    required String message,
    int? bookingId,
  }) async {
    final body = await _request(
      'POST',
      '/api/accounts/support/tickets/',
      auth: true,
      body: <String, dynamic>{
        'issue_type': issueType,
        'message': message,
        'booking_id': bookingId,
      },
    );
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Invalid support ticket response');
    }
    return SupportTicket.fromJson(body);
  }

  Future<SupportTicket> updateSupportTicketStatus({
    required int ticketId,
    required String status,
  }) async {
    final body = await _request(
      'POST',
      '/api/accounts/support/tickets/$ticketId/status/',
      auth: true,
      body: <String, dynamic>{'status': status},
    );
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Invalid support ticket response');
    }
    return SupportTicket.fromJson(body);
  }

  Future<List<BookingItem>> fetchProviderDashboardBookings() async {
    final body = await _request(
      'GET',
      '/api/bookings/provider/dashboard/',
      auth: true,
    );
    if (body is! List<dynamic>) return <BookingItem>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(BookingItem.fromJson)
        .toList();
  }

  Future<void> providerAction({
    required int bookingId,
    required String action,
  }) async {
    await _request(
      'POST',
      '/api/bookings/provider/action/$bookingId/',
      auth: true,
      body: {'action': action},
    );
  }

  Future<void> providerUpdateStatus({
    required int bookingId,
    required String status,
    String? otp,
  }) async {
    final payload = <String, dynamic>{'status': status};
    if (otp != null && otp.trim().isNotEmpty) {
      payload['otp'] = otp.trim();
    }
    await _request(
      'POST',
      '/api/bookings/provider/update-status/$bookingId/',
      auth: true,
      body: payload,
    );
  }

  Future<List<BasicService>> fetchProviderMyServices() async {
    final body = await _request(
      'GET',
      '/api/accounts/providers/me/services/',
      auth: true,
    );
    if (body is! Map<String, dynamic>) return <BasicService>[];
    final raw = body['services'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (row) =>
              BasicService(id: row['id'] as int, name: row['name'].toString()),
        )
        .toList();
  }

  Future<void> updateProviderMyServices(List<int> serviceIds) async {
    await _request(
      'POST',
      '/api/accounts/providers/me/services/',
      auth: true,
      body: {'services': serviceIds},
    );
  }

  Future<List<ProviderServicePrice>> fetchProviderMyServicePrices() async {
    final body = await _request(
      'GET',
      '/api/accounts/providers/me/service-prices/',
      auth: true,
    );
    if (body is! Map<String, dynamic>) return <ProviderServicePrice>[];
    final prices = body['prices'] as List<dynamic>? ?? <dynamic>[];
    return prices
        .whereType<Map<String, dynamic>>()
        .map(ProviderServicePrice.fromJson)
        .toList();
  }

  Future<void> updateProviderMyServicePrices(
    List<Map<String, dynamic>> prices,
  ) async {
    await _request(
      'POST',
      '/api/accounts/providers/me/service-prices/',
      auth: true,
      body: {'prices': prices},
    );
  }

  Future<List<ProviderItem>> fetchProvidersList() async {
    final body = await _request('GET', '/api/accounts/providers/', auth: false);
    if (body is! List<dynamic>) return <ProviderItem>[];
    return body.whereType<Map<String, dynamic>>().map((row) {
      return ProviderItem(
        id: int.tryParse(row['id']?.toString() ?? '') ?? 0,
        userId: int.tryParse(row['id']?.toString() ?? '') ?? 0,
        username: row['username']?.toString() ?? '',
        fullName: row['username']?.toString() ?? '',
        rating: double.tryParse(row['average_rating']?.toString() ?? '') ?? 0,
        price: null,
        city: '',
        phone: '',
      );
    }).toList();
  }

  Future<List<BookingItem>> fetchAdminBookings() async {
    final body = await _request('GET', '/api/bookings/admin/all/', auth: true);
    if (body is! List<dynamic>) return <BookingItem>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(BookingItem.fromJson)
        .toList();
  }

  Future<void> assignProvider({
    required int bookingId,
    required int providerId,
  }) async {
    await _request(
      'POST',
      '/api/bookings/assign/$bookingId/',
      auth: true,
      body: {'provider_id': providerId},
    );
  }

  Future<List<AdminUser>> fetchAdminUsers() async {
    final body = await _request(
      'GET',
      '/api/accounts/admin/users/',
      auth: true,
    );
    if (body is! List<dynamic>) return <AdminUser>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(AdminUser.fromJson)
        .toList();
  }

  Future<AdminUser> createAdminUser(Map<String, dynamic> payload) async {
    final body = await _request(
      'POST',
      '/api/accounts/admin/users/',
      auth: true,
      body: payload,
    );
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Invalid user response');
    }
    return AdminUser.fromJson(body);
  }

  Future<void> toggleAdminUser(int userId) async {
    await _request(
      'POST',
      '/api/accounts/admin/users/$userId/toggle/',
      auth: true,
    );
  }

  Future<void> deleteAdminUser(int userId) async {
    await _request('DELETE', '/api/accounts/admin/users/$userId/', auth: true);
  }

  Future<void> updateAdminProviderServices({
    required int userId,
    required List<int> services,
  }) async {
    await _request(
      'POST',
      '/api/accounts/admin/providers/$userId/services/',
      auth: true,
      body: {'services': services},
    );
  }

  Future<List<ProviderServicePrice>> fetchAdminProviderServicePrices(
    int userId,
  ) async {
    final body = await _request(
      'GET',
      '/api/accounts/admin/providers/$userId/service-prices/',
      auth: true,
    );
    if (body is! Map<String, dynamic>) return <ProviderServicePrice>[];
    final prices = body['prices'] as List<dynamic>? ?? <dynamic>[];
    return prices
        .whereType<Map<String, dynamic>>()
        .map(ProviderServicePrice.fromJson)
        .toList();
  }

  Future<void> updateAdminProviderServicePrices({
    required int userId,
    required List<Map<String, dynamic>> prices,
  }) async {
    await _request(
      'POST',
      '/api/accounts/admin/providers/$userId/service-prices/',
      auth: true,
      body: {'prices': prices},
    );
  }

  Future<List<AdminCategory>> fetchAdminCategories() async {
    final body = await _request(
      'GET',
      '/api/services/admin/categories/',
      auth: true,
    );
    if (body is! List<dynamic>) return <AdminCategory>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(AdminCategory.fromJson)
        .toList();
  }

  Future<AdminCategory> createAdminCategory(
    Map<String, dynamic> payload,
  ) async {
    final body = await _request(
      'POST',
      '/api/services/admin/categories/',
      auth: true,
      body: payload,
    );
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Invalid category response');
    }
    return AdminCategory.fromJson(body);
  }

  Future<void> updateAdminCategory(int id, Map<String, dynamic> payload) async {
    await _request(
      'PUT',
      '/api/services/admin/categories/$id/',
      auth: true,
      body: payload,
    );
  }

  Future<void> deleteAdminCategory(int id) async {
    await _request('DELETE', '/api/services/admin/categories/$id/', auth: true);
  }

  Future<List<AdminService>> fetchAdminServices() async {
    final body = await _request(
      'GET',
      '/api/services/admin/services/',
      auth: true,
    );
    if (body is! List<dynamic>) return <AdminService>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(AdminService.fromJson)
        .toList();
  }

  Future<AdminService> createAdminService(Map<String, dynamic> payload) async {
    final body = await _request(
      'POST',
      '/api/services/admin/services/',
      auth: true,
      body: payload,
    );
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Invalid service response');
    }
    return AdminService.fromJson(body);
  }

  Future<void> updateAdminService(int id, Map<String, dynamic> payload) async {
    await _request(
      'PUT',
      '/api/services/admin/services/$id/',
      auth: true,
      body: payload,
    );
  }

  Future<void> deleteAdminService(int id) async {
    await _request('DELETE', '/api/services/admin/services/$id/', auth: true);
  }

  Future<String> uploadAdminIcon(String filePath) async {
    final session = await TokenStore.read();
    if (session == null) {
      throw const ApiException('You are not logged in', statusCode: 401);
    }

    final request = http.MultipartRequest(
      'POST',
      _uri('/api/services/admin/upload-icon/'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${session.access}';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: File(filePath).uri.pathSegments.last,
      ),
    );

    http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } on http.ClientException catch (error) {
      throw ApiException(
        'Cannot connect to ${AppConfig.baseUrl}. Start Django server and check network access. (${error.message})',
      );
    } catch (error) {
      throw ApiException(
        'Network error while uploading icon to ${AppConfig.baseUrl}: $error',
      );
    }

    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(
          decoded,
          fallback: 'Upload failed (${response.statusCode})',
        ),
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Invalid upload response');
    }
    final imageUrl = decoded['image_url']?.toString().trim() ?? '';
    if (imageUrl.isEmpty) {
      throw const ApiException(
        'Upload succeeded but image URL was not returned',
      );
    }
    return imageUrl;
  }

  Future<List<AdminReview>> fetchAdminReviews() async {
    final body = await _request(
      'GET',
      '/api/bookings/admin/reviews/',
      auth: true,
    );
    if (body is! List<dynamic>) return <AdminReview>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(AdminReview.fromJson)
        .toList();
  }
}
