// أنواع ما يقرؤه التطبيق — أضيق مما في القاعدة عمداً: لا عمولات ولا مستحقات
// شركاء ولا سجل عمليات، فلا داعي لأن يعرف التطبيق شكلها.

import '../core/geo.dart';

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
    this.providerVerified = false,
    this.coverPath,
    this.imagesCount = 0,
    this.hasVideo = false,
    this.hasAudio = false,
    this.providerPoint,
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

  /// وثّقته الإدارة. يأتي مع صفّ الخدمة فتحمل كلُّ بطاقةٍ علامتها بلا نداءٍ
  /// ثانٍ — وقائمةُ الاستكشاف عشرون بطاقة.
  final bool providerVerified;

  /// مسار الغلاف داخل سلّة `service-media` — أوّل صورةٍ بترتيب صاحبها.
  ///
  /// يأتي مع صفّ الخدمة لا في نداءٍ ثانٍ: قائمةُ الاستكشاف عشرون بطاقة،
  /// ونداءٌ لكلِّ غلافٍ عشرون طلباً على شبكة جوالٍ يمنية.
  final String? coverPath;
  final int imagesCount;
  final bool hasVideo;
  final bool hasAudio;

  /// نقطةُ مقدّم الخدمة على الخريطة — `null` لمن لم يضعها.
  ///
  /// تأتي مع صفّ الخدمة، فتُحسب المسافةُ في البطاقة بلا نداءٍ ثانٍ ولا عمودٍ
  /// محسوبٍ من الخادم: ضربٌ واحدٌ لكلّ بطاقةٍ معروضة.
  final GeoPoint? providerPoint;

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
    providerVerified: (m['provider_verified'] ?? false) as bool,
    coverPath: m['cover_path'] as String?,
    imagesCount: ((m['images_count'] ?? 0) as num).toInt(),
    hasVideo: (m['has_video'] ?? false) as bool,
    hasAudio: (m['has_audio'] ?? false) as bool,
    providerPoint:
        pointFromRow(m, 'provider_latitude', 'provider_longitude'),
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
    this.couponCode = '',
    this.discountAmount = 0,
    this.point,
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

  /// كودُ الخصم المستعمَل في هذا الحجز، ومبلغُه بالريال.
  ///
  /// ويُنسخان في الحجز نصّاً ورقماً كما تُنسخ سياسةُ الإلغاء: الكوبون قد
  /// يُحذف بعد سنة، والحجزُ يبقى ويجب أن يقول ما جرى فيه.
  final String couponCode;
  final num discountAmount;

  /// موقعُ المناسبة على الخريطة — وهو ما يُسلَّم إلى تطبيق الخرائط ليصل
  /// مقدّمُ الخدمة إلى بيت العرس.
  final GeoPoint? point;

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
    couponCode: (m['coupon_code'] ?? '') as String,
    discountAmount: (m['discount_amount'] ?? 0) as num,
    point: _pointOf(m),
  );
}

/// نتيجةُ التحقّق من كودِ خصمٍ قبل الحجز.
///
/// و`discount` هو **المبلغُ المطبَّق فعلاً** لا قيمةُ الكود: كودُ ٥٠٪ على
/// منصّةٍ عمولتُها ١٠٪ يُقصّ عند العشرة، فيُعرض للعميل ما سيُخصم حقّاً قبل
/// أن يؤكّد — لا رقمٌ يعِد بما لا يقع.
class CouponCheck {
  const CouponCheck({
    required this.code,
    required this.description,
    required this.discount,
  });

  final String code;
  final String description;
  final num discount;

  factory CouponCheck.fromMap(Map<String, dynamic> m) => CouponCheck(
    code: (m['code'] ?? '') as String,
    description: (m['description'] ?? '') as String,
    discount: (m['discount'] ?? 0) as num,
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
    required this.logoPath,
    required this.status,
    required this.rating,
    required this.reviewsCount,
    required this.completedBookings,
    required this.totalEarnings,
    required this.rejectionReason,
    this.point,
  });

  final String id;
  final String businessName;
  final String fullName;
  final String governorate;
  final String bio;
  final String logoPath;
  final String status;
  final num rating;
  final int reviewsCount;
  final int completedBookings;
  final num totalEarnings;
  final String rejectionReason;

  /// نقطةُ محلّه على الخريطة — يضعها بنفسه، ويُرتَّب بها في «الأقرب إليّ».
  ///
  /// وليست من الحقول المحروسة: `guard_provider_self_update` يمنع الحالةَ
  /// والتوثيقَ والعمولةَ والتقييم، لا موقعَ المحلّ — وهو أعرفُ الناس به.
  final GeoPoint? point;

  factory ProviderProfile.fromMap(Map<String, dynamic> m) => ProviderProfile(
    id: m['id'] as String,
    businessName: (m['business_name'] ?? '') as String,
    fullName: (m['full_name'] ?? '') as String,
    governorate: (m['governorate'] ?? '') as String,
    bio: (m['bio'] ?? '') as String,
    logoPath: (m['logo_path'] ?? '') as String,
    status: (m['status'] ?? 'pending') as String,
    rating: (m['rating'] ?? 0) as num,
    reviewsCount: ((m['reviews_count'] ?? 0) as num).toInt(),
    completedBookings: ((m['completed_bookings'] ?? 0) as num).toInt(),
    totalEarnings: (m['total_earnings'] ?? 0) as num,
    rejectionReason: (m['rejection_reason'] ?? '') as String,
    point: pointFromRow(m, 'latitude', 'longitude'),
  );
}

/// مقدّم الخدمة **كما يراه العميل**.
///
/// غير `ProviderProfile` أعلاه: تلك صفُّ `service_providers` كما يراه صاحبه —
/// فيه أرباحُه وحالتُه وسببُ رفضه إن رُفض. وهذه صفٌّ من `v_providers`، وليس
/// فيها شيءٌ من ذلك ولا بريدٌ ولا رقمُ جوال: **ما لا يُعرض لا يُقرأ أصلاً**،
/// فلا يُنقل إلى الجهاز سرٌّ لينتظر من يعرضه سهواً.
///
/// وسياسةُ القراءة تقصر الظاهرَ على الموثّقين، فلا يُفتح ملفُّ من لم تُوثّقه
/// الإدارة بعد ولو عُرف معرّفه.
class PublicProvider {
  const PublicProvider({
    required this.id,
    required this.businessName,
    required this.bio,
    required this.logoPath,
    required this.governorate,
    required this.coverageAreas,
    required this.rating,
    required this.reviewsCount,
    required this.completedBookings,
    required this.isFeatured,
    required this.isVerified,
    required this.categories,
    this.point,
  });

  final String id;
  final String businessName;
  final String bio;

  /// مسارُ الشعار داخل سلّة `avatars` — لا رابطٌ كامل.
  final String logoPath;

  final String governorate;

  /// المناطق التي يخدمها خارج محافظته.
  final List<String> coverageAreas;

  final num rating;
  final int reviewsCount;
  final int completedBookings;
  final bool isFeatured;

  /// وُثِّق من الإدارة. تُحسب من `verified_at` لا من `status`: الطريقة العامة
  /// لا تُظهر العمود الثاني أصلاً.
  final bool isVerified;

  /// أسماء أقسامه — لا معرّفاتها: هذه للعرض لا للترشيح.
  final List<String> categories;

  /// نقطتُه على الخريطة — `null` لمن لم يضعها، وهم موجودون ويعملون.
  final GeoPoint? point;

  factory PublicProvider.fromMap(Map<String, dynamic> m) => PublicProvider(
    id: m['id'] as String,
    businessName: (m['business_name'] ?? '') as String,
    bio: (m['bio'] ?? '') as String,
    logoPath: (m['logo_path'] ?? '') as String,
    governorate: (m['governorate'] ?? '') as String,
    coverageAreas: _texts(m['coverage_areas']),
    rating: (m['rating'] ?? 0) as num,
    reviewsCount: ((m['reviews_count'] ?? 0) as num).toInt(),
    completedBookings: ((m['completed_bookings'] ?? 0) as num).toInt(),
    isFeatured: (m['is_featured'] ?? false) as bool,
    isVerified: m['verified_at'] != null,
    categories: _texts(m['categories']),
    point: pointFromRow(m, 'latitude', 'longitude'),
  );
}

/// مصفوفة `text[]` من Postgres تصل قائمةَ `dynamic` — أو `null` لو غاب العمود.
List<String> _texts(Object? raw) =>
    raw is List ? raw.map((e) => '$e').where((s) => s.isNotEmpty).toList() : const [];

/// رأيُ عميلٍ في مقدّم خدمة — المنشورُ منها وحده.
///
/// ولا يُكتب من التطبيق: `api_submit_review` هي التي تكتبه، وهي التي تتحقّق
/// أن الحجز نُفِّذ فعلاً. فلا يُقيَّم من لم يُتعامل معه.
class Review {
  const Review({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String userName;
  final int rating;
  final String comment;
  final String createdAt;

  factory Review.fromMap(Map<String, dynamic> m) => Review(
    id: m['id'] as String,
    userName: (m['user_name'] ?? '') as String,
    rating: ((m['rating'] ?? 0) as num).toInt(),
    comment: (m['comment'] ?? '') as String,
    createdAt: (m['created_at'] ?? '') as String,
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

/// ملخّصُ الحجوزات: كم، وأقربُها، وكم مؤكّدٌ وكم ينتظر.
///
/// **وواحدٌ في موضعين لا نسختان.** يُعرض في الرئيسية وفي أعلى «حجوزاتي»، ولو
/// حُسب في كلٍّ على حدة لاختلف العددان يوماً — تُستبعد الملغاة في إحداهما
/// وتبقى في الأخرى — فيقرأ العميل «٣ حجوزات» في الرئيسية ثمّ يعدّ اثنين في
/// الشاشة، فلا يثق بالرقمين معاً.
class BookingsSummary {
  const BookingsSummary({
    required this.upcoming,
    required this.confirmed,
    required this.pending,
  });

  /// القادمةُ مرتّبةً بالأقرب.
  final List<Booking> upcoming;
  final int confirmed;
  final int pending;

  Booking? get next => upcoming.isEmpty ? null : upcoming.first;
  int get count => upcoming.length;

  /// **والماضي يُستبعد:** «حجزك القادم» عن عرسٍ انقضى الشهر الماضي خبرٌ خاطئ
  /// لا خبرٌ قديم. وكذلك الملغى والمرفوض — عدُّهما في «٣ حجوزات» يَعِد بما لا
  /// وجود له.
  factory BookingsSummary.of(List<Booking> all) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows =
        all
            .where(
              (b) =>
                  b.eventDate.compareTo(today) >= 0 &&
                  b.status != BookingStatus.cancelled &&
                  b.status != BookingStatus.rejected,
            )
            .toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return BookingsSummary(
      upcoming: rows,
      confirmed: rows.where((b) => b.status == BookingStatus.confirmed).length,
      pending: rows.where((b) => b.status == BookingStatus.pendingProvider).length,
    );
  }
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
    this.weddingRole = '',
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String governorate;
  final String? governorateId;
  final String avatarPath;

  /// `bride` أو `groom` — أو فراغٌ لمن لا عرسَ له.
  ///
  /// **والفراغُ حالٌ صحيحة لا نقص:** من سجّل قبل هذا العمود، ومن جاء ليبيع
  /// لا ليعرس.
  final String weddingRole;

  factory MyProfile.fromMap(Map<String, dynamic> m) => MyProfile(
    id: (m['id'] ?? '') as String,
    fullName: (m['full_name'] ?? '') as String,
    email: (m['email'] ?? '') as String,
    phone: (m['phone'] ?? '') as String,
    governorate: (m['governorate'] ?? '') as String,
    governorateId: m['governorate_id'] as String?,
    avatarPath: (m['avatar_path'] ?? '') as String,
    weddingRole: (m['wedding_role'] ?? '') as String,
  );

  MyProfile copyWith({
    String? fullName,
    String? phone,
    String? avatarPath,
    String? weddingRole,
  }) => MyProfile(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email,
    phone: phone ?? this.phone,
    governorate: governorate,
    governorateId: governorateId,
    avatarPath: avatarPath ?? this.avatarPath,
    weddingRole: weddingRole ?? this.weddingRole,
  );
}

/// اسمُ الدور كما يُعرض. والفراغُ يقع على صفة الحساب لا على «بلا دور».
String weddingRoleLabel(String role, {required bool provider}) => switch (role) {
  'bride' => 'عروس',
  'groom' => 'عريس',
  _ => provider ? 'مقدّم خدمة' : 'عميل',
};

/// عنوانٌ محفوظ — يملأ به نموذجُ الحجز بدل أن يُكتب في كل مرّة.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.details,
    required this.governorate,
    required this.governorateId,
    required this.isDefault,
    this.point,
  });

  final String id;
  final String label;
  final String details;
  final String governorate;
  final String? governorateId;
  final bool isDefault;

  /// نقطةُ العنوان على الخريطة، أو `null` لمن لم يحدّد.
  ///
  /// **والنصُّ يبقى إلزاميّاً فوقها:** الإحداثيّاتُ تصلح للملاحة ولا تُقرأ،
  /// ومن قرأ «١٥٫٣٥، ٤٤٫٢٠» لا يعرف أين هي.
  final GeoPoint? point;

  /// ما يُكتب في `bookings.address`: الاسمُ وحدَه لا يكفي من يبحث عن البيت.
  String get forBooking =>
      [if (governorate.isNotEmpty) governorate, details].join(' — ');

  factory SavedAddress.fromMap(Map<String, dynamic> m) => SavedAddress(
    id: (m['id'] ?? '') as String,
    label: (m['label'] ?? '') as String,
    details: (m['details'] ?? '') as String,
    governorate: (m['governorate'] ?? '') as String,
    governorateId: m['governorate_id'] as String?,
    isDefault: (m['is_default'] ?? false) as bool,
    point: _pointOf(m),
  );
}

/// نقطةٌ من صفٍّ في القاعدة — أو `null` إن نقص أحدُ العمودين.
///
/// **وإمّا الاثنان أو لا شيء:** خطُّ عرضٍ بلا طولٍ يُرسم في خليج غينيا.
/// والقاعدةُ تمنع نصفَ نقطةٍ بقيدٍ، وهذا حارسٌ ثانٍ لصفوفٍ قديمةٍ سبقت القيد.
GeoPoint? _pointOf(Map<String, dynamic> m) {
  final lat = (m['latitude'] as num?)?.toDouble();
  final lng = (m['longitude'] as num?)?.toDouble();
  if (lat == null || lng == null) return null;
  final point = GeoPoint(lat, lng);
  return point.isValid ? point : null;
}

/// محفظةٌ يُحوّل منها المستخدم — لا بطاقةٌ ولا رقمٌ سرّيّ.
class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.id,
    required this.method,
    required this.accountRef,
    required this.holderName,
    required this.isDefault,
  });

  final String id;
  final String method;
  final String accountRef;
  final String holderName;
  final bool isDefault;

  factory SavedPaymentMethod.fromMap(Map<String, dynamic> m) => SavedPaymentMethod(
    id: (m['id'] ?? '') as String,
    method: (m['method'] ?? 'jawali') as String,
    accountRef: (m['account_ref'] ?? '') as String,
    holderName: (m['holder_name'] ?? '') as String,
    isDefault: (m['is_default'] ?? false) as bool,
  );
}

/// إعداداتُ المستخدم.
class UserSettings {
  const UserSettings({this.push = true, this.promos = true});
  final bool push;
  final bool promos;

  factory UserSettings.fromMap(Map<String, dynamic> m) => UserSettings(
    push: (m['push_enabled'] ?? true) as bool,
    promos: (m['promos_enabled'] ?? true) as bool,
  );
}

// ── المحادثة ─────────────────────────────────────────────────────────────────

/// جانبُ من يتكلّم. النصّ هو ما يقبله قيد الجدول حرفياً.
enum ChatSide { customer, provider }

ChatSide chatSideFrom(String raw) =>
    raw == 'provider' ? ChatSide.provider : ChatSide.customer;

String chatSideValue(ChatSide s) => s == ChatSide.provider ? 'provider' : 'customer';

/// محادثةٌ كما تظهر في القائمة — الطرف الآخر وآخر ما قيل وكم لم يُقرأ.
class Conversation {
  const Conversation({
    required this.id,
    required this.providerId,
    required this.otherName,
    required this.mySide,
    required this.lastMessageAt,
    required this.lastMessageBody,
    required this.lastMessageSender,
    required this.unreadCount,
  });

  final String id;
  final String? providerId;

  /// اسم الطرف **الآخر** — تحسبه القاعدة لأن لكل طرفٍ «آخرَ» غير آخر صاحبه.
  final String otherName;
  final ChatSide mySide;
  final String lastMessageAt;
  final String lastMessageBody;
  final ChatSide? lastMessageSender;
  final int unreadCount;

  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
    id: m['id'] as String,
    providerId: m['provider_id'] as String?,
    otherName: (m['other_name'] ?? '') as String,
    mySide: chatSideFrom((m['my_side'] ?? 'customer') as String),
    lastMessageAt: (m['last_message_at'] ?? '') as String,
    lastMessageBody: (m['last_message_body'] ?? '') as String,
    lastMessageSender: m['last_message_sender'] == null
        ? null
        : chatSideFrom(m['last_message_sender'] as String),
    unreadCount: ((m['unread_count'] ?? 0) as num).toInt(),
  );
}

/// نوعُ مرفقٍ في المحادثة — كما يقيّده `message_attachment_kind`.
enum ChatAttachment { image, audio, video, file }

ChatAttachment? chatAttachmentFrom(String? raw) => switch (raw) {
  'image' => ChatAttachment.image,
  'audio' => ChatAttachment.audio,
  'video' => ChatAttachment.video,
  'file' => ChatAttachment.file,
  _ => null,
};

String chatAttachmentValue(ChatAttachment kind) => switch (kind) {
  ChatAttachment.image => 'image',
  ChatAttachment.audio => 'audio',
  ChatAttachment.video => 'video',
  ChatAttachment.file => 'file',
};

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.createdAt,
    this.attachment,
    this.attachmentPath = '',
    this.attachmentSeconds = 0,
    this.attachmentName = '',
    this.attachmentSize = 0,
  });

  final String id;
  final ChatSide sender;
  final String body;
  final String createdAt;

  /// نوعُ المرفق — و`null` لرسالةٍ نصّية.
  final ChatAttachment? attachment;

  /// المسارُ داخل سلّة `chat-media` — لا الرابط.
  ///
  /// **والسلّةُ خاصّة**، فالرابط يُوقَّع عند العرض وينتهي بعد ساعة. ولو خُزّن
  /// رابطٌ جاهزٌ في الصفّ لانتهت صلاحيتُه وبقي يشير إلى لا شيء.
  final String attachmentPath;

  /// للمسموع والمرئيّ وحدهما — والقاعدة ترفض مدّةً على صورة.
  final int attachmentSeconds;

  /// اسمُ الملفّ كما سمّاه صاحبه: «العقد.pdf». ومن يفتح محادثةً بعد شهرٍ
  /// يبحث بالاسم لا بالأيقونة.
  final String attachmentName;
  final int attachmentSize;

  bool get hasAttachment => attachment != null;

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'] as String,
    sender: chatSideFrom((m['sender'] ?? 'customer') as String),
    body: (m['body'] ?? '') as String,
    createdAt: (m['created_at'] ?? '') as String,
    attachment: chatAttachmentFrom(m['attachment_kind'] as String?),
    attachmentPath: (m['attachment_path'] ?? '') as String,
    attachmentSeconds: ((m['attachment_seconds'] ?? 0) as num).toInt(),
    attachmentName: (m['attachment_name'] ?? '') as String,
    attachmentSize: ((m['attachment_size'] ?? 0) as num).toInt(),
  );
}

// ── صندوق الإشعارات ──────────────────────────────────────────────────────────

/// نوع الإشعار كما يقيّده الجدول. أي قيمةٍ خارجها يرفضها القيد.
enum NotificationKind { booking, payment, message, review, dispute, account, reminder, general }

NotificationKind notificationKindFrom(String raw) => switch (raw) {
  'booking' => NotificationKind.booking,
  'payment' => NotificationKind.payment,
  'message' => NotificationKind.message,
  'review' => NotificationKind.review,
  'dispute' => NotificationKind.dispute,
  'account' => NotificationKind.account,
  'reminder' => NotificationKind.reminder,
  _ => NotificationKind.general,
};

/// إشعارٌ في صندوق حسابٍ بعينه.
///
/// و`data` ليست زينة: فيها المعرّفات التي يفتح بها التطبيق الشاشة الصحيحة —
/// `booking_id` أو `conversation_id`. وإشعارٌ لا يُفتح على شيءٍ خبرٌ لا فعل.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? readAt;
  final String createdAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as String,
    kind: notificationKindFrom((m['kind'] ?? 'general') as String),
    title: (m['title'] ?? '') as String,
    body: (m['body'] ?? '') as String,
    data: m['data'] == null
        ? const {}
        : Map<String, dynamic>.from(m['data'] as Map),
    readAt: m['read_at'] as String?,
    createdAt: (m['created_at'] ?? '') as String,
  );
}

/// نزاعٌ على حجز.
///
/// غير تذكرة الدعم: التذكرة سؤالٌ للإدارة عن المنصّة، والنزاع **خصومةٌ بين
/// طرفَي حجز** — لها رقمُ حجزٍ وطرفان ومبلغٌ قد يُعاد. ولذلك لها جدولها
/// وسجلُّها، ولا تُخلط بالأولى.
class Dispute {
  const Dispute({
    required this.id,
    required this.reference,
    required this.bookingId,
    required this.bookingReference,
    required this.openedBy,
    required this.providerName,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    required this.resolution,
    required this.refundAmount,
    required this.createdAt,
    required this.resolvedAt,
  });

  final String id;
  final String reference;
  final String? bookingId;
  final String bookingReference;

  /// `customer` أو `provider` — من فتحه.
  final String openedBy;
  final String providerName;
  final String subject;
  final String description;
  final String category;
  final String status;

  /// ما قرّرته الإدارة عند الحسم، وما أعادته من مال.
  final String resolution;
  final num refundAmount;

  final String createdAt;
  final String? resolvedAt;

  bool get isOpen => status == 'open' || status == 'investigating';

  factory Dispute.fromMap(Map<String, dynamic> m) => Dispute(
    id: m['id'] as String,
    reference: (m['reference'] ?? '') as String,
    bookingId: m['booking_id'] as String?,
    bookingReference: (m['booking_reference'] ?? '') as String,
    openedBy: (m['opened_by'] ?? 'customer') as String,
    providerName: (m['provider_name'] ?? '') as String,
    subject: (m['subject'] ?? '') as String,
    description: (m['description'] ?? '') as String,
    category: (m['category'] ?? 'other') as String,
    status: (m['status'] ?? 'open') as String,
    resolution: (m['resolution'] ?? '') as String,
    refundAmount: (m['refund_amount'] ?? 0) as num,
    createdAt: (m['created_at'] ?? '') as String,
    resolvedAt: m['resolved_at'] as String?,
  );
}

/// رسالةٌ في خيط النزاع — من العميل أو المزوّد أو الإدارة.
class DisputeMessage {
  const DisputeMessage({
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

  factory DisputeMessage.fromMap(Map<String, dynamic> m) => DisputeMessage(
    id: m['id'] as String,
    author: (m['author'] ?? 'customer') as String,
    authorName: (m['author_name'] ?? '') as String,
    body: (m['body'] ?? '') as String,
    createdAt: (m['created_at'] ?? '') as String,
  );
}

/// عمليةُ دفعٍ كما يراها العميل.
class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.reference,
    required this.bookingId,
    required this.bookingReference,
    required this.kind,
    required this.description,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String reference;
  final String? bookingId;
  final String bookingReference;
  final String kind;
  final String description;
  final num amount;
  final String method;

  /// `pending` أو `paid` أو `failed` أو `refunded`.
  final String status;
  final String createdAt;

  bool get isPending => status == 'pending';

  factory PaymentRow.fromMap(Map<String, dynamic> m) => PaymentRow(
    id: m['id'] as String,
    reference: (m['reference'] ?? '') as String,
    bookingId: m['booking_id'] as String?,
    bookingReference: (m['booking_reference'] ?? '') as String,
    kind: (m['kind'] ?? 'deposit') as String,
    description: (m['description'] ?? '') as String,
    amount: (m['amount'] ?? 0) as num,
    method: (m['method'] ?? 'jawali') as String,
    status: (m['status'] ?? 'pending') as String,
    createdAt: (m['created_at'] ?? '') as String,
  );
}

/// أين يُحوَّل المال — يملؤها المسؤول من اللوحة.
///
/// وتُقرأ من القاعدة لا من الشيفرة: الأرقام تتغيّر، وتغييرُها في الشيفرة يعني
/// بناءً جديداً وتحديثاً على كل جهاز.
class PaymentSettings {
  const PaymentSettings({
    required this.jawali,
    required this.kuraimi,
    required this.bank,
    required this.note,
    this.promoDaily = 0,
  });

  final String jawali;
  final String kuraimi;
  final String bank;
  final String note;

  /// سعرُ يومٍ من الظهور المميز. صفرٌ يعني أن البيع لم يُفتح، فيُخفى الشراء.
  final num promoDaily;

  /// هل ضبط المسؤول وسيلةً واحدة على الأقل.
  bool get any => jawali.isNotEmpty || kuraimi.isNotEmpty || bank.isNotEmpty;

  factory PaymentSettings.fromMap(Map<String, dynamic> m) => PaymentSettings(
    jawali: (m['pay_jawali'] ?? '') as String,
    kuraimi: (m['pay_kuraimi'] ?? '') as String,
    bank: (m['pay_bank'] ?? '') as String,
    note: (m['pay_note'] ?? '') as String,
    promoDaily: (m['promo_featured_daily'] ?? 0) as num,
  );
}

/// يومٌ في تقويم مقدّم الخدمة.
///
/// و«من أغلقه» ليس تفصيلاً: يومٌ أغلقته القاعدة بحجزٍ مؤكّد لا يفتحه صاحبه —
/// ولو فُتح لأمكن أن يقع عرسان في ليلة. ويومٌ أغلقه بعذرٍ يفتحه متى شاء.
class DayMark {
  const DayMark({required this.day, required this.blocked, required this.note});

  final DateTime day;
  final bool blocked;
  final String note;

  /// أغلقته القاعدة بحجز، لا صاحبُه بعذر. والعلامة في نصّ الملاحظة نفسه —
  /// تكتبها `api_respond_to_booking` ويقرؤها الحارس في `api_set_availability`.
  bool get byBooking => note.startsWith('محجوز');

  factory DayMark.fromMap(Map<String, dynamic> m) => DayMark(
    day: DateTime.parse(m['day'] as String),
    blocked: (m['is_blocked'] ?? true) as bool,
    note: (m['note'] ?? '') as String,
  );
}

/// مهمّةٌ في قائمة تجهيز العرس.
class PlanTask {
  const PlanTask({
    required this.id,
    required this.title,
    required this.done,
    required this.dueDate,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final bool done;

  /// موعدُها إن حُدِّد. نصٌّ فارغٌ لا `null`: الشاشة تعرضه أو تُخفيه، ولا
  /// تحتاج تمييزاً بين «بلا موعد» و«لم يُقرأ».
  final String dueDate;
  final int sortOrder;

  factory PlanTask.fromMap(Map<String, dynamic> m) => PlanTask(
    id: m['id'] as String,
    title: (m['title'] ?? '') as String,
    done: (m['is_done'] ?? false) as bool,
    dueDate: (m['due_date'] ?? '') as String,
    sortOrder: ((m['sort_order'] ?? 0) as num).toInt(),
  );
}

/// تقدّمُ خطّةٍ — يُحسب في القاعدة لا في الجوال.
class PlanProgress {
  const PlanProgress({
    required this.tasksTotal,
    required this.tasksDone,
    required this.percent,
    required this.upcomingBookings,
  });

  final int tasksTotal;
  final int tasksDone;
  final int percent;
  final int upcomingBookings;

  int get tasksLeft => tasksTotal - tasksDone;

  static const empty = PlanProgress(
    tasksTotal: 0,
    tasksDone: 0,
    percent: 0,
    upcomingBookings: 0,
  );

  factory PlanProgress.fromMap(Map<String, dynamic> m) => PlanProgress(
    tasksTotal: ((m['tasks_total'] ?? 0) as num).toInt(),
    tasksDone: ((m['tasks_done'] ?? 0) as num).toInt(),
    percent: ((m['tasks_percent'] ?? 0) as num).toInt(),
    upcomingBookings: ((m['upcoming_bookings'] ?? 0) as num).toInt(),
  );
}

/// باقةٌ معروضة على مقدّم الخدمة.
class SubPlan {
  const SubPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.days,
    required this.perks,
  });

  final String id;
  final String name;
  final String description;
  final num price;
  final int days;
  final List<String> perks;

  bool get free => price == 0;

  factory SubPlan.fromMap(Map<String, dynamic> m) => SubPlan(
    id: m['id'] as String,
    name: (m['name'] ?? '') as String,
    description: (m['description'] ?? '') as String,
    price: (m['price'] ?? 0) as num,
    days: (m['duration_days'] ?? 30) as int,
    perks: ((m['perks'] ?? const []) as List).map((e) => e.toString()).toList(),
  );
}

/// اشتراكي أنا — حالتُه ومدّته.
class MySub {
  const MySub({
    required this.id,
    required this.planName,
    required this.amount,
    required this.status,
    required this.endsAt,
  });

  final String id;
  final String planName;
  final num amount;
  final String status;
  final DateTime endsAt;

  bool get pending => status == 'pending';
  bool get active => status == 'active';

  factory MySub.fromMap(Map<String, dynamic> m) => MySub(
    id: m['id'] as String,
    planName: (m['plan_name'] ?? '') as String,
    amount: (m['amount'] ?? 0) as num,
    status: (m['status'] ?? 'pending') as String,
    endsAt: DateTime.parse(m['ends_at'] as String),
  );
}

/// فاتورةُ حجز — تُصدرها القاعدة عند التأكيد.
class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.bookingId,
    required this.subtotal,
    required this.commission,
    required this.total,
    required this.status,
    required this.issuedAt,
  });

  final String id;
  final String number;
  final String bookingId;
  final num subtotal;
  final num commission;
  final num total;
  final String status;
  final DateTime issuedAt;

  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
    id: m['id'] as String,
    number: (m['number'] ?? '') as String,
    bookingId: (m['booking_id'] ?? '') as String,
    subtotal: (m['subtotal'] ?? 0) as num,
    commission: (m['commission'] ?? 0) as num,
    total: (m['total'] ?? 0) as num,
    status: (m['status'] ?? 'issued') as String,
    issuedAt: DateTime.parse(m['issued_at'] as String),
  );
}

/// تسويةُ مستحقّات — ما تدين به المنصّة لمقدّم الخدمة عن فترة.
class Settlement {
  const Settlement({
    required this.id,
    required this.reference,
    required this.periodStart,
    required this.periodEnd,
    required this.gross,
    required this.commission,
    required this.net,
    required this.status,
  });

  final String id;
  final String reference;
  final DateTime periodStart;
  final DateTime periodEnd;
  final num gross;
  final num commission;
  final num net;
  final String status;

  factory Settlement.fromMap(Map<String, dynamic> m) => Settlement(
    id: m['id'] as String,
    reference: (m['reference'] ?? '') as String,
    periodStart: DateTime.parse(m['period_start'] as String),
    periodEnd: DateTime.parse(m['period_end'] as String),
    gross: (m['gross_amount'] ?? 0) as num,
    commission: (m['commission_amount'] ?? 0) as num,
    net: (m['net_amount'] ?? 0) as num,
    status: (m['status'] ?? 'pending') as String,
  );
}

/// إعلانٌ قائمٌ في الرئيسية — بطاقةٌ في الشريط.
class PromoSlot {
  const PromoSlot({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.logoPath,
    required this.governorate,
    required this.rating,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String logoPath;
  final String governorate;
  final num rating;

  factory PromoSlot.fromMap(Map<String, dynamic> m) => PromoSlot(
    id: m['id'] as String,
    providerId: (m['provider_id'] ?? '') as String,
    providerName: (m['provider_name'] ?? '') as String,
    logoPath: (m['logo_path'] ?? '') as String,
    governorate: (m['governorate'] ?? '') as String,
    rating: (m['rating'] ?? 0) as num,
  );
}
