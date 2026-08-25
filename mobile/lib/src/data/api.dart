import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, PostgrestException;

import 'models.dart';
import 'supabase.dart';
import 'demo.dart';

/// رمزُ Postgres لعمودٍ لا وجود له.
///
/// يُقارَن به لا بنصّ الرسالة: النصّ إنجليزيٌّ قد يتغيّر بين إصدارات الخادم،
/// والرمز جزءٌ من المعيار.
const undefinedColumn = '42703';

/// ينفّذ القراءةَ الكاملة، فإن أنكرت القاعدةُ عموداً أعاد الأضيق منها.
///
/// **ولماذا هذا موجود:** التطبيق يُحدَّث من متجرٍ أو رابط، والقاعدة تُحدَّث
/// بيد صاحبها في محرّر SQL. فبينهما دائماً نافذةٌ يكون فيها التطبيق أحدثَ من
/// قاعدته — وفي تلك النافذة يجب أن تنقص ميزةٌ لا أن تسقط شاشة.
///
/// وقد سقطت: شاشةُ المزوّد كلُّها صارت رسالةً حمراء لأجل عمود صورة.
Future<T> whenColumnMissing<T>(
  Future<T> Function() full,
  Future<T> Function() lean,
) async {
  try {
    return await full();
  } on PostgrestException catch (e) {
    if (e.code != undefinedColumn) rethrow;
    return await lean();
  }
}

/// كل ما يقرؤه التطبيق أو يكتبه.
///
/// **كل ما يمسّ المال يمرّ بدالة `api_*`** لا بالجداول: الخادم هو من يحسب السعر
/// والعربون والعمولة وسلّم الإلغاء. لو قبِل سعراً من التطبيق لأمكن حجز قاعة
/// بريال واحد.
///
/// وما لا يمسّ المال — خدمات المزوّد وخطة العرس والمستندات — يُكتب مباشرةً على
/// جداوله. ليس تساهلاً: سياسات RLS تحصر الكتابة في صاحب الصفّ
/// (`services_owner_write` و `plans_owner` و `documents_owner_upload`)، ولا شيء
/// في هذه الجداول يحسبه الخادم حتى يُحمى. ودالةٌ تكتفي بتمرير ما أُعطيت إلى
/// `insert` تضيف طبقةً بلا حماية.
class Api {
  // ‎**كل `order` هنا يذكر `ascending` صراحةً — ولو كان صعوداً.**
  //
  // `postgrest` في Dart افتراضُها `ascending: false`، أي أن `.order('created_at')`
  // تعني **نزولاً**. وهي عكسُ نظيرتها في JavaScript (‏`ascending = true`‏)،
  // فمن قرأ وثائق Supabase أو نقل سطراً من اللوحة وقع فيها.
  //
  // وقد وقعتُ فيها في تسعة مواضع: المحادثة كانت تُقرأ من أسفل إلى أعلى،
  // والأقسام الاثنا عشر معكوسة، والحجوزات أبعدُها موعداً أوّلاً. ولم يكشفها
  // اختبارٌ واحد لأن وضع العرض يرتّب في الذاكرة ولا يمرّ بـ`postgrest` أصلاً
  // — أي أن الطريق الذي كُسر هو الطريق الوحيد الذي لا تسلكه الاختبارات.
  //
  // ويحرسه الآن `api_order_test.dart`: يقرأ هذا الملف ويسقط عند أوّل
  // `order` بلا `ascending`.

  // ----- المرجعيات والاستكشاف -----

  static Future<List<Governorate>> governorates() async {
    if (!isSupabaseConfigured) return demoDelay(demoGovernorates);
    final rows = await db
        .from('governorates')
        .select('id, name')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows.map(Governorate.fromMap).toList();
  }

  static Future<List<ServiceCategory>> categories() async {
    if (!isSupabaseConfigured) return demoDelay(demoCategories);
    final rows = await db
        .from('service_categories')
        .select('id, name, slug')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows.map(ServiceCategory.fromMap).toList();
  }

  /// و`governorate` **اسمُ محافظةٍ لا معرّفُها**: `v_services` تُعيد اسمها
  /// (`provider_governorate`) لأنها معدّةٌ للعرض، و`governorates` جدولٌ
  /// أسماؤه هي التي تُطابَق. ومن رشّح بالمعرّف هنا لم يجد شيئاً وظنّ أن لا
  /// خدمة في المحافظة.
  static Future<List<ServiceItem>> services({
    String? search,
    String? categoryId,
    String? governorate,
  }) async {
    if (!isSupabaseConfigured) {
      final term = (search ?? '').trim().toLowerCase();
      return demoDelay(
        demoServices.where((s) {
          if (categoryId != null && s.categoryId != categoryId) return false;
          if (governorate != null && s.providerGovernorate != governorate) return false;
          if (term.isEmpty) return true;
          return s.title.toLowerCase().contains(term) ||
              s.providerName.toLowerCase().contains(term);
        }).toList(),
      );
    }

    var query = db.from('v_services').select();
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (governorate != null) query = query.eq('provider_governorate', governorate);
    final term = (search ?? '').trim();
    if (term.isNotEmpty) {
      final safe = term.replaceAll(RegExp(r'[,()]'), ' ');
      query = query.or('title.ilike.%$safe%,provider_name.ilike.%$safe%');
    }
    // المميَّزون أولاً ثم الأعلى تقييماً — وهو ما تبيعه المنصة في «الحملات».
    final rows = await query
        .order('provider_is_featured', ascending: false)
        .order('provider_rating', ascending: false)
        .limit(40);
    return rows.map(ServiceItem.fromMap).toList();
  }

  static Future<ServiceItem?> service(String id) async {
    if (!isSupabaseConfigured) {
      final match = demoServices.where((s) => s.id == id).firstOrNull;
      return demoDelay(match);
    }
    final row = await db.from('v_services').select().eq('id', id).maybeSingle();
    return row == null ? null : ServiceItem.fromMap(row);
  }

  // ----- ملفّ مقدّم الخدمة كما يراه العميل -----
  //
  // لا دالّةَ `api_*` هنا ولا ملفَّ SQL جديد: الطريقة `v_providers` وجدولُ
  // `reviews` موجودان منذ أوّل مخطّط، وسياساتُهما تكفي — الموثَّقون وحدهم
  // ظاهرون، والمنشورُ من التقييمات وحده يُقرأ. فما يُقرأ هنا هو ما سمحت به
  // القاعدة، لا ما اختار التطبيق أن يُظهره.

  static Future<PublicProvider?> provider(String id) async {
    if (!isSupabaseConfigured) {
      return demoDelay(demoProviders.where((p) => p.id == id).firstOrNull);
    }
    final row = await db.from('v_providers').select().eq('id', id).maybeSingle();
    return row == null ? null : PublicProvider.fromMap(row);
  }

  /// دليلُ المزوّدين — يُتصفَّحون أنفسُهم لا خدماتُهم.
  ///
  /// **ولماذا:** من يبحث عن قاعةٍ يقارن خدمات، ومن يبحث عن **منسّق حفلات**
  /// أو مصوّرٍ يقارن أشخاصاً: كم عرساً نفّذ، وما تقييمه، وماذا يعرض كلَّه.
  /// وقائمةٌ من خدماتٍ متفرّقة تُخفي ذلك خلف عناوين الباقات.
  ///
  /// والترشيح بالاسم لا بالمعرّف: `v_providers` تُعيد أسماء الأقسام لا
  /// معرّفاتها — وهي معرّفةٌ للعرض. و`contains` تقابل `@>` في Postgres.
  static Future<List<PublicProvider>> providers({
    String? search,
    String? categoryName,
    String? governorate,
  }) async {
    if (!isSupabaseConfigured) {
      final term = (search ?? '').trim().toLowerCase();
      return demoDelay(
        demoProviders.where((p) {
          if (categoryName != null && !p.categories.contains(categoryName)) return false;
          if (governorate != null && p.governorate != governorate) return false;
          if (term.isEmpty) return true;
          return p.businessName.toLowerCase().contains(term) ||
              p.bio.toLowerCase().contains(term);
        }).toList(),
      );
    }
    var query = db.from('v_providers').select();
    if (categoryName != null) query = query.contains('categories', [categoryName]);
    if (governorate != null) query = query.eq('governorate', governorate);
    final term = (search ?? '').trim();
    if (term.isNotEmpty) {
      query = query.ilike('business_name', '%${term.replaceAll(RegExp(r'[,()]'), ' ')}%');
    }
    final rows = await query
        .order('is_featured', ascending: false)
        .order('rating', ascending: false)
        .limit(40);
    return rows.map(PublicProvider.fromMap).toList();
  }

  /// خدماتُ مزوّدٍ بعينه.
  ///
  /// من `v_services` لا من `provider_services`: سياسةُ الأولى تُخفي المعطَّل
  /// وغيرَ الموثَّق، وتأتي معها أسماءُ الأقسام والأغلفة في صفٍّ واحد.
  static Future<List<ServiceItem>> providerServices(String providerId) async {
    if (!isSupabaseConfigured) {
      return demoDelay(demoServices.where((s) => s.providerId == providerId).toList());
    }
    final rows = await db
        .from('v_services')
        .select()
        .eq('provider_id', providerId)
        .order('price', ascending: true);
    return rows.map(ServiceItem.fromMap).toList();
  }

  /// آراءُ العملاء — الأحدثُ أوّلاً.
  static Future<List<Review>> providerReviews(String providerId) async {
    if (!isSupabaseConfigured) return demoDelay(demoReviewsOf(providerId));
    final rows = await db
        .from('reviews')
        .select('id, user_name, rating, comment, created_at')
        .eq('provider_id', providerId)
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map(Review.fromMap).toList();
  }

  // ----- الحساب -----

  /// معرّف الصفّ في `app_users`، أو null إن لم يُكمل ملفه بعد.
  ///
  /// يُقرأ من الجدول لا بدالة: `current_app_user()` مساعدةٌ داخلية لم تُمنح
  /// صلاحية تنفيذها لـ `authenticated`، وسياسة القراءة الذاتية تكفي.
  static Future<String?> myAppUserId() async {
    if (!isSupabaseConfigured) return 'demo-user';
    final uid = db.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await db.from('app_users').select('id').eq('auth_user_id', uid).maybeSingle();
    return row?['id'] as String?;
  }

  static Future<String?> myProviderId(String appUserId) async {
    if (!isSupabaseConfigured) return demoProviderId;
    final row = await db
        .from('service_providers')
        .select('id')
        .eq('user_id', appUserId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  static Future<void> registerProfile({
    required String fullName,
    required String phone,
    required String governorate,
    required String platform,
  }) async {
    if (!isSupabaseConfigured) return;
    await db.rpc(
      'api_register_profile',
      params: {
        'p_full_name': fullName,
        'p_phone': phone,
        'p_governorate': governorate,
        'p_platform': platform,
      },
    );
  }

  static Future<void> applyAsProvider({
    required String businessName,
    required String phone,
    required String bio,
    required String governorate,
    required List<String> categoryIds,
  }) async {
    if (!isSupabaseConfigured) {
      demoBecomeProvider(businessName: businessName, governorate: governorate, bio: bio);
      return;
    }
    await db.rpc(
      'api_apply_as_provider',
      params: {
        'p_business_name': businessName,
        'p_phone': phone,
        'p_bio': bio,
        'p_governorate': governorate,
        'p_category_ids': categoryIds,
      },
    );
  }

  /// محاكاة توثيق الإدارة — لا أثر لها إلا في الوضع التجريبي.
  static void approveProviderInDemo() {
    if (isSupabaseConfigured) return;
    demoApproveProvider();
  }

  static Future<ProviderProfile?> providerProfile(String providerId) async {
    if (!isSupabaseConfigured) return demoDelay(demoProviderProfile);

    // **العمود قد لا يكون في القاعدة بعد.**
    //
    // من لم يشغّل `provider_logo.sql` كانت شاشتُه كلُّها تسقط برسالةٍ حمراء —
    // `column service_providers.logo_path does not exist` — لأجل صورةٍ زينة.
    // وهذا وقع على جهاز صاحب المنتج.
    //
    // فتُقرأ مرّةً بالعمود، وإن أنكرته القاعدة (‏`42703`‏) أُعيدت القراءة
    // بدونه. والشاشة تعمل كما كانت، ويبقى الشعار حرفاً في قرص حتى يُشغَّل
    // الملف — وهو الفرق بين ميزةٍ لم تصل وشاشةٍ مكسورة.
    Future<Map<String, dynamic>?> read(String columns) => db
        .from('service_providers')
        .select(columns)
        .eq('id', providerId)
        .maybeSingle();

    const base = 'id, full_name, business_name, governorate, bio, status, rating, '
        'reviews_count, completed_bookings, total_earnings, rejection_reason';

    final row = await whenColumnMissing(
      () => read('$base, logo_path'),
      () => read(base),
    );
    return row == null ? null : ProviderProfile.fromMap(row);
  }

  /// يرفع شعار المزوّد ويعيد مساره.
  ///
  /// في سلّة `avatars` نفسها وفي مجلّد صاحب الحساب: سياستُها تحصر الكتابة في
  /// `<auth_user_id>/…`، فلا يكتب أحدٌ فوق شعار غيره. واسمٌ ثابت مع `upsert`
  /// كي لا تتراكم الصور القديمة بلا حذف.
  static Future<String> uploadProviderLogo({
    required String authUserId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final path = '$authUserId/provider.$ext';
    if (!isSupabaseConfigured) return path;
    await db.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: _mimeOf(ext), upsert: true),
    );
    return path;
  }

  /// يحفظ ما يعرضه المزوّد عن نفسه.
  ///
  /// `update` مباشر لا دالّة `api_*`: سياسةُ `providers_self_update` تحصره في
  /// صفّه، والمُشغِّل `guard_provider_self_update` يمنعه من مسّ الحالة
  /// والتوثيق والعمولة والتقييم. فدالّةٌ تكتفي بتمرير ما أُعطيت تضيف طبقةً بلا
  /// حماية.
  static Future<void> updateProviderProfile({
    required String providerId,
    String? businessName,
    String? bio,
    String? logoPath,
  }) async {
    final values = <String, dynamic>{
      'business_name': ?businessName,
      'bio': ?bio,
      'logo_path': ?logoPath,
    };
    if (values.isEmpty) return;
    if (!isSupabaseConfigured) {
      demoUpdateProviderProfile(businessName: businessName, bio: bio, logoPath: logoPath);
      return;
    }
    try {
      await db.from('service_providers').update(values).eq('id', providerId);
    } on PostgrestException catch (e) {
      // ونصٌّ عربيٌّ يقول ما يُفعل بدل رسالةِ Postgres: صاحبُ القاعة لا يعرف
      // ما «42703»، ويعرف تماماً معنى «شغّل هذا الملف».
      if (e.code == undefinedColumn && e.message.contains('logo_path')) {
        throw 'قاعدتك لم تُحدَّث بعد: شغّل ملف supabase/provider_logo.sql ثم أعد المحاولة.';
      }
      rethrow;
    }
  }

  // ----- الحجوزات -----

  /// حجوزات المستخدم بوصفه **عميلاً**.
  ///
  /// الشرط ضروري ولا تكفي RLS: سياسة الحجوزات تُرجع للمستخدم ما حجزه *وما
  /// وصله بوصفه مقدّم خدمة* — «الحجز يراه طرفاه». ومن يجمع الصفتين — وهو ما
  /// يقصده التطبيق أصلاً — كان يرى مبيعاته مختلطةً بمشترياته في الشاشتين معاً.
  static Future<List<Booking>> myBookings(String appUserId) async {
    if (!isSupabaseConfigured) return demoDelay(demoBookings);
    final rows = await db.from('bookings').select().eq('user_id', appUserId).order('event_date', ascending: true);
    return rows.map(Booking.fromMap).toList();
  }

  /// الطلبات الواردة إلى المستخدم بوصفه **مقدّم خدمة** — الوجه الآخر للسياسة.
  static Future<List<Booking>> providerRequests(String providerId) async {
    if (!isSupabaseConfigured) return demoDelay(demoProviderRequests);
    final rows = await db
        .from('bookings')
        .select()
        .eq('provider_id', providerId)
        .order('event_date', ascending: true);
    return rows.map(Booking.fromMap).toList();
  }

  static Future<Booking> createBooking({
    required String serviceId,
    required String eventDate,
    String? eventTime,
    required int guests,
    required String address,
    String notes = '',

    /// خطة العرس التي يُضاف إليها الحجز، إن كانت للعميل خطة.
    ///
    /// كان يُمرَّر `null` دائماً، فلا يرتبط حجزٌ بخطة أبداً، وتبقى «إجمالي
    /// الحجوزات» و«المدفوع» و«المتبقّي عليك» أصفاراً في شاشة الخطة مهما حجز.
    /// والبيانات التجريبية كانت تخفي ذلك لأن أرقامها مكتوبةٌ بخط اليد.
    String? planId,
  }) async {
    if (!isSupabaseConfigured) {
      return demoDelay(demoCreateBooking(serviceId, eventDate, eventTime, guests, address));
    }
    final result = await db.rpc(
      'api_create_booking',
      params: {
        'p_service_id': serviceId,
        'p_event_date': eventDate,
        'p_event_time': eventTime,
        'p_plan_id': planId,
        'p_guests_count': guests,
        'p_address': address,
        'p_notes': notes,
        'p_pay_full': false,
      },
    );
    final map = result is List ? result.first : result;
    return Booking.fromMap(Map<String, dynamic>.from(map as Map));
  }

  static Future<void> respondToBooking(String id, bool accept, {String reason = ''}) async {
    if (!isSupabaseConfigured) {
      demoRespond(id, accept);
      return;
    }
    await db.rpc(
      'api_respond_to_booking',
      params: {'p_booking_id': id, 'p_accept': accept, 'p_reason': reason},
    );
  }

  static Future<void> completeBooking(String id) async {
    if (!isSupabaseConfigured) {
      demoComplete(id);
      return;
    }
    await db.rpc('api_complete_booking', params: {'p_booking_id': id});
  }

  /// الإلغاء من جهة العميل. المبلغ المستردّ يحسبه الخادم من سلّم الإلغاء
  /// المنسوخ في الحجز وقت إنشائه، فلا يتغيّر بتغيّر سياسة المزوّد بعده.
  static Future<void> cancelBooking(String id, {String reason = ''}) async {
    if (!isSupabaseConfigured) {
      demoCancel(id);
      return;
    }
    await db.rpc('api_cancel_booking', params: {'p_booking_id': id, 'p_reason': reason});
  }

  // ----- التقييمات -----

  static Future<void> submitReview(String bookingId, int rating, String comment) async {
    if (!isSupabaseConfigured) {
      demoReview(bookingId, rating);
      return;
    }
    await db.rpc(
      'api_submit_review',
      params: {'p_booking_id': bookingId, 'p_rating': rating, 'p_comment': comment},
    );
  }

  /// الحجوزات المنفَّذة التي قُيّمت — لإخفاء زرّ التقييم عمّا قُيّم.
  ///
  /// `reviews` فيه قيد `unique (booking_id)`، فالتقييم مرّةٌ واحدة؛ وإظهار الزرّ
  /// بعدها يَعِد بما سيرفضه الخادم.
  static Future<Set<String>> reviewedBookingIds(List<String> bookingIds) async {
    // نسخةٌ لا الأصل: القاعدة تبني مجموعةً جديدة كل مرة، فلو أعاد الوضع
    // التجريبي مجموعته نفسها لصارت حالةُ الشاشة هي حالةَ «الخادم» — فيلغي
    // التبديلُ المتفائل في الواجهة تبديلَ الخادم، ولا يتغيّر شيء.
    if (!isSupabaseConfigured) return {...demoReviewedBookings};
    if (bookingIds.isEmpty) return {};
    final rows = await db.from('reviews').select('booking_id').inFilter('booking_id', bookingIds);
    return rows.map((r) => r['booking_id'] as String).toSet();
  }

  // ----- المفضّلة -----

  static Future<Set<String>> myFavourites() async {
    if (!isSupabaseConfigured) return {...demoFavourites};
    final rows = await db.from('favourites').select('service_id');
    return rows.map((r) => r['service_id'] as String).toSet();
  }

  static Future<void> toggleFavourite(String serviceId) async {
    if (!isSupabaseConfigured) {
      demoToggleFavourite(serviceId);
      return;
    }
    await db.rpc('api_toggle_favourite', params: {'p_service_id': serviceId});
  }

  // ----- خطة العرس -----

  static Future<List<WeddingPlan>> myPlans() async {
    if (!isSupabaseConfigured) return demoDelay(demoPlans);
    final rows = await db.from('v_plan_summary').select().order('wedding_date', ascending: true);
    return rows.map(WeddingPlan.fromMap).toList();
  }

  /// إنشاء الخطة أو تعديلها. كتابةٌ مباشرة تحرسها سياسة `plans_owner`.
  static Future<void> savePlan({
    String? id,
    required String appUserId,
    required String title,
    required String weddingDate,
    required String governorate,
    required int guests,
    required num budget,
  }) async {
    final values = {
      'title': title,
      'wedding_date': weddingDate,
      'governorate': governorate,
      'guests_count': guests,
      'budget': budget,
    };
    if (!isSupabaseConfigured) {
      demoSavePlan(id: id, values: values);
      return;
    }
    if (id == null) {
      await db.from('wedding_plans').insert({...values, 'user_id': appUserId});
    } else {
      await db.from('wedding_plans').update(values).eq('id', id);
    }
  }

  // ----- خدمات مقدّم الخدمة -----

  /// خدماتي أنا — المعطَّلة منها كذلك، وهي التي تُخفيها `v_services`.
  static Future<List<MyService>> myServices(String providerId) async {
    if (!isSupabaseConfigured) return demoDelay(demoMyServices);
    final rows = await db
        .from('provider_services')
        .select(
          'id, title, description, price, price_to, unit, deposit_percent, category_id, is_active',
        )
        .eq('provider_id', providerId)
        .order('created_at', ascending: false);
    return rows.map(MyService.fromMap).toList();
  }

  static Future<void> saveService({
    String? id,
    required String providerId,
    required String title,
    required String description,
    required String categoryId,
    required num price,
    num? priceTo,
    required String unit,
    required int depositPercent,
  }) async {
    final values = {
      'title': title,
      'description': description,
      'category_id': categoryId,
      'price': price,
      'price_to': priceTo,
      'unit': unit,
      'deposit_percent': depositPercent,
    };
    if (!isSupabaseConfigured) {
      demoSaveService(id: id, values: values);
      return;
    }
    if (id == null) {
      await db.from('provider_services').insert({...values, 'provider_id': providerId});
    } else {
      await db.from('provider_services').update(values).eq('id', id);
    }
  }

  /// الإيقاف لا الحذف: الخدمة مرتبطةٌ بحجوزات قائمة، وحذفها يقطع سجلّها.
  static Future<void> setServiceActive(String id, bool active) async {
    if (!isSupabaseConfigured) {
      demoSetServiceActive(id, active);
      return;
    }
    await db.from('provider_services').update({'is_active': active}).eq('id', id);
  }

  // ----- الإشعارات -----

  /// صندوقي. وسياسة `notifications_owner_read` هي التي تحصره فيّ — لا شرطٌ
  /// أكتبه هنا: العميل لا يعرف معرّفه في `app_users` أصلاً.
  static Future<List<AppNotification>> myNotifications({int limit = 60}) async {
    if (!isSupabaseConfigured) return demoDelay(demoNotificationList());
    final rows = await db
        .from('notifications')
        .select('id, kind, title, body, data, read_at, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AppNotification.fromMap).toList();
  }

  /// بثٌّ حيٌّ للإشعارات الواصلة — لعرضها والتطبيق مفتوح.
  ///
  /// **ولماذا لا يكفي الدفع:** إشعار شريط النظام لا يظهر أصلاً والتطبيق أمام
  /// المستخدم، فمن كان يتصفّح لحظةَ قَبولِ حجزه لا يعلم — والجرسُ في الأعلى
  /// يزيد رقماً لا ينظر إليه أحد. وهذا يعمل بلا Firebase ولا إعداد: الجدول
  /// في نشرة البثّ منذ `notifications.sql`.
  ///
  /// والسياسة تحصر الصفوف في صفوف المتصل، فلا شرط هنا.
  static Stream<List<AppNotification>>? notificationStream() {
    if (!isSupabaseConfigured) return null;
    return db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(5)
        .map((rows) => rows.map(AppNotification.fromMap).toList());
  }

  static Future<void> markNotificationRead(String id) async {
    if (!isSupabaseConfigured) {
      demoMarkNotificationRead(id);
      return;
    }
    await db
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// «علّم الكلّ مقروءاً» — جملةٌ لا يستطيع التطبيق كتابتها بنفسه بأمان.
  static Future<void> markAllNotificationsRead() async {
    if (!isSupabaseConfigured) {
      demoMarkAllNotificationsRead();
      return;
    }
    await db.rpc('api_mark_all_notifications_read');
  }

  /// يسجّل رمز جهاز الدفع. يُستدعى عند كل إقلاع — الرمز يتغيّر بلا إشعار.
  static Future<void> registerPushToken({
    required String token,
    required String platform,
    String model = '',
    String osVersion = '',
  }) async {
    if (!isSupabaseConfigured) return;
    await db.rpc('api_register_push_token', params: {
      'p_token': token,
      'p_platform': platform,
      'p_model': model,
      'p_os_version': osVersion,
    });
  }

  /// ينسى الرمز عند الخروج — وإلّا وصلت إشعاراتُ الحساب إلى جهازٍ غادره.
  static Future<void> forgetPushToken(String token) async {
    if (!isSupabaseConfigured) return;
    await db.rpc('api_forget_push_token', params: {'p_token': token});
  }

  // ----- المحادثة -----

  /// محادثاتي مرتّبةً بالأحدث.
  ///
  /// من `v_my_conversations` لا من الجدول: الطريقة تحسب اسم الطرف الآخر وعدد
  /// ما لم يُقرأ في صفٍّ واحد. وحسابُهما في التطبيق يعني نداءً لكل محادثة.
  static Future<List<Conversation>> myConversations() async {
    if (!isSupabaseConfigured) return demoDelay(demoConversationList());
    final rows = await db
        .from('v_my_conversations')
        .select()
        .order('last_message_at', ascending: false);
    return rows.map(Conversation.fromMap).toList();
  }

  /// يفتح المحادثة مع مقدّم الخدمة أو يعيد القائمة.
  ///
  /// دالّةٌ في القاعدة لا بحثٌ ثم إنشاء من هنا: الثاني ينتج خيطين حين تُضغط
  /// الزرّ مرّتين بسرعة، فتنقسم الرسائل بينهما ولا يرى أحدٌ نصفها.
  static Future<String> openConversation(String providerId, {String? bookingId}) async {
    if (!isSupabaseConfigured) return demoOpenConversation(providerId);
    final id = await db.rpc(
      'api_open_conversation',
      params: {'p_provider_id': providerId, 'p_booking_id': bookingId},
    );
    return id as String;
  }

  /// يفتحها مقدّمُ الخدمة على حجزٍ له.
  static Future<String> openConversationWithCustomer(String bookingId) async {
    if (!isSupabaseConfigured) return demoOpenConversationWithCustomer(bookingId);
    final id = await db.rpc(
      'api_open_conversation_with_customer',
      params: {'p_booking_id': bookingId},
    );
    return id as String;
  }

  static Future<List<ChatMessage>> conversationMessages(String conversationId) async {
    if (!isSupabaseConfigured) return demoDelay(demoMessagesOf(conversationId));
    final rows = await db
        .from('conversation_messages')
        .select('id, sender, body, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return rows.map(ChatMessage.fromMap).toList();
  }

  /// بثٌّ حيٌّ لرسائل محادثة.
  ///
  /// بدونه لا تصل الرسالة حتى يُغلق الطرف الآخر الشاشة ويفتحها — وهذه ليست
  /// محادثة. ويعمل البثّ متى أُضيف الجدول إلى نشرة Supabase (وهو ما يفعله
  /// `chat.sql`)؛ وإن لم يُضَف وصلت الدفعة الأولى ولم تصل التالية، فتبقى
  /// الشاشة صحيحةً ناقصةَ الحياة لا مكسورة.
  static Stream<List<ChatMessage>>? conversationStream(String conversationId) {
    if (!isSupabaseConfigured) return null;
    return db
        .from('conversation_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(ChatMessage.fromMap).toList());
  }

  static Future<void> sendChatMessage({
    required String conversationId,
    required ChatSide sender,
    required String body,
  }) async {
    if (!isSupabaseConfigured) {
      demoSendMessage(conversationId, sender, body);
      return;
    }
    await db.from('conversation_messages').insert({
      'conversation_id': conversationId,
      'sender': chatSideValue(sender),
      'body': body,
    });
  }

  /// يعلّم المحادثة مقروءةً عند المتصل وحده.
  static Future<void> markConversationRead(String conversationId) async {
    if (!isSupabaseConfigured) {
      demoMarkRead(conversationId);
      return;
    }
    await db.rpc('api_mark_conversation_read', params: {'p_conversation_id': conversationId});
  }

  // ----- وسائط الخدمة -----

  /// حدود الوسائط — واحدةٌ في التطبيق ومثلُها في القاعدة.
  ///
  /// والتكرار مقصود: القاعدة هي الحارس (مُشغِّلٌ وقيد)، والتطبيق يمنع الرحلة
  /// أصلاً. فمن رفع ملفاً بخمسين ميجابايت ثم رُدّ من الخادم دفع الشبكة كلَّها
  /// ليقرأ «لا» — وشبكةُ الجوال هنا ليست سخيّة.
  static const int mediaMaxImages = 8;
  static const int mediaMaxSeconds = 60;
  static const int mediaMaxBytes = 52428800;

  /// وسائط خدمةٍ مرتّبةً كما رتّبها صاحبها.
  static Future<List<ServiceMedia>> serviceMedia(String serviceId) async {
    if (!isSupabaseConfigured) return demoDelay(demoMediaOf(serviceId));
    final rows = await db
        .from('service_media')
        .select('id, kind, path, title, duration_seconds, size_bytes, sort_order')
        .eq('service_id', serviceId)
        .order('kind', ascending: true)
        .order('sort_order', ascending: true);
    return rows.map(ServiceMedia.fromMap).toList();
  }

  /// يرفع الملف ثم يسجّله.
  ///
  /// الترتيب مقصود كما في المستندات: لو سُجّل الصفّ أولاً وفشل الرفع لبقي في
  /// الشاشة وسيطٌ يشير إلى ملفٍ ليس هناك، فيظهر مربّعٌ مكسور لكل من فتح
  /// الخدمة.
  ///
  /// والمسار `<provider_id>/<service_id>/<ختم>.<امتداد>` كما تشترطه سياسة
  /// السلّة: أوّل جزءٍ منه يجب أن يساوي معرّف المزوّد وإلّا رُفض الرفع.
  static Future<void> uploadServiceMedia({
    required String providerId,
    required String serviceId,
    required MediaKind kind,
    required String fileName,
    required Uint8List bytes,
    int durationSeconds = 0,
    int sortOrder = 0,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final path = '$providerId/$serviceId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    if (!isSupabaseConfigured) {
      demoAddMedia(serviceId, kind, path, durationSeconds, bytes.length, sortOrder);
      return;
    }
    await db.storage.from('service-media').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mediaMimeOf(ext)),
    );
    try {
      await db.from('service_media').insert({
        'service_id': serviceId,
        'provider_id': providerId,
        'kind': mediaKindValue(kind),
        'path': path,
        'duration_seconds': durationSeconds,
        'size_bytes': bytes.length,
        'sort_order': sortOrder,
      });
    } catch (e) {
      // فشل التسجيل بعد نجاح الرفع يترك ملفاً في السلّة لا يشير إليه صفّ —
      // لا يراه أحد ولا يحذفه أحد، ويُحسب في الفاتورة إلى الأبد.
      await db.storage.from('service-media').remove([path]);
      rethrow;
    }
  }

  /// يحذف الصفّ والملف معاً.
  ///
  /// والصفّ أولاً: لو حُذف الملف ثم فشل حذف الصفّ لبقي في الشاشة وسيطٌ
  /// مكسور — وهو أسوأ من ملفٍ زائدٍ لا يراه أحد.
  static Future<void> deleteServiceMedia(ServiceMedia media) async {
    if (!isSupabaseConfigured) {
      demoRemoveMedia(media.id);
      return;
    }
    await db.from('service_media').delete().eq('id', media.id);
    await db.storage.from('service-media').remove([media.path]);
  }

  /// الرابط العلنيّ للوسيط — السلّة عامّة فلا توقيع ينتهي.
  static String? mediaUrl(String? path) {
    if (path == null || path.isEmpty || !isSupabaseConfigured) return null;
    return db.storage.from('service-media').getPublicUrl(path);
  }

  /// السلّة تقبل هذه الأنواع وحدها، ورفعُ ملفٍ بنوعٍ غيرها يُرفض من الخادم.
  static String mediaMimeOf(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    '3gp' => 'video/3gpp',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'ogg' || 'oga' => 'audio/ogg',
    'wav' => 'audio/wav',
    _ => 'image/jpeg',
  };

  // ----- مستندات التوثيق -----

  static Future<List<ProviderDocument>> myDocuments(String providerId) async {
    if (!isSupabaseConfigured) return demoDelay(demoDocuments);
    final rows = await db
        .from('provider_documents')
        .select('id, type, file_name, file_url, status, note, uploaded_at')
        .eq('provider_id', providerId)
        .order('uploaded_at', ascending: false);
    return rows.map(ProviderDocument.fromMap).toList();
  }

  /// يرفع الملف ثم يسجّله.
  ///
  /// الترتيب مقصود: لو سُجّل الصفّ أولاً وفشل الرفع لبقي في اللوحة مستندٌ
  /// «قيد المراجعة» بلا ملف، ينتظره المسؤول ولا يجده.
  ///
  /// والمسار `<provider_id>/<uuid>.<ext>` كما تشترطه سياسة الحاوية: أول جزء
  /// من المسار يجب أن يساوي معرّف المزوّد، وإلا رُفض الرفع.
  // ── الملف الشخصي ──────────────────────────────────────────────────────────

  /// ملفّي كما هو في القاعدة.
  static Future<MyProfile?> myProfile() async {
    if (!isSupabaseConfigured) return demoProfile();
    final row = await db.rpc('api_my_profile');
    if (row == null) return null;
    return MyProfile.fromMap(Map<String, dynamic>.from(row as Map));
  }

  /// يحفظ ما عُدّل. وما لم يُمرَّر لا يُمسّ — فمن غيّر اسمه لا يُفرَّغ جواله.
  static Future<MyProfile> updateProfile({
    required String fullName,
    String? phone,
    String? governorateId,
    String? avatarPath,
  }) async {
    if (!isSupabaseConfigured) {
      return demoUpdateProfile(fullName, phone, governorateId, avatarPath);
    }
    final row = await db.rpc('api_update_profile', params: {
      'p_full_name': fullName,
      'p_phone': phone,
      'p_governorate_id': governorateId,
      'p_avatar_path': avatarPath,
    });
    return MyProfile.fromMap(Map<String, dynamic>.from(row as Map));
  }

  /// يرفع الصورة ويعيد مسارها داخل السلّة.
  ///
  /// اسمٌ ثابت `avatar.<ext>` مع `upsert`: صورةُ الملف واحدةٌ تُستبدل، ولو
  /// حمل كلُّ رفعٍ اسماً جديداً لتراكمت الصور القديمة في السلّة بلا حذف.
  static Future<String> uploadAvatar({
    required String authUserId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final path = '$authUserId/avatar.$ext';
    if (!isSupabaseConfigured) return path;
    await db.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: _mimeOf(ext), upsert: true),
    );
    return path;
  }

  /// الرابط العلنيّ للصورة — السلّة عامّة فلا حاجة إلى توقيعٍ ينتهي.
  ///
  /// و`?v=` بختمٍ زمنيّ: بلا فرقٍ في العنوان يعرض المتصفّح والتطبيق الصورةَ
  /// القديمة من ذاكرتهما بعد الاستبدال، فيبدو الرفعُ وكأنه لم يقع.
  static String? avatarUrl(String path, {int? version}) {
    if (path.isEmpty) return null;
    if (!isSupabaseConfigured) return null;
    final url = db.storage.from('avatars').getPublicUrl(path);
    return version == null ? url : '$url?v=$version';
  }

  static Future<void> uploadDocument({
    required String providerId,
    required String type,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!isSupabaseConfigured) {
      demoAddDocument(type, fileName);
      return;
    }
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'bin';
    final path = '$providerId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await db.storage
        .from('provider-docs')
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: _mimeOf(ext)));
    await db.from('provider_documents').insert({
      'provider_id': providerId,
      'type': type,
      'file_name': fileName,
      'file_url': path,
    });
  }

  /// الحاوية تقبل هذه الأنواع وحدها، ورفعُ ملفٍ بنوعٍ غيرها يُرفض من الخادم.
  static String _mimeOf(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };

  // ----- خدمة العملاء -----

  static Future<List<SupportTicket>> myTickets() async {
    if (!isSupabaseConfigured) return demoDelay(demoTickets);
    final rows = await db
        .from('support_tickets')
        .select('id, reference, subject, status, last_message_at')
        .order('last_message_at', ascending: false);
    return rows.map(SupportTicket.fromMap).toList();
  }

  static Future<List<SupportMessage>> ticketMessages(String ticketId) async {
    if (!isSupabaseConfigured) return demoDelay(demoTicketMessages);
    // الملاحظات الداخلية محجوبة بسياسة RLS لا باستعلام — لا شرط عليها هنا.
    final rows = await db
        .from('support_messages')
        .select('id, author, author_name, body, created_at')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return rows.map(SupportMessage.fromMap).toList();
  }

  static Future<void> openTicket({
    required String subject,
    required String body,
    required String category,
    bool asProvider = false,
  }) async {
    if (!isSupabaseConfigured) {
      demoOpenTicket(subject);
      return;
    }
    await db.rpc(
      'api_open_ticket',
      params: {
        'p_subject': subject,
        'p_body': body,
        'p_category': category,
        'p_booking_id': null,
        'p_as_provider': asProvider,
      },
    );
  }

  static Future<void> replyTicket(String ticketId, String body) async {
    if (!isSupabaseConfigured) {
      demoReply(body);
      return;
    }
    await db.rpc('api_reply_ticket', params: {'p_ticket_id': ticketId, 'p_body': body});
  }

  static Future<void> closeTicket(String ticketId) async {
    if (!isSupabaseConfigured) {
      demoCloseTicket(ticketId);
      return;
    }
    await db.rpc('api_close_ticket', params: {'p_ticket_id': ticketId});
  }

  // ----- الدفع -----
  //
  // **المبلغ لا يُرسَل من هنا.** `api_submit_payment` تحسبه من الحجز نفسه:
  // العربونُ ما بقي منه، والباقي ما بقي من الإجمالي. ولو قبِلت مبلغاً من
  // التطبيق لأمكن دفع عربون قاعةٍ بريالٍ واحد.

  /// أين يُحوَّل المال — من إعدادات المنصّة.
  static Future<PaymentSettings> paymentSettings() async {
    if (!isSupabaseConfigured) return demoDelay(demoPaymentSettings);
    // وقاعدةٌ لم يُطبَّق عليها `payments_app.sql` تنكر الأعمدة الأربعة، فتُقرأ
    // على أنها «لم تُضبط وسائلُ التحويل بعد» — وهو الصدق: لا رقم مُعلَناً.
    // أما رميُ الخطأ فيجعل شاشة الدفع حمراء، وهي لا تُصلَح من التطبيق أصلاً.
    final row = await whenColumnMissing<Map<String, dynamic>?>(
      () => db
          .from('app_settings')
          .select('pay_jawali, pay_kuraimi, pay_bank, pay_note')
          .eq('id', 1)
          .maybeSingle(),
      () async => null,
    );
    return PaymentSettings.fromMap(row ?? const {});
  }

  /// عملياتُ حجزٍ بعينه — أحدثُها أوّلاً.
  static Future<List<PaymentRow>> bookingPayments(String bookingId) async {
    if (!isSupabaseConfigured) return demoDelay(demoPaymentsOf(bookingId));
    final rows = await db
        .from('payments')
        .select()
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false);
    return rows.map(PaymentRow.fromMap).toList();
  }

  /// كلُّ عملياتي — لشاشةٍ واحدة تجمعها.
  static Future<List<PaymentRow>> myPayments() async {
    if (!isSupabaseConfigured) return demoDelay(demoPayments);
    final rows = await db.from('payments').select().order('created_at', ascending: false);
    return rows.map(PaymentRow.fromMap).toList();
  }

  /// إبلاغٌ بحوالة. يُنشئ عمليةً **معلّقة** تؤكّدها الإدارة.
  static Future<PaymentRow> submitPayment({
    required String bookingId,
    required String method,
    String kind = 'deposit',
    String senderRef = '',
  }) async {
    if (!isSupabaseConfigured) {
      return demoSubmitPayment(bookingId: bookingId, method: method, kind: kind);
    }
    final row = await db.rpc(
      'api_submit_payment',
      params: {
        'p_booking_id': bookingId,
        'p_method': method,
        'p_kind': kind,
        'p_sender_ref': senderRef,
      },
    );
    return PaymentRow.fromMap(Map<String, dynamic>.from(row as Map));
  }

  // ----- النزاعات -----
  //
  // ولا ملفَّ SQL جديد لها: الجدولان وسياساتُهما ودالّة `api_open_dispute`
  // في المخطّط منذ أوّل يوم — تقرأ الإدارة النزاعات من اللوحة، ولم يكن
  // للعميل بابٌ يفتح منه واحداً. وهذا الباب.

  /// نزاعاتي — والسياسة تحصرها في نزاعاتي وحدها، فلا شرط هنا.
  static Future<List<Dispute>> myDisputes() async {
    if (!isSupabaseConfigured) return demoDelay(List<Dispute>.from(demoDisputes));
    final rows = await db
        .from('disputes')
        .select()
        .order('created_at', ascending: false);
    return rows.map(Dispute.fromMap).toList();
  }

  /// **الفتحُ بدالّة لا بـ`insert`**: هي التي تقرّر أنك طرفٌ في هذا الحجز
  /// أصلاً، وتنسخ رقمه واسمَي طرفيه — ولو كتبها التطبيق لكتب ما شاء.
  static Future<void> openDispute({
    required String bookingId,
    required String subject,
    required String description,
    required String category,
  }) async {
    if (!isSupabaseConfigured) {
      demoOpenDispute(
        bookingId: bookingId,
        subject: subject,
        description: description,
        category: category,
      );
      return;
    }
    await db.rpc(
      'api_open_dispute',
      params: {
        'p_booking_id': bookingId,
        'p_subject': subject,
        'p_description': description,
        'p_category': category,
      },
    );
  }

  static Future<List<DisputeMessage>> disputeMessages(String disputeId) async {
    if (!isSupabaseConfigured) return demoDelay(demoDisputeMessagesOf(disputeId));
    final rows = await db
        .from('dispute_messages')
        .select('id, author, author_name, body, created_at')
        .eq('dispute_id', disputeId)
        .order('created_at', ascending: true);
    return rows.map(DisputeMessage.fromMap).toList();
  }

  /// ردٌّ في خيط النزاع.
  ///
  /// `insert` مباشر: سياسة `dispute_messages_write` تشترط أن يكون الكاتب طرفاً
  /// في النزاع **وأن يطابق `author` طرفَه** — فلا يكتب عميلٌ باسم المزوّد.
  static Future<void> replyDispute({
    required String disputeId,
    required String body,
    required bool asProvider,
    required String authorName,
  }) async {
    if (!isSupabaseConfigured) {
      demoReplyDispute(disputeId, body, asProvider ? 'provider' : 'customer', authorName);
      return;
    }
    await db.from('dispute_messages').insert({
      'dispute_id': disputeId,
      'author': asProvider ? 'provider' : 'customer',
      'author_name': authorName,
      'body': body,
    });
  }

  // ----- التقويم -----

  /// `yyyy-MM-dd` — القاعدة تحفظ يوماً لا لحظة، وإرسال طابع زمنٍ كامل يجعل
  /// يومَ المستخدم يتزحزح بفارق المنطقة الزمنية: عرسٌ يوم الخميس يُغلق يوم
  /// الأربعاء.
  static String _dayOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// تقويمي أنا — بملاحظاته.
  static Future<List<DayMark>> myDays(DateTime from, DateTime to) async {
    if (!isSupabaseConfigured) return demoDelay(demoMyDays(from, to));
    final rows = await db.rpc('api_my_days',
        params: {'p_from': _dayOf(from), 'p_to': _dayOf(to)}) as List<dynamic>;
    return rows.map((r) => DayMark.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  /// أغلق يوماً أو افتحه. تُعيد `null` حين يُفتح — إذ لم يبقَ صفّ.
  static Future<DayMark?> setAvailability(DateTime day, bool blocked,
      {String note = ''}) async {
    if (!isSupabaseConfigured) return demoSetAvailability(day, blocked, note);
    final row = await db.rpc('api_set_availability', params: {
      'p_day': _dayOf(day),
      'p_blocked': blocked,
      'p_note': note,
    });
    if (row == null) return null;
    return DayMark.fromMap(Map<String, dynamic>.from(row as Map));
  }

  /// أيامُ مزوّدٍ المشغولة — تواريخُ بلا ملاحظات، فما يخصّ حجوزات غيره ليس
  /// من شأن من يريد أن يحجز.
  static Future<Set<DateTime>> blockedDays(
      String providerId, DateTime from, DateTime to) async {
    if (!isSupabaseConfigured) {
      return demoDelay(demoBlockedDays(providerId, from, to));
    }
    final rows = await db.rpc('api_blocked_days', params: {
      'p_provider_id': providerId,
      'p_from': _dayOf(from),
      'p_to': _dayOf(to),
    }) as List<dynamic>;
    return rows.map((r) => DateTime.parse(r as String)).toSet();
  }

  // ----- الاشتراكات -----

  /// الباقات المتاحة. سياسةُ `plans_public_read` تُخفي الموقوفة، فلا شرط هنا.
  static Future<List<SubPlan>> plans() async {
    if (!isSupabaseConfigured) return demoDelay(demoSubPlans);
    final rows = await db
        .from('subscription_plans')
        .select('id, name, description, price, duration_days, perks')
        .order('price', ascending: true);
    return rows.map(SubPlan.fromMap).toList();
  }

  /// اشتراكي — أو `null` إن لم يكن لي اشتراكٌ قائمٌ ولا معلّق.
  static Future<MySub?> mySubscription() async {
    if (!isSupabaseConfigured) return demoDelay(demoMySub);
    final row = await db.rpc('api_my_subscription');
    if (row == null) return null;
    return MySub.fromMap(Map<String, dynamic>.from(row as Map));
  }

  /// يطلب باقة. المجّانية تُفعَّل فوراً، وما له سعرٌ ينتظر تأكيد الحوالة.
  static Future<MySub> subscribe({
    required String planId,
    required String method,
    String senderRef = '',
  }) async {
    if (!isSupabaseConfigured) return demoSubscribe(planId, method, senderRef);
    final row = await db.rpc('api_subscribe', params: {
      'p_plan_id': planId,
      'p_method': method,
      'p_sender_ref': senderRef,
    });
    return MySub.fromMap(Map<String, dynamic>.from(row as Map));
  }
}
