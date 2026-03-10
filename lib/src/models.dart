class UserProfile {
  const UserProfile({
    required this.username,
    required this.role,
    required this.email,
    required this.phone,
    required this.fullName,
  });

  final String username;
  final String role;
  final String email;
  final String phone;
  final String fullName;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: _asString(json['username']),
      role: _asString(json['role']),
      email: _asString(json['email']),
      phone: _asString(json['phone']),
      fullName: _asString(json['full_name']),
    );
  }
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.basePrice,
    required this.startsFrom,
    required this.isActive,
  });

  final int id;
  final int? category;
  final String name;
  final String description;
  final String imageUrl;
  final double basePrice;
  final double? startsFrom;
  final bool isActive;

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: _asInt(json['id']),
      category: json['category'] == null ? null : _asInt(json['category']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      imageUrl: _asString(json['image_url']),
      basePrice: _asDouble(json['base_price']),
      startsFrom: json['starts_from'] == null ? null : _asDouble(json['starts_from']),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.isActive,
    required this.services,
  });

  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final bool isActive;
  final List<ServiceItem> services;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    final servicesRaw = (json['services'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ServiceItem.fromJson)
        .toList();

    return ServiceCategory(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      imageUrl: _asString(json['image_url']),
      isActive: _asBool(json['is_active'], fallback: true),
      services: servicesRaw,
    );
  }
}

class ProviderItem {
  const ProviderItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.rating,
    required this.price,
    required this.city,
    required this.phone,
  });

  final int id;
  final int userId;
  final String username;
  final String fullName;
  final double rating;
  final double? price;
  final String city;
  final String phone;

  factory ProviderItem.fromJson(Map<String, dynamic> json) {
    return ProviderItem(
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      username: _asString(json['username']),
      fullName: _asString(json['full_name']),
      rating: _asDouble(json['rating'], fallback: 0),
      price: json['price'] == null ? null : _asDouble(json['price']),
      city: _asString(json['city']),
      phone: _asString(json['phone']),
    );
  }
}

class BookingItem {
  const BookingItem({
    required this.id,
    required this.serviceName,
    required this.serviceNames,
    required this.category,
    required this.providerUsername,
    required this.providerFullName,
    required this.customerUsername,
    required this.address,
    required this.scheduledDate,
    required this.timeSlot,
    required this.status,
    required this.hasReview,
    required this.reviewRating,
    required this.reviewComment,
  });

  final int id;
  final String serviceName;
  final List<String> serviceNames;
  final String category;
  final String providerUsername;
  final String providerFullName;
  final String customerUsername;
  final String address;
  final String scheduledDate;
  final String timeSlot;
  final String status;
  final bool hasReview;
  final int? reviewRating;
  final String reviewComment;

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    final names = (json['service_names'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => _asString(e))
        .where((e) => e.isNotEmpty)
        .toList();
    return BookingItem(
      id: _asInt(json['id']),
      serviceName: _asString(json['service_name']),
      serviceNames: names,
      category: _asString(json['category']),
      providerUsername: _asString(json['provider_username']),
      providerFullName: _asString(json['provider_full_name']),
      customerUsername: _asString(json['customer_username']),
      address: _asString(json['address']),
      scheduledDate: _asString(json['scheduled_date']),
      timeSlot: _asString(json['time_slot']),
      status: _asString(json['status']),
      hasReview: _asBool(json['has_review']),
      reviewRating: json['review_rating'] == null ? null : _asInt(json['review_rating']),
      reviewComment: _asString(json['review_comment']),
    );
  }

  String get serviceLabel => serviceNames.isNotEmpty ? serviceNames.join(', ') : serviceName;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String message;
  final bool isRead;
  final String createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _asInt(json['id']),
      message: _asString(json['message']),
      isRead: _asBool(json['is_read']),
      createdAt: _asString(json['created_at']),
    );
  }
}

class ProviderServicePrice {
  const ProviderServicePrice({
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.basePrice,
  });

  final int serviceId;
  final String serviceName;
  final double price;
  final double basePrice;

  factory ProviderServicePrice.fromJson(Map<String, dynamic> json) {
    return ProviderServicePrice(
      serviceId: _asInt(json['service_id']),
      serviceName: _asString(json['service_name']),
      price: _asDouble(json['price']),
      basePrice: _asDouble(json['base_price']),
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.city,
    required this.phone,
    required this.providerServices,
  });

  final int id;
  final String username;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final String city;
  final String phone;
  final List<BasicService> providerServices;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final services = (json['provider_services'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(BasicService.fromJson)
        .toList();

    return AdminUser(
      id: _asInt(json['id']),
      username: _asString(json['username']),
      fullName: _asString(json['full_name']),
      email: _asString(json['email']),
      role: _asString(json['role']),
      isActive: _asBool(json['is_active'], fallback: true),
      city: _asString(json['city']),
      phone: _asString(json['phone']),
      providerServices: services,
    );
  }
}

class BasicService {
  const BasicService({required this.id, required this.name});

  final int id;
  final String name;

  factory BasicService.fromJson(Map<String, dynamic> json) {
    return BasicService(
      id: _asInt(json['id']),
      name: _asString(json['name']),
    );
  }
}

class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.isActive,
  });

  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final bool isActive;

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    return AdminCategory(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      imageUrl: _asString(json['image_url']),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }
}

class AdminService {
  const AdminService({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.basePrice,
    required this.isActive,
    required this.category,
    required this.categoryName,
  });

  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final double basePrice;
  final bool isActive;
  final int category;
  final String categoryName;

  factory AdminService.fromJson(Map<String, dynamic> json) {
    return AdminService(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      imageUrl: _asString(json['image_url']),
      basePrice: _asDouble(json['base_price']),
      isActive: _asBool(json['is_active'], fallback: true),
      category: _asInt(json['category']),
      categoryName: _asString(json['category_name']),
    );
  }
}

class AdminReview {
  const AdminReview({
    required this.id,
    required this.bookingId,
    required this.serviceName,
    required this.providerUsername,
    required this.authorUsername,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final int id;
  final int bookingId;
  final String serviceName;
  final String providerUsername;
  final String authorUsername;
  final int rating;
  final String comment;
  final String createdAt;

  factory AdminReview.fromJson(Map<String, dynamic> json) {
    return AdminReview(
      id: _asInt(json['id']),
      bookingId: _asInt(json['booking_id']),
      serviceName: _asString(json['service_name']),
      providerUsername: _asString(json['provider_username']),
      authorUsername: _asString(json['author_username']),
      rating: _asInt(json['rating']),
      comment: _asString(json['comment']),
      createdAt: _asString(json['created_at']),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) {
    final v = value.toLowerCase().trim();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  if (value is num) return value != 0;
  return fallback;
}