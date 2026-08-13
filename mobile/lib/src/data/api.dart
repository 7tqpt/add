import 'models.dart';
import 'supabase.dart';
import 'demo.dart';

/// كل ما يقرؤه التطبيق أو يكتبه.
///
/// الكتابة كلها تمرّ بدوال `api_*` لا بالجداول: الخادم هو من يحسب السعر والعربون
/// والعمولة وسلّم الإلغاء. لو قبِل سعراً من التطبيق لأمكن حجز قاعة بريال واحد.
class Api {
  // ----- المرجعيات والاستكشاف -----

  static Future<List<Governorate>> governorates() async {
    if (!isSupabaseConfigured) return demoDelay(demoGovernorates);
    final rows = await db
        .from('governorates')
        .select('id, name')
        .eq('is_active', true)
        .order('sort_order');
    return rows.map(Governorate.fromMap).toList();
  }

  static Future<List<ServiceCategory>> categories() async {
    if (!isSupabaseConfigured) return demoDelay(demoCategories);
    final rows = await db
        .from('service_categories')
        .select('id, name, slug')
        .eq('is_active', true)
        .order('sort_order');
    return rows.map(ServiceCategory.fromMap).toList();
  }

  static Future<List<ServiceItem>> services({String? search, String? categoryId}) async {
    if (!isSupabaseConfigured) {
      final term = (search ?? '').trim().toLowerCase();
      return demoDelay(
        demoServices.where((s) {
          if (categoryId != null && s.categoryId != categoryId) return false;
          if (term.isEmpty) return true;
          return s.title.toLowerCase().contains(term) ||
              s.providerName.toLowerCase().contains(term);
        }).toList(),
      );
    }

    var query = db.from('v_services').select();
    if (categoryId != null) query = query.eq('category_id', categoryId);
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
    final row = await db
        .from('service_providers')
        .select(
          'id, full_name, business_name, governorate, bio, status, rating, reviews_count, completed_bookings, total_earnings, rejection_reason',
        )
        .eq('id', providerId)
        .maybeSingle();
    return row == null ? null : ProviderProfile.fromMap(row);
  }

  // ----- الحجوزات -----

  /// حجوزات المستخدم بوصفه **عميلاً**.
  ///
  /// الشرط ضروري ولا تكفي RLS: سياسة الحجوزات تُرجع للمستخدم ما حجزه *وما
  /// وصله بوصفه مقدّم خدمة* — «الحجز يراه طرفاه». ومن يجمع الصفتين — وهو ما
  /// يقصده التطبيق أصلاً — كان يرى مبيعاته مختلطةً بمشترياته في الشاشتين معاً.
  static Future<List<Booking>> myBookings(String appUserId) async {
    if (!isSupabaseConfigured) return demoDelay(demoBookings);
    final rows = await db.from('bookings').select().eq('user_id', appUserId).order('event_date');
    return rows.map(Booking.fromMap).toList();
  }

  /// الطلبات الواردة إلى المستخدم بوصفه **مقدّم خدمة** — الوجه الآخر للسياسة.
  static Future<List<Booking>> providerRequests(String providerId) async {
    if (!isSupabaseConfigured) return demoDelay(demoProviderRequests);
    final rows = await db
        .from('bookings')
        .select()
        .eq('provider_id', providerId)
        .order('event_date');
    return rows.map(Booking.fromMap).toList();
  }

  static Future<Booking> createBooking({
    required String serviceId,
    required String eventDate,
    String? eventTime,
    required int guests,
    required String address,
    String notes = '',
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
        'p_plan_id': null,
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

  // ----- خطة العرس -----

  static Future<List<WeddingPlan>> myPlans() async {
    if (!isSupabaseConfigured) return demoDelay(demoPlans);
    final rows = await db.from('v_plan_summary').select().order('wedding_date');
    return rows.map(WeddingPlan.fromMap).toList();
  }

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
        .order('created_at');
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
}
