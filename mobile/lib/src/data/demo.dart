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
    coverPath: 'p1/s1/hall.jpg',
    imagesCount: 1,
    hasVideo: true,
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
    hasAudio: true,
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
  // خدمتان أُخريان لـ«قاعة التاج»: مزوّدٌ بخدمةٍ واحدة لا يُري ملفَّه شيئاً،
  // وصاحبُ القاعة في الواقع يعرض باقاتٍ لا باقة.
  ServiceItem(
    id: 's6',
    title: 'قاعة التاج — باقة الخطوبة',
    description: 'القاعة الصغرى لمئة وخمسين ضيفاً، مع الضيافة والتنسيق.',
    price: 450000,
    priceTo: null,
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
    id: 's7',
    title: 'خيمة أفراح متنقّلة',
    description: 'خيمة مكيّفة تُنصب في موقعك، بفرشها وإضاءتها وطاقم النصب.',
    price: 320000,
    priceTo: 520000,
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
    cancellationPolicyName: 'متوسّطة',
  ),
];

/// مقدّمو الخدمة كما يراهم العميل.
///
/// ولا واحدَ منهم غيرُ موثَّق: القاعدة لا تُظهر غيرَ الموثَّقين أصلاً، فوضعُ
/// العرض يُري ما تُريه القاعدة لا ما يزيد عليه.
const demoProviders = [
  PublicProvider(
    id: 'p1',
    businessName: 'قاعة التاج',
    bio: 'قاعتان في حي السنينة تتّسعان لأربعمئة ضيف، مع تنسيقٍ كامل وإضاءةٍ '
        'وطاقم استقبال. نعمل منذ ٢٠١٤ ونستقبل الخطوبات والأعراس.',
    governorate: 'أمانة العاصمة',
    coverageAreas: ['أمانة العاصمة', 'صنعاء'],
    rating: 4.9,
    reviewsCount: 87,
    completedBookings: 142,
    isFeatured: true,
    isVerified: true,
    categories: ['القاعات والخيام'],
  ),
  PublicProvider(
    id: 'p2',
    businessName: 'مطبخ الأصالة',
    bio: 'مندي وحنيذ وزربيان بطبخٍ تقليديّ على الحطب، مع طاقم تقديمٍ كامل.',
    governorate: 'أمانة العاصمة',
    coverageAreas: ['أمانة العاصمة', 'ذمار'],
    rating: 4.7,
    reviewsCount: 52,
    completedBookings: 96,
    isFeatured: false,
    isVerified: true,
    categories: ['الطبخ والضيافة'],
  ),
  PublicProvider(
    id: 'p3',
    businessName: 'استوديو السعادة',
    bio: 'تصويرٌ فوتوغرافيّ وفيديو بفريقٍ من ثلاثة مصوّرين ودرون، والتسليم '
        'خلال أسبوعين.',
    governorate: 'عدن',
    coverageAreas: ['عدن', 'لحج', 'أبين'],
    rating: 4.4,
    reviewsCount: 24,
    completedBookings: 38,
    isFeatured: false,
    isVerified: true,
    categories: ['التصوير والإضاءة'],
  ),
  PublicProvider(
    id: 'p4',
    businessName: 'ديكور الياسمين',
    bio: 'كوشات الورد الطبيعيّ وتنسيق المداخل والطاولات.',
    governorate: 'أمانة العاصمة',
    coverageAreas: ['أمانة العاصمة'],
    rating: 4.8,
    reviewsCount: 31,
    completedBookings: 44,
    isFeatured: false,
    isVerified: true,
    categories: ['الديكور والكوشة'],
  ),
  PublicProvider(
    id: 'p5',
    businessName: 'مركز النجم',
    bio: 'صوتيات وإضاءة وأجهزة دي جي مع فنّيٍّ طوال الحفل.',
    governorate: 'تعز',
    coverageAreas: ['تعز', 'إب'],
    rating: 4.2,
    reviewsCount: 18,
    completedBookings: 27,
    isFeatured: false,
    isVerified: true,
    categories: ['الصوت والمعدات'],
  ),
];

/// آراءُ العملاء في وضع العرض.
///
/// وفيها رأيٌ بثلاث نجوم: صفحةُ كلُّها خمسٌ لا تُصدَّق، ومن رأى نقداً معقولاً
/// وثِق بالبقيّة.
final Map<String, List<Review>> _demoReviews = {
  'p1': [
    Review(
      id: 'r1',
      userName: 'أحمد الشرعبي',
      rating: 5,
      comment: 'قاعة نظيفة والاستقبال ممتاز، والتزموا بالوقت تماماً.',
      createdAt: _at(24 * 9),
    ),
    Review(
      id: 'r2',
      userName: 'سُمية القدسي',
      rating: 5,
      comment: 'التنسيق فاق ما اتّفقنا عليه، والإضاءة كانت جميلة في الصور.',
      createdAt: _at(24 * 26),
    ),
    Review(
      id: 'r3',
      userName: 'خالد الحداد',
      rating: 3,
      comment: 'القاعة جيدة لكن المواقف ضيّقة ليلة العرس.',
      createdAt: _at(24 * 51),
    ),
  ],
  'p2': [
    Review(
      id: 'r4',
      userName: 'نبيل العزّاني',
      rating: 5,
      comment: 'المندي كان ممتازاً والكمّية كافية لأكثر من العدد المتّفق عليه.',
      createdAt: _at(24 * 14),
    ),
    Review(
      id: 'r5',
      userName: 'أروى المِقطري',
      rating: 4,
      comment: 'الطعم ممتاز، وتأخّر التقديم نحو نصف ساعة.',
      createdAt: _at(24 * 33),
    ),
  ],
  'p3': [
    Review(
      id: 'r6',
      userName: 'وليد باشا',
      rating: 4,
      comment: 'الصور جميلة وسلّموا في الموعد.',
      createdAt: _at(24 * 20),
    ),
  ],
};

List<Review> demoReviewsOf(String providerId) => _demoReviews[providerId] ?? const [];

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

/// إعادة رسائل التذكرة إلى حالها — للاختبارات، فما يُرسَل يُضاف إلى القائمة.
void demoResetTicketMessages() {
  demoTicketMessages = [
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
}

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

// ── وسائط الخدمة في وضع العرض ───────────────────────────────────────────────
//
// بلا Supabase لا سلّة ولا روابط، فتُخزَّن الصفوف في الذاكرة وحدها: الشاشة
// تُبنى وتُختبر بلا شبكة، وما يُرفع يظهر في القائمة كما يظهر على القاعدة.
// والملفّ نفسه لا يُحفظ — لا شيء هنا يعرضه.
int _mediaSeq = 0;
Map<String, List<ServiceMedia>> demoMedia = {
  's1': const [
    ServiceMedia(
      id: 'm1',
      kind: MediaKind.image,
      path: 'p1/s1/hall.jpg',
      title: 'القاعة ليلة عرس',
      durationSeconds: 0,
      sizeBytes: 320000,
      sortOrder: 0,
    ),
    ServiceMedia(
      id: 'm2',
      kind: MediaKind.video,
      path: 'p1/s1/tour.mp4',
      title: 'جولة في القاعة',
      durationSeconds: 48,
      sizeBytes: 18000000,
      sortOrder: 0,
    ),
  ],
  's3': const [
    ServiceMedia(
      id: 'm3',
      kind: MediaKind.audio,
      path: 'p3/s3/sample.m4a',
      title: 'مقطع من حفل',
      durationSeconds: 55,
      sizeBytes: 900000,
      sortOrder: 0,
    ),
  ],
};

List<ServiceMedia> demoMediaOf(String serviceId) =>
    List<ServiceMedia>.from(demoMedia[serviceId] ?? const []);

void demoAddMedia(
  String serviceId,
  MediaKind kind,
  String path,
  int seconds,
  int bytes,
  int order,
) {
  _mediaSeq += 1;
  demoMedia = {
    ...demoMedia,
    serviceId: [
      ...(demoMedia[serviceId] ?? const []),
      ServiceMedia(
        id: 'md$_mediaSeq',
        kind: kind,
        path: path,
        title: '',
        durationSeconds: seconds,
        sizeBytes: bytes,
        sortOrder: order,
      ),
    ],
  };
}

void demoRemoveMedia(String id) {
  demoMedia = {
    for (final entry in demoMedia.entries)
      entry.key: entry.value.where((m) => m.id != id).toList(),
  };
}

// ── المحادثة في وضع العرض ────────────────────────────────────────────────────
//
// بلا Supabase لا بثَّ حيّاً ولا `now()` من الخادم، فتُحفظ الخيوط في الذاكرة.
// وهذا يكفي لبناء الشاشتين واختبارهما بلا شبكة: ما يُرسَل يظهر في مكانه،
// والعدّاد يصفر عند القراءة كما يصفر على القاعدة.
int _chatSeq = 0;

class _DemoThread {
  _DemoThread({
    required this.id,
    required this.providerId,
    required this.otherName,
    required this.mySide,
    required this.messages,
    this.readAt,
  });
  final String id;
  final String providerId;
  final String otherName;
  final ChatSide mySide;
  List<ChatMessage> messages;
  String? readAt;
}

List<_DemoThread> _threads = [
  _DemoThread(
    id: 'cv1',
    providerId: 'p1',
    otherName: 'قاعة التاج',
    mySide: ChatSide.customer,
    messages: [
      ChatMessage(
        id: 'cm1',
        sender: ChatSide.customer,
        body: 'السلام عليكم، القاعة متاحة يوم ١٥ سبتمبر؟',
        createdAt: _at(30),
      ),
      ChatMessage(
        id: 'cm2',
        sender: ChatSide.provider,
        body: 'وعليكم السلام. نعم متاحة، والعربون ٣٠٪ لتثبيت الموعد.',
        createdAt: _at(26),
      ),
      ChatMessage(
        id: 'cm3',
        sender: ChatSide.provider,
        body: 'وتشمل التنسيق والإضاءة وطاقم الاستقبال.',
        createdAt: _at(25),
      ),
    ],
  ),
  _DemoThread(
    id: 'cv2',
    providerId: 'p2',
    otherName: 'مطبخ الأصالة',
    mySide: ChatSide.customer,
    messages: [
      ChatMessage(
        id: 'cm4',
        sender: ChatSide.customer,
        body: 'كم سعر مندي لـ٣٠٠ شخص؟',
        createdAt: _at(90),
      ),
    ],
    readAt: _at(89),
  ),
];

/// إعادة الحال إلى أوّلها — للاختبارات، فكلٌّ يبدأ من حيث بدأ سابقُه.
void demoResetChat() {
  _chatSeq = 0;
  _threads = [
    _DemoThread(
      id: 'cv1',
      providerId: 'p1',
      otherName: 'قاعة التاج',
      mySide: ChatSide.customer,
      messages: [
        ChatMessage(
          id: 'cm1',
          sender: ChatSide.customer,
          body: 'السلام عليكم، القاعة متاحة يوم ١٥ سبتمبر؟',
          createdAt: _at(30),
        ),
        ChatMessage(
          id: 'cm2',
          sender: ChatSide.provider,
          body: 'وعليكم السلام. نعم متاحة، والعربون ٣٠٪ لتثبيت الموعد.',
          createdAt: _at(26),
        ),
        ChatMessage(
          id: 'cm3',
          sender: ChatSide.provider,
          body: 'وتشمل التنسيق والإضاءة وطاقم الاستقبال.',
          createdAt: _at(25),
        ),
      ],
    ),
    _DemoThread(
      id: 'cv2',
      providerId: 'p2',
      otherName: 'مطبخ الأصالة',
      mySide: ChatSide.customer,
      messages: [
        ChatMessage(
          id: 'cm4',
          sender: ChatSide.customer,
          body: 'كم سعر مندي لـ٣٠٠ شخص؟',
          createdAt: _at(90),
        ),
      ],
      readAt: _at(89),
    ),
  ];
}

List<Conversation> demoConversationList() {
  final rows = _threads.map((t) {
    final last = t.messages.isEmpty ? null : t.messages.last;
    final mine = chatSideValue(t.mySide);
    final unread = t.messages
        .where((m) =>
            chatSideValue(m.sender) != mine &&
            (t.readAt == null || m.createdAt.compareTo(t.readAt!) > 0))
        .length;
    return Conversation(
      id: t.id,
      providerId: t.providerId,
      otherName: t.otherName,
      mySide: t.mySide,
      lastMessageAt: last?.createdAt ?? '',
      lastMessageBody: last == null
          ? ''
          : (last.body.length > 160 ? last.body.substring(0, 160) : last.body),
      lastMessageSender: last?.sender,
      unreadCount: unread,
    );
  }).toList();
  rows.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  return rows;
}

List<ChatMessage> demoMessagesOf(String conversationId) =>
    List<ChatMessage>.from(
      _threads.where((t) => t.id == conversationId).firstOrNull?.messages ?? const [],
    );

String demoOpenConversation(String providerId) {
  final existing = _threads.where((t) => t.providerId == providerId).firstOrNull;
  if (existing != null) return existing.id;
  _chatSeq += 1;
  final name = demoServices
          .where((s) => s.providerId == providerId)
          .firstOrNull
          ?.providerName ??
      'مقدّم الخدمة';
  final thread = _DemoThread(
    id: 'cv-new$_chatSeq',
    providerId: providerId,
    otherName: name,
    mySide: ChatSide.customer,
    messages: [],
  );
  _threads = [..._threads, thread];
  return thread.id;
}

void demoSendMessage(String conversationId, ChatSide sender, String body) {
  final thread = _threads.where((t) => t.id == conversationId).firstOrNull;
  if (thread == null) return;
  _chatSeq += 1;
  final now = DateTime.now().toIso8601String();
  thread.messages = [
    ...thread.messages,
    ChatMessage(id: 'cm-new$_chatSeq', sender: sender, body: body, createdAt: now),
  ];
  // المرسِل قارئٌ لكلامه: لولا ذلك لظهرت له محادثتُه «غير مقروءة» بسببه هو.
  if (chatSideValue(sender) == chatSideValue(thread.mySide)) thread.readAt = now;
}

void demoMarkRead(String conversationId) {
  final thread = _threads.where((t) => t.id == conversationId).firstOrNull;
  if (thread != null) thread.readAt = DateTime.now().toIso8601String();
}

/// فتحُ المحادثة من طرف مقدّم الخدمة، على حجزٍ له.
///
/// وجانبُها هنا `provider`: قائمةُ المحادثات تعرض «الطرف الآخر»، والآخرُ عند
/// صاحب القاعة هو العميل — عكسُ ما يراه العميل في الخيط نفسه.
String demoOpenConversationWithCustomer(String bookingId) {
  final booking = [...demoProviderRequests, ...demoBookings]
      .where((b) => b.id == bookingId)
      .firstOrNull;
  final name = booking?.userName ?? 'العميل';
  final existing = _threads.where((t) => t.otherName == name).firstOrNull;
  if (existing != null) return existing.id;
  _chatSeq += 1;
  final thread = _DemoThread(
    id: 'cv-p$_chatSeq',
    providerId: demoProviderId ?? 'p1',
    otherName: name,
    mySide: ChatSide.provider,
    messages: [],
  );
  _threads = [..._threads, thread];
  return thread.id;
}

/// يحذف خيطاً — للاختبارات وحدها، لبلوغ حال «لا محادثات بعد».
void demoDropThread(String id) => _threads = _threads.where((t) => t.id != id).toList();

// ── صندوق الإشعارات في وضع العرض ────────────────────────────────────────────
int _noteSeq = 0;

List<AppNotification> demoNotifications = [
  AppNotification(
    id: 'n1',
    kind: NotificationKind.message,
    title: 'قاعة التاج',
    body: 'وتشمل التنسيق والإضاءة وطاقم الاستقبال.',
    data: const {'conversation_id': 'cv1'},
    readAt: null,
    createdAt: _at(25),
  ),
  AppNotification(
    id: 'n2',
    kind: NotificationKind.booking,
    title: 'تم تأكيد حجزك',
    body: 'قبل مقدّم الخدمة حجزك BK-2026-000318.',
    data: const {'booking_id': 'b1'},
    readAt: null,
    createdAt: _at(40),
  ),
  AppNotification(
    id: 'n3',
    kind: NotificationKind.payment,
    title: 'تم استلام الدفعة',
    body: 'تم تأكيد دفعتك بنجاح.',
    data: const {'booking_id': 'b1'},
    readAt: _at(60),
    createdAt: _at(64),
  ),
];

void demoResetNotifications() {
  _noteSeq = 0;
  demoNotifications = [
    AppNotification(
      id: 'n1',
      kind: NotificationKind.message,
      title: 'قاعة التاج',
      body: 'وتشمل التنسيق والإضاءة وطاقم الاستقبال.',
      data: const {'conversation_id': 'cv1'},
      readAt: null,
      createdAt: _at(25),
    ),
    AppNotification(
      id: 'n2',
      kind: NotificationKind.booking,
      title: 'تم تأكيد حجزك',
      body: 'قبل مقدّم الخدمة حجزك BK-2026-000318.',
      data: const {'booking_id': 'b1'},
      readAt: null,
      createdAt: _at(40),
    ),
    AppNotification(
      id: 'n3',
      kind: NotificationKind.payment,
      title: 'تم استلام الدفعة',
      body: 'تم تأكيد دفعتك بنجاح.',
      data: const {'booking_id': 'b1'},
      readAt: _at(60),
      createdAt: _at(64),
    ),
  ];
}

List<AppNotification> demoNotificationList() =>
    List<AppNotification>.from(demoNotifications);

AppNotification _readCopy(AppNotification n) => AppNotification(
  id: n.id,
  kind: n.kind,
  title: n.title,
  body: n.body,
  data: n.data,
  readAt: DateTime.now().toIso8601String(),
  createdAt: n.createdAt,
);

void demoMarkNotificationRead(String id) {
  demoNotifications =
      demoNotifications.map((n) => n.id == id && n.isUnread ? _readCopy(n) : n).toList();
}

void demoMarkAllNotificationsRead() {
  demoNotifications = demoNotifications.map((n) => n.isUnread ? _readCopy(n) : n).toList();
}

/// إشعارٌ يصل والتطبيق مفتوح — لمحاكاة البثّ في الاختبارات.
void demoPushNotification(NotificationKind kind, String title, String body) {
  _noteSeq += 1;
  demoNotifications = [
    AppNotification(
      id: 'n-new$_noteSeq',
      kind: kind,
      title: title,
      body: body,
      data: const {},
      readAt: null,
      createdAt: DateTime.now().toIso8601String(),
    ),
    ...demoNotifications,
  ];
}
