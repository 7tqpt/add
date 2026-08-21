import 'models.dart';

// بيانات تجريبية تعمل بلا خادم.
//
// الغرض نفسه الذي في اللوحة: يُتصفَّح التطبيق كاملاً قبل أن يُربط بمشروع
// Supabase — يراه صاحب المنصة على جواله في دقيقة، وتُراجَع الشاشات بلا انتظار
// شبكة. تُستبدل كلها بالبيانات الحقيقية بمجرد تمرير المفتاحين عند البناء.

String _day(int offset) =>
    DateTime.now().add(Duration(days: offset)).toIso8601String().substring(0, 10);
String _at(int hoursAgo) => DateTime.now().subtract(Duration(hours: hoursAgo)).toIso8601String();

/// تأخير بسيط ليظهر مؤشّر التحميل كما سيظهر مع شبكة حقيقية.
Future<T> demoDelay<T>(T value) => Future.delayed(const Duration(milliseconds: 300), () => value);

const demoGovernorates = [
  Governorate(id: 'g1', name: 'أمانة العاصمة'),
  Governorate(id: 'g2', name: 'عدن'),
  Governorate(id: 'g3', name: 'تعز'),
  Governorate(id: 'g4', name: 'الحديدة'),
  Governorate(id: 'g5', name: 'حضرموت'),
  Governorate(id: 'g6', name: 'إب'),
];

const demoCategories = [
  ServiceCategory(id: 'c1', name: 'القاعات والخيام', slug: 'halls'),
  ServiceCategory(id: 'c2', name: 'الطبخ والضيافة', slug: 'catering'),
  ServiceCategory(id: 'c3', name: 'التصوير والإضاءة', slug: 'photography'),
  ServiceCategory(id: 'c4', name: 'الديكور والكوشة', slug: 'decor'),
  ServiceCategory(id: 'c5', name: 'الصوت والمعدات', slug: 'sound'),
  // الاثنا عشر كما هي في `seed.sql`. وكانت خمسةً، فكان وضعُ العرض يُري
  // المنصّة أفقر ممّا هي — وهو الوضع الذي يُعرض به التطبيق على من لم يربط
  // قاعدةً بعد، وأوّلُ ما يحكم به على المنتج.
  ServiceCategory(id: 'c6', name: 'الفنانين والفرق', slug: 'artists'),
  ServiceCategory(id: 'c7', name: 'الموية والطليع والخدمات المساندة', slug: 'support'),
  ServiceCategory(id: 'c8', name: 'السيارات', slug: 'cars'),
  ServiceCategory(id: 'c9', name: 'الملبوسات', slug: 'attire'),
  ServiceCategory(id: 'c10', name: 'متعهدين الحفلات', slug: 'planners'),
  ServiceCategory(id: 'c11', name: 'التجميل والكوافير', slug: 'beauty'),
  ServiceCategory(id: 'c12', name: 'الطباعة', slug: 'printing'),
];

const demoServices = [
  ServiceItem(
    id: 's1',
    title: 'قاعة التاج — باقة شاملة',
    description: 'قاعة تتّسع لأربعمئة ضيف، مع التنسيق الكامل والإضاءة وطاقم الاستقبال.',
    price: 850000,
    priceTo: 1400000,
    unit: 'للحجز',
    depositPercent: 30,
    categoryId: 'c1',
    categoryName: 'القاعات والخيام',
    providerId: 'p1',
    providerName: 'قاعة التاج',
    providerGovernorate: 'أمانة العاصمة',
    providerRating: 4.9,
    providerReviewsCount: 87,
    providerIsFeatured: true,
    cancellationPolicyName: 'مرنة',
  ),
  ServiceItem(
    id: 's2',
    title: 'مندي وحنيذ لـ300 شخص',
    description: 'ذبائح وطبخ تقليدي مع طاقم تقديم كامل وقهوة وشاي.',
    price: 420000,
    priceTo: null,
    unit: 'للحجز',
    depositPercent: 30,
    categoryId: 'c2',
    categoryName: 'الطبخ والضيافة',
    providerId: 'p2',
    providerName: 'مطبخ الأصالة',
    providerGovernorate: 'أمانة العاصمة',
    providerRating: 4.7,
    providerReviewsCount: 52,
    providerIsFeatured: false,
    cancellationPolicyName: 'مرنة',
  ),
  ServiceItem(
    id: 's3',
    title: 'تصوير فيديو وفوتوغرافي',
    description: 'فريق من ثلاثة مصوّرين مع درون وإضاءة، وتسليم خلال أسبوعين.',
    price: 180000,
    priceTo: null,
    unit: 'لليوم',
    depositPercent: 30,
    categoryId: 'c3',
    categoryName: 'التصوير والإضاءة',
    providerId: 'p3',
    providerName: 'استوديو السعادة',
    providerGovernorate: 'عدن',
    providerRating: 4.4,
    providerReviewsCount: 24,
    providerIsFeatured: false,
    cancellationPolicyName: 'صارمة',
  ),
  ServiceItem(
    id: 's4',
    title: 'كوشة ورد طبيعي',
    description: 'تصميم وتنفيذ الكوشة بالورد الطبيعي، مع خلفية وإضاءة.',
    price: 260000,
    priceTo: null,
    unit: 'للحجز',
    depositPercent: 40,
    categoryId: 'c4',
    categoryName: 'الديكور والكوشة',
    providerId: 'p4',
    providerName: 'ديكور الياسمين',
    providerGovernorate: 'أمانة العاصمة',
    providerRating: 4.8,
    providerReviewsCount: 31,
    providerIsFeatured: false,
    cancellationPolicyName: 'مرنة',
  ),
  ServiceItem(
    id: 's5',
    title: 'صوتيات وإضاءة كاملة',
    description: 'سماعات ومكبّرات وميكروفونات وأجهزة دي جي مع فنّي طوال الحفل.',
    price: 95000,
    priceTo: null,
    unit: 'لليلة',
    depositPercent: 25,
    categoryId: 'c5',
    categoryName: 'الصوت والمعدات',
    providerId: 'p5',
    providerName: 'مركز النجم',
    providerGovernorate: 'تعز',
    providerRating: 4.2,
    providerReviewsCount: 18,
    providerIsFeatured: false,
    cancellationPolicyName: 'مرنة',
  ),
];

/// الحالة التجريبية متغيّرة: الحجز والقبول والاعتذار تُغيّرها فعلاً، فيرى
/// المستخدم أثر ما فعل بدل قائمة جامدة.
List<Booking> demoBookings = [
  Booking(
    id: 'b1',
    reference: 'BK-2026-000318',
    userName: 'أحمد الشرعبي',
    providerName: 'قاعة التاج',
    serviceTitle: 'قاعة التاج — باقة شاملة',
    eventDate: _day(28),
    eventTime: '20:00',
    address: 'حي السنينة — صنعاء',
    guestsCount: 400,
    status: BookingStatus.confirmed,
    totalPrice: 850000,
    depositAmount: 255000,
    paidAmount: 255000,
  ),
  Booking(
    id: 'b2',
    reference: 'BK-2026-000402',
    userName: 'أحمد الشرعبي',
    providerName: 'مطبخ الأصالة',
    serviceTitle: 'مندي وحنيذ لـ300 شخص',
    eventDate: _day(28),
    eventTime: '19:00',
    address: 'حي السنينة — صنعاء',
    guestsCount: 300,
    status: BookingStatus.pendingProvider,
    totalPrice: 420000,
    depositAmount: 126000,
    paidAmount: 0,
  ),
  Booking(
    id: 'b3',
    reference: 'BK-2026-000155',
    userName: 'أحمد الشرعبي',
    providerName: 'استوديو السعادة',
    serviceTitle: 'تصوير فيديو وفوتوغرافي',
    eventDate: _day(-40),
    eventTime: '18:30',
    address: 'قاعة الأندلس',
    guestsCount: 250,
    status: BookingStatus.completed,
    totalPrice: 180000,
    depositAmount: 54000,
    paidAmount: 180000,
  ),
];

List<WeddingPlan> demoPlans = [
  WeddingPlan(
    id: 'pl1',
    title: 'عرس أحمد ومريم',
    weddingDate: _day(28),
    governorate: 'أمانة العاصمة',
    guestsCount: 400,
    budget: 2000000,
    status: 'planning',
    servicesCount: 2,
    totalCost: 1270000,
    paidAmount: 255000,
    remainingAmount: 1015000,
  ),
];

List<SupportTicket> demoTickets = [
  SupportTicket(
    id: 't1',
    reference: 'SUP-2026-000118',
    subject: 'خُصم المبلغ ولم يظهر الحجز',
    status: 'waiting_customer',
    lastMessageAt: _at(4),
  ),
];

List<SupportMessage> demoTicketMessages = [
  SupportMessage(
    id: 'tm1',
    author: 'customer',
    authorName: 'أحمد الشرعبي',
    body: 'حوّلت العربون من محفظتي وخُصم المبلغ، لكن الحجز ما زال يظهر «بانتظار الدفع».',
    createdAt: _at(30),
  ),
  SupportMessage(
    id: 'tm2',
    author: 'admin',
    authorName: 'فريق خدمة العملاء',
    body: 'راجعنا سجل البوابة ووجدنا العملية معلّقة لديهم. سيُعاد المبلغ خلال 48 ساعة أو يُثبَّت الحجز.',
    createdAt: _at(4),
  ),
];

/// في الوضع التجريبي يبدأ الجميع عملاء بلا ملف مزوّد — تماماً كالواقع.
String? demoProviderId;

ProviderProfile? demoProviderProfile;

/// الطلبات الواردة إلى مقدّم الخدمة.
///
/// تبدأ فارغة عمداً: الملفّ الجديد «قيد المراجعة» ولا يصله شيء حتى تقبله
/// الإدارة — وعرضُ طلباتٍ عليه قبل ذلك يناقض ما تقوله شاشته نفسها.
List<Booking> demoProviderRequests = [];

void demoBecomeProvider({
  required String businessName,
  required String governorate,
  required String bio,
}) {
  demoProviderId = 'demo-provider';
  demoProviderProfile = ProviderProfile(
    id: 'demo-provider',
    // ما كتبه المستخدم لا اسمٌ ثابت: نموذجٌ يُرسَل ثم يُعرض بغير ما أُدخل يجعل
    // المجرِّب يظنّ أن الإرسال لم ينجح.
    businessName: businessName,
    fullName: 'أحمد الشرعبي',
    governorate: governorate,
    bio: bio,
    status: 'pending',
    rating: 0,
    reviewsCount: 0,
    completedBookings: 0,
    totalEarnings: 0,
    rejectionReason: '',
  );
  demoProviderRequests = [];
}

/// محاكاة قبول الإدارة — في الوضع التجريبي وحده.
///
/// لا مسؤول في الوضع التجريبي يضغط «توثيق» في اللوحة، فبلا هذا يقف المجرِّب عند
/// «قيد المراجعة» ولا يرى شاشة الطلبات أبداً. الزرّ موسومٌ «تجريبي» في الواجهة
/// كي لا يُفهم أنّ التوثيق يقع تلقائياً في الإنتاج.
void demoApproveProvider() {
  final p = demoProviderProfile;
  if (p == null) return;
  demoProviderProfile = ProviderProfile(
    id: p.id,
    businessName: p.businessName,
    fullName: p.fullName,
    governorate: p.governorate,
    bio: p.bio,
    status: 'verified',
    rating: 0,
    reviewsCount: 0,
    completedBookings: 0,
    totalEarnings: 0,
    rejectionReason: '',
  );
  demoProviderRequests = [
    Booking(
      id: 'r1',
      reference: 'BK-2026-000511',
      userName: 'سالم باحميد',
      providerName: p.businessName,
      serviceTitle: 'حجز ${p.businessName}',
      eventDate: _day(34),
      eventTime: '20:00',
      address: 'شارع الستين — صنعاء',
      guestsCount: 350,
      status: BookingStatus.pendingProvider,
      totalPrice: 700000,
      depositAmount: 210000,
      paidAmount: 0,
    ),
    Booking(
      id: 'r2',
      reference: 'BK-2026-000524',
      userName: 'هدى المقطري',
      providerName: p.businessName,
      serviceTitle: 'حجز ${p.businessName}',
      eventDate: _day(52),
      eventTime: '19:30',
      address: 'حدة — صنعاء',
      guestsCount: 220,
      status: BookingStatus.pendingProvider,
      totalPrice: 480000,
      depositAmount: 144000,
      paidAmount: 0,
    ),
  ];
}

int _seq = 500;

Booking demoCreateBooking(String serviceId, String date, String? time, int guests, String address) {
  final service = demoServices.firstWhere((s) => s.id == serviceId);
  _seq += 1;
  final booking = Booking(
    id: 'b$_seq',
    reference: 'BK-2026-${_seq.toString().padLeft(6, '0')}',
    userName: 'أحمد الشرعبي',
    providerName: service.providerName,
    serviceTitle: service.title,
    eventDate: date,
    eventTime: time,
    address: address,
    guestsCount: guests,
    status: BookingStatus.pendingProvider,
    totalPrice: service.price,
    depositAmount: (service.price * service.depositPercent / 100).round(),
    paidAmount: 0,
  );
  demoBookings = [booking, ...demoBookings];
  return booking;
}

void _replace(String id, BookingStatus status) {
  // القائمتان تُمسحان معاً: الحجز الواحد يعيش في إحداهما، ومن يقبل طلباً وارداً
  // إنما يعدّل صفّاً في قائمة المزوّد لا في قائمة العميل.
  demoBookings = _withStatus(demoBookings, id, status);
  demoProviderRequests = _withStatus(demoProviderRequests, id, status);
}

List<Booking> _withStatus(List<Booking> list, String id, BookingStatus status) {
  return list.map((b) {
    if (b.id != id) return b;
    return Booking(
      id: b.id,
      reference: b.reference,
      userName: b.userName,
      providerName: b.providerName,
      serviceTitle: b.serviceTitle,
      eventDate: b.eventDate,
      eventTime: b.eventTime,
      address: b.address,
      guestsCount: b.guestsCount,
      status: status,
      totalPrice: b.totalPrice,
      depositAmount: b.depositAmount,
      paidAmount: status == BookingStatus.confirmed ? b.depositAmount : b.paidAmount,
    );
  }).toList();
}

void demoRespond(String id, bool accept) =>
    _replace(id, accept ? BookingStatus.confirmed : BookingStatus.rejected);

void demoComplete(String id) => _replace(id, BookingStatus.completed);

void demoOpenTicket(String subject) {
  demoTickets = [
    SupportTicket(
      id: 't${demoTickets.length + 1}',
      reference: 'SUP-2026-${(119 + demoTickets.length).toString().padLeft(6, '0')}',
      subject: subject,
      status: 'open',
      lastMessageAt: DateTime.now().toIso8601String(),
    ),
    ...demoTickets,
  ];
}

void demoReply(String body) {
  demoTicketMessages = [
    ...demoTicketMessages,
    SupportMessage(
      id: 'tm${demoTicketMessages.length + 1}',
      author: 'customer',
      authorName: 'أحمد الشرعبي',
      body: body,
      createdAt: DateTime.now().toIso8601String(),
    ),
  ];
}

// ---------------------------------------------------------------------------
// ما أُضيف مع إكمال التطبيق: الخدمات والمستندات والخطة والتقييم والمفضّلة.
// ---------------------------------------------------------------------------

/// خدمات المزوّد التجريبي. تبدأ فارغة كملفه: من أنشأ حسابه للتوّ لا خدمة له.
List<MyService> demoMyServices = [];

int _serviceSeq = 0;

void demoSaveService({String? id, required Map<String, dynamic> values}) {
  final next = MyService(
    id: id ?? 'ms${++_serviceSeq}',
    title: values['title'] as String,
    description: values['description'] as String,
    price: values['price'] as num,
    priceTo: values['price_to'] as num?,
    unit: values['unit'] as String,
    depositPercent: values['deposit_percent'] as int,
    categoryId: values['category_id'] as String,
    isActive: id == null ? true : demoMyServices.firstWhere((s) => s.id == id).isActive,
  );
  demoMyServices = id == null
      ? [next, ...demoMyServices]
      : demoMyServices.map((s) => s.id == id ? next : s).toList();
}

void demoSetServiceActive(String id, bool active) {
  demoMyServices = demoMyServices.map((s) {
    if (s.id != id) return s;
    return MyService(
      id: s.id,
      title: s.title,
      description: s.description,
      price: s.price,
      priceTo: s.priceTo,
      unit: s.unit,
      depositPercent: s.depositPercent,
      categoryId: s.categoryId,
      isActive: active,
    );
  }).toList();
}

List<ProviderDocument> demoDocuments = [];

int _docSeq = 0;

void demoAddDocument(String type, String fileName) {
  demoDocuments = [
    ProviderDocument(
      id: 'doc${++_docSeq}',
      type: type,
      fileName: fileName,
      fileUrl: 'demo/$fileName',
      status: 'pending',
      note: '',
      uploadedAt: DateTime.now().toIso8601String(),
    ),
    ...demoDocuments,
  ];
}

int _planSeq = 0;

void demoSavePlan({String? id, required Map<String, dynamic> values}) {
  final budget = values['budget'] as num;
  final existing = id == null ? null : demoPlans.firstWhere((p) => p.id == id);
  final next = WeddingPlan(
    id: id ?? 'pl${++_planSeq + 1}',
    title: values['title'] as String,
    weddingDate: values['wedding_date'] as String,
    governorate: values['governorate'] as String,
    guestsCount: values['guests_count'] as int,
    budget: budget,
    status: existing?.status ?? 'planning',
    servicesCount: existing?.servicesCount ?? 0,
    totalCost: existing?.totalCost ?? 0,
    paidAmount: existing?.paidAmount ?? 0,
    remainingAmount: budget - (existing?.paidAmount ?? 0),
  );
  demoPlans = id == null
      ? [next, ...demoPlans]
      : demoPlans.map((p) => p.id == id ? next : p).toList();
}

void demoCancel(String id) => _replace(id, BookingStatus.cancelled);

/// الحجوزات المقيَّمة. القاعدة تمنع تقييم الحجز مرّتين بقيد فريد، والوضع
/// التجريبي يحاكي المنع نفسه كي يختفي الزرّ بعد الضغط كما سيختفي فعلاً.
Set<String> demoReviewedBookings = {};

void demoReview(String bookingId, int rating) => demoReviewedBookings.add(bookingId);

Set<String> demoFavourites = {};

void demoToggleFavourite(String serviceId) {
  if (!demoFavourites.remove(serviceId)) demoFavourites.add(serviceId);
}

void demoCloseTicket(String ticketId) {
  demoTickets = demoTickets.map((t) {
    if (t.id != ticketId) return t;
    return SupportTicket(
      id: t.id,
      reference: t.reference,
      subject: t.subject,
      status: 'closed',
      lastMessageAt: DateTime.now().toIso8601String(),
    );
  }).toList();
}

// ── الملف الشخصي في وضع العرض ───────────────────────────────────────────────
MyProfile _demoProfile = const MyProfile(
  id: 'demo-user',
  fullName: 'مستخدم تجريبي',
  email: 'demo@example.com',
  phone: '770000000',
  governorate: 'أمانة العاصمة',
  governorateId: null,
  avatarPath: '',
);

MyProfile? demoProfile() => _demoProfile;

MyProfile demoUpdateProfile(String name, String? phone, String? govId, String? avatar) {
  _demoProfile = _demoProfile.copyWith(
    fullName: name,
    phone: phone,
    avatarPath: avatar,
  );
  return _demoProfile;
}
