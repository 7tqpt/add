// أنواع ما يقرؤه التطبيق — أضيق مما في القاعدة عمداً: لا عمولات ولا مستحقات
// شركاء ولا سجل عمليات، فلا داعي لأن يعرف التطبيق شكلها.

class Governorate {
  const Governorate({required this.id, required this.name});
  final String id;
  final String name;
  factory Governorate.fromMap(Map<String, dynamic> m) =>
      Governorate(id: m['id'] as String, name: m['name'] as String);
}

class ServiceCategory {
  const ServiceCategory({required this.id, required this.name, required this.slug});
  final String id;
  final String name;
  final String slug;
  factory ServiceCategory.fromMap(Map<String, dynamic> m) => ServiceCategory(
    id: m['id'] as String,
    name: m['name'] as String,
    slug: (m['slug'] ?? '') as String,
  );
}

/// صفّ `v_services` بأسماء أعمدته كما هي.
///
/// `provider_governorate` لا `governorate`: الطريقة تجمع جدولين فيهما العمود
/// نفسه فسُمّي بمصدره. واختصار الاسم هنا يُنتج قيمةً فارغة على الشاشة بلا خطأ
/// يدلّ عليها.
class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceTo,
    required this.unit,
    required this.depositPercent,
    required this.categoryId,
    required this.categoryName,
    required this.providerId,
    required this.providerName,
    required this.providerGovernorate,
    required this.providerRating,
    required this.providerReviewsCount,
    required this.providerIsFeatured,
    required this.cancellationPolicyName,
    this.coverPath,
    this.imagesCount = 0,
    this.hasVideo = false,
    this.hasAudio = false,
  });

  final String id;
  final String title;
  final String description;
  final num price;
  final num? priceTo;
  final String unit;
  final int depositPercent;
  final String categoryId;
  final String categoryName;
  final String providerId;
  final String providerName;
  final String providerGovernorate;
  final num providerRating;
  final int providerReviewsCount;
  final bool providerIsFeatured;
  final String? cancellationPolicyName;

  /// مسار الغلاف داخل سلّة `service-media` — أوّل صورةٍ بترتيب صاحبها.
  ///
  /// يأتي مع صفّ الخدمة لا في نداءٍ ثانٍ: قائمةُ الاستكشاف عشرون بطاقة،
  /// ونداءٌ لكلِّ غلافٍ عشرون طلباً على شبكة جوالٍ يمنية.
  final String? coverPath;
  final int imagesCount;
  final bool hasVideo;
  final bool hasAudio;

  factory ServiceItem.fromMap(Map<String, dynamic> m) => ServiceItem(
    id: m['id'] as String,
    title: (m['title'] ?? '') as String,
    description: (m['description'] ?? '') as String,
    price: (m['price'] ?? 0) as num,
    priceTo: m['price_to'] as num?,
    unit: (m['unit'] ?? '') as String,
    depositPercent: ((m['deposit_percent'] ?? 0) as num).toInt(),
    categoryId: (m['category_id'] ?? '') as String,
    categoryName: (m['category_name'] ?? '') as String,
    providerId: (m['provider_id'] ?? '') as String,
    providerName: (m['provider_name'] ?? '') as String,
    providerGovernorate: (m['provider_governorate'] ?? '') as String,
    providerRating: (m['provider_rating'] ?? 0) as num,
    providerReviewsCount: ((m['provider_reviews_count'] ?? 0) as num).toInt(),
    providerIsFeatured: (m['provider_is_featured'] ?? false) as bool,
    cancellationPolicyName: m['cancellation_policy_name'] as String?,
    coverPath: m['cover_path'] as String?,
    imagesCount: ((m['images_count'] ?? 0) as num).toInt(),
    hasVideo: (m['has_video'] ?? false) as bool,
    hasAudio: (m['has_audio'] ?? false) as bool,
  );
}

/// نوع الوسيط. النصّ هو ما يقبله قيد الجدول حرفياً — فلا يُترجم ولا يُختصر.
enum MediaKind { image, video, audio }

MediaKind mediaKindFrom(String raw) => switch (raw) {
  'video' => MediaKind.video,
  'audio' => MediaKind.audio,
  _ => MediaKind.image,
};

String mediaKindValue(MediaKind k) => switch (k) {
  MediaKind.image => 'image',
  MediaKind.video => 'video',
  MediaKind.audio => 'audio',
};

/// وسيطٌ لخدمة — صورةٌ أو مقطع فيديو أو مقطع صوتي.
class ServiceMedia {
  const ServiceMedia({
    required this.id,
    required this.kind,
    required this.path,
    required this.title,
    required this.durationSeconds,
    required this.sizeBytes,
    required this.sortOrder,
  });

  final String id;
  final MediaKind kind;

  /// المسار داخل السلّة لا الرابط — والرابط يُشتقّ منه عند العرض.
  final String path;
  final String title;
  final int durationSeconds;
  final int sizeBytes;
  final int sortOrder;

  factory ServiceMedia.fromMap(Map<String, dynamic> m) => ServiceMedia(
    id: m['id'] as String,
    kind: mediaKindFrom((m['kind'] ?? 'image') as String),
    path: (m['path'] ?? '') as String,
    title: (m['title'] ?? '') as String,
    durationSeconds: ((m['duration_seconds'] ?? 0) as num).toInt(),
    sizeBytes: ((m['size_bytes'] ?? 0) as num).toInt(),
    sortOrder: ((m['sort_order'] ?? 0) as num).toInt(),
  );
}

enum BookingStatus { pendingProvider, confirmed, completed, rejected, cancelled, expired }

BookingStatus bookingStatusFrom(String raw) => switch (raw) {
  'pending_provider' => BookingStatus.pendingProvider,
  'confirmed' => BookingStatus.confirmed,
  'completed' => BookingStatus.completed,
  'rejected' => BookingStatus.rejected,
  'cancelled' => BookingStatus.cancelled,
  _ => BookingStatus.expired,
};

class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.userName,
    required this.providerName,
    required this.serviceTitle,
    required this.eventDate,
    required this.eventTime,
    required this.address,
    required this.guestsCount,
    required this.status,
    required this.totalPrice,
    required this.depositAmount,
    required this.paidAmount,
  });

  final String id;
  final String reference;
  final String userName;
  final String providerName;
  final String serviceTitle;
  final String eventDate;
  final String? eventTime;
  final String address;
  final int guestsCount;
  final BookingStatus status;
  final num totalPrice;
  final num depositAmount;
  final num paidAmount;

  factory Booking.fromMap(Map<String, dynamic> m) => Booking(
    id: m['id'] as String,
    reference: (m['reference'] ?? '') as String,
    userName: (m['user_name'] ?? '') as String,
    providerName: (m['provider_name'] ?? '') as String,
    serviceTitle: (m['service_title'] ?? '') as String,
    eventDate: (m['event_date'] ?? '') as String,
    eventTime: m['event_time'] as String?,
    address: (m['address'] ?? '') as String,
    guestsCount: ((m['guests_count'] ?? 0) as num).toInt(),
    status: bookingStatusFrom((m['status'] ?? '') as String),
    totalPrice: (m['total_price'] ?? 0) as num,
    depositAmount: (m['deposit_amount'] ?? 0) as num,
    paidAmount: (m['paid_amount'] ?? 0) as num,
  );
}

class WeddingPlan {
  const WeddingPlan({
    required this.id,
    required this.title,
    required this.weddingDate,
    required this.governorate,
    required this.guestsCount,
    required this.budget,
    required this.status,
    required this.servicesCount,
    required this.totalCost,
    required this.paidAmount,
    required this.remainingAmount,
  });

  final String id;
  final String title;
  final String weddingDate;
  final String governorate;
  final int guestsCount;
  final num budget;
  final String status;
  final int servicesCount;
  final num totalCost;
  final num paidAmount;
  final num remainingAmount;

  factory WeddingPlan.fromMap(Map<String, dynamic> m) => WeddingPlan(
    id: m['id'] as String,
    title: (m['title'] ?? '') as String,
    weddingDate: (m['wedding_date'] ?? '') as String,
    governorate: (m['governorate'] ?? '') as String,
    guestsCount: ((m['guests_count'] ?? 0) as num).toInt(),
    budget: (m['budget'] ?? 0) as num,
    status: (m['status'] ?? 'planning') as String,
    servicesCount: ((m['services_count'] ?? 0) as num).toInt(),
    totalCost: (m['total_cost'] ?? 0) as num,
    paidAmount: (m['paid_amount'] ?? 0) as num,
    remainingAmount: (m['remaining_amount'] ?? 0) as num,
  );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.reference,
    required this.subject,
    required this.status,
    required this.lastMessageAt,
  });
  final String id;
  final String reference;
  final String subject;
  final String status;
  final String lastMessageAt;

  factory SupportTicket.fromMap(Map<String, dynamic> m) => SupportTicket(
    id: m['id'] as String,
    reference: (m['reference'] ?? '') as String,
    subject: (m['subject'] ?? '') as String,
    status: (m['status'] ?? 'open') as String,
    lastMessageAt: (m['last_message_at'] ?? '') as String,
  );
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.author,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });
  final String id;
  final String author;
  final String authorName;
  final String body;
  final String createdAt;

  factory SupportMessage.fromMap(Map<String, dynamic> m) => SupportMessage(
    id: m['id'] as String,
    author: (m['author'] ?? '') as String,
    authorName: (m['author_name'] ?? '') as String,
    body: (m['body'] ?? '') as String,
    createdAt: (m['created_at'] ?? '') as String,
  );
}

class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.businessName,
    required this.fullName,
    required this.governorate,
    required this.bio,
    required this.status,
    required this.rating,
    required this.reviewsCount,
    required this.completedBookings,
    required this.totalEarnings,
    required this.rejectionReason,
  });

  final String id;
  final String businessName;
  final String fullName;
  final String governorate;
  final String bio;
  final String status;
  final num rating;
  final int reviewsCount;
  final int completedBookings;
  final num totalEarnings;
  final String rejectionReason;

  factory ProviderProfile.fromMap(Map<String, dynamic> m) => ProviderProfile(
    id: m['id'] as String,
    businessName: (m['business_name'] ?? '') as String,
    fullName: (m['full_name'] ?? '') as String,
    governorate: (m['governorate'] ?? '') as String,
    bio: (m['bio'] ?? '') as String,
    status: (m['status'] ?? 'pending') as String,
    rating: (m['rating'] ?? 0) as num,
    reviewsCount: ((m['reviews_count'] ?? 0) as num).toInt(),
    completedBookings: ((m['completed_bookings'] ?? 0) as num).toInt(),
    totalEarnings: (m['total_earnings'] ?? 0) as num,
    rejectionReason: (m['rejection_reason'] ?? '') as String,
  );
}

/// خدمةٌ يملكها مقدّم الخدمة، كما يراها هو لا كما يراها المشتري.
///
/// غير `ServiceItem`: تلك صفٌّ من `v_services` مضمومٌ إلى اسم المزوّد وتقييمه
/// لعرضه في الاستكشاف، وهذه صفّ الجدول نفسه بما يملك صاحبه تعديله — ومنه
/// `isActive` الذي لا تُظهره الطريقة أصلاً لأنها تُخفي المعطَّل.
class MyService {
  const MyService({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceTo,
    required this.unit,
    required this.depositPercent,
    required this.categoryId,
    required this.isActive,
  });

  final String id;
  final String title;
  final String description;
  final num price;
  final num? priceTo;
  final String unit;
  final int depositPercent;
  final String categoryId;
  final bool isActive;

  factory MyService.fromMap(Map<String, dynamic> m) => MyService(
    id: m['id'] as String,
    title: (m['title'] ?? '') as String,
    description: (m['description'] ?? '') as String,
    price: (m['price'] ?? 0) as num,
    priceTo: m['price_to'] as num?,
    unit: (m['unit'] ?? 'للحجز') as String,
    depositPercent: ((m['deposit_percent'] ?? 30) as num).toInt(),
    categoryId: (m['category_id'] ?? '') as String,
    isActive: (m['is_active'] ?? true) as bool,
  );
}

/// مستند توثيق. `fileUrl` مسارٌ داخل حاوية `provider-docs` لا رابطاً:
/// الحاوية خاصّة، واللوحة توقّع رابطاً مؤقّتاً عند العرض.
class ProviderDocument {
  const ProviderDocument({
    required this.id,
    required this.type,
    required this.fileName,
    required this.fileUrl,
    required this.status,
    required this.note,
    required this.uploadedAt,
  });

  final String id;
  final String type;
  final String fileName;
  final String fileUrl;
  final String status;
  final String note;
  final String uploadedAt;

  factory ProviderDocument.fromMap(Map<String, dynamic> m) => ProviderDocument(
    id: m['id'] as String,
    type: (m['type'] ?? '') as String,
    fileName: (m['file_name'] ?? '') as String,
    fileUrl: (m['file_url'] ?? '') as String,
    status: (m['status'] ?? 'pending') as String,
    note: (m['note'] ?? '') as String,
    uploadedAt: (m['uploaded_at'] ?? '') as String,
  );
}

/// ملفّي الشخصيّ كما تعيده `api_my_profile`.
///
/// نموذجٌ مستقلٌّ عن `AppUser` الذي تقرؤه اللوحة: هذا ما يملك المستخدم تعديله
/// من التطبيق، وذاك صفٌّ إداريٌّ فيه `status` و`sessions_count` ولا شأن له بها.
class MyProfile {
  const MyProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.governorate,
    required this.governorateId,
    required this.avatarPath,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String governorate;
  final String? governorateId;
  final String avatarPath;

  factory MyProfile.fromMap(Map<String, dynamic> m) => MyProfile(
    id: (m['id'] ?? '') as String,
    fullName: (m['full_name'] ?? '') as String,
    email: (m['email'] ?? '') as String,
    phone: (m['phone'] ?? '') as String,
    governorate: (m['governorate'] ?? '') as String,
    governorateId: m['governorate_id'] as String?,
    avatarPath: (m['avatar_path'] ?? '') as String,
  );

  MyProfile copyWith({String? fullName, String? phone, String? avatarPath}) => MyProfile(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email,
    phone: phone ?? this.phone,
    governorate: governorate,
    governorateId: governorateId,
    avatarPath: avatarPath ?? this.avatarPath,
  );
}
