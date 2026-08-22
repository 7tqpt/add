import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';

String bookingStatusLabel(BookingStatus s) => switch (s) {
  BookingStatus.pendingProvider => 'بانتظار مقدّم الخدمة',
  BookingStatus.confirmed => 'مؤكد',
  BookingStatus.completed => 'منفّذ',
  BookingStatus.rejected => 'مرفوض',
  BookingStatus.cancelled => 'ملغي',
  BookingStatus.expired => 'منتهٍ',
};

Color bookingStatusColor(BookingStatus s) => switch (s) {
  BookingStatus.pendingProvider => AppColors.warning,
  BookingStatus.confirmed => AppColors.good,
  BookingStatus.completed => AppColors.good,
  BookingStatus.rejected => AppColors.critical,
  BookingStatus.cancelled => AppColors.muted,
  BookingStatus.expired => AppColors.muted,
};

String ticketStatusLabel(String s) => switch (s) {
  'open' => 'مفتوحة',
  'in_progress' => 'قيد المعالجة',
  'waiting_customer' => 'بانتظار ردّك',
  'resolved' => 'تم الحل',
  _ => 'مغلقة',
};

const ticketCategories = <({String value, String label})>[
  (value: 'booking', label: 'الحجوزات'),
  (value: 'payment', label: 'الدفع'),
  (value: 'account', label: 'الحساب'),
  (value: 'technical', label: 'عطل فني'),
  (value: 'suggestion', label: 'اقتراح'),
  (value: 'other', label: 'أخرى'),
];

String planStatusLabel(String s) => switch (s) {
  'confirmed' => 'مكتملة الحجز',
  'completed' => 'انتهى العرس',
  'cancelled' => 'ملغاة',
  _ => 'قيد التجهيز',
};

Color planStatusColor(String s) => switch (s) {
  'confirmed' => AppColors.good,
  'completed' => AppColors.muted,
  'cancelled' => AppColors.critical,
  _ => AppColors.warning,
};

String providerStatusLabel(String s) => switch (s) {
  'verified' => 'موثّق',
  'rejected' => 'مرفوض',
  'suspended' => 'موقوف',
  _ => 'قيد المراجعة',
};

Color providerStatusColor(String s) => switch (s) {
  'verified' => AppColors.good,
  'rejected' => AppColors.critical,
  'suspended' => AppColors.critical,
  _ => AppColors.warning,
};

/// أنواع المستندات كما يقيّدها الجدول — أي قيمةٍ خارجها يرفضها القيد.
const documentTypes = <({String value, String label})>[
  (value: 'id_card', label: 'الهوية الشخصية'),
  (value: 'commercial_register', label: 'السجل التجاري'),
  (value: 'certificate', label: 'شهادة أو ترخيص'),
  (value: 'insurance', label: 'تأمين'),
  (value: 'work_samples', label: 'نماذج أعمال'),
];

String documentTypeLabel(String value) =>
    documentTypes.where((t) => t.value == value).firstOrNull?.label ?? value;

String documentStatusLabel(String s) => switch (s) {
  'approved' => 'مقبول',
  'rejected' => 'مرفوض',
  _ => 'قيد المراجعة',
};

Color documentStatusColor(String s) => switch (s) {
  'approved' => AppColors.good,
  'rejected' => AppColors.critical,
  _ => AppColors.warning,
};

/// أسبابُ النزاع كما يقيّدها الجدول — أي قيمةٍ خارجها يرفضها القيد.
const disputeCategories = <({String value, String label})>[
  (value: 'no_show', label: 'لم يحضر / لم يُنفَّذ'),
  (value: 'quality', label: 'الخدمة دون المتّفق عليه'),
  (value: 'payment', label: 'مشكلة في مبلغ أو استرجاع'),
  (value: 'cancellation', label: 'خلاف على الإلغاء'),
  (value: 'behaviour', label: 'سلوك غير لائق'),
  (value: 'other', label: 'سبب آخر'),
];

String disputeCategoryLabel(String value) =>
    disputeCategories.where((c) => c.value == value).firstOrNull?.label ?? value;

String disputeStatusLabel(String s) => switch (s) {
  'investigating' => 'قيد النظر',
  'resolved' => 'حُسم',
  'closed' => 'مغلق',
  _ => 'مفتوح',
};

Color disputeStatusColor(String s) => switch (s) {
  'investigating' => AppColors.warning,
  'resolved' => AppColors.good,
  'closed' => AppColors.muted,
  _ => AppColors.critical,
};
