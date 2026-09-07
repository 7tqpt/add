import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';

String bookingStatusLabel(BookingStatus s) => switch (s) {
  BookingStatus.pendingProvider => tr('بانتظار مقدّم الخدمة'),
  BookingStatus.confirmed => tr('مؤكد'),
  BookingStatus.completed => tr('منفّذ'),
  BookingStatus.rejected => tr('مرفوض'),
  BookingStatus.cancelled => tr('ملغي'),
  BookingStatus.expired => tr('منتهٍ'),
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
  'open' => tr('مفتوحة'),
  'in_progress' => tr('قيد المعالجة'),
  'waiting_customer' => tr('بانتظار ردّك'),
  'resolved' => tr('تم الحل'),
  _ => tr('مغلقة'),
};

/// أبوابُ التذكرة.
///
/// **ودالّةٌ لا ثابت:** الثابتُ يُحسب مرّةً عند التحميل، فلو بدّل المستخدمُ
/// اللغةَ بقيت القائمةُ باللغة الأولى إلى أن يُغلق التطبيقُ ويُفتح.
List<({String value, String label})> ticketCategories() => [
  (value: 'booking', label: tr('الحجوزات')),
  (value: 'payment', label: tr('الدفع')),
  (value: 'account', label: tr('الحساب')),
  (value: 'technical', label: tr('عطل فني')),
  (value: 'suggestion', label: tr('اقتراح')),
  (value: 'other', label: tr('أخرى')),
];

String planStatusLabel(String s) => switch (s) {
  'confirmed' => tr('مكتملة الحجز'),
  'completed' => tr('انتهى العرس'),
  'cancelled' => tr('ملغاة'),
  _ => tr('قيد التجهيز'),
};

Color planStatusColor(String s) => switch (s) {
  'confirmed' => AppColors.good,
  'completed' => AppColors.muted,
  'cancelled' => AppColors.critical,
  _ => AppColors.warning,
};

String providerStatusLabel(String s) => switch (s) {
  'verified' => tr('موثّق'),
  'rejected' => tr('مرفوض'),
  'suspended' => tr('موقوف'),
  _ => tr('قيد المراجعة'),
};

Color providerStatusColor(String s) => switch (s) {
  'verified' => AppColors.good,
  'rejected' => AppColors.critical,
  'suspended' => AppColors.critical,
  _ => AppColors.warning,
};

/// أنواع المستندات كما يقيّدها الجدول — أي قيمةٍ خارجها يرفضها القيد.
/// دالّةٌ لا ثابت — للسبب نفسِه في `ticketCategories`.
List<({String value, String label})> documentTypes() => [
  (value: 'id_card', label: tr('الهوية الشخصية')),
  (value: 'commercial_register', label: tr('السجل التجاري')),
  (value: 'certificate', label: tr('شهادة أو ترخيص')),
  (value: 'insurance', label: tr('تأمين')),
  (value: 'work_samples', label: tr('نماذج أعمال')),
];

String documentTypeLabel(String value) =>
    documentTypes().where((t) => t.value == value).firstOrNull?.label ?? value;

String documentStatusLabel(String s) => switch (s) {
  'approved' => tr('مقبول'),
  'rejected' => tr('مرفوض'),
  _ => tr('قيد المراجعة'),
};

Color documentStatusColor(String s) => switch (s) {
  'approved' => AppColors.good,
  'rejected' => AppColors.critical,
  _ => AppColors.warning,
};

/// أسبابُ النزاع كما يقيّدها الجدول — أي قيمةٍ خارجها يرفضها القيد.
/// دالّةٌ لا ثابت — للسبب نفسِه في `ticketCategories`.
List<({String value, String label})> disputeCategories() => [
  (value: 'no_show', label: tr('لم يحضر / لم يُنفَّذ')),
  (value: 'quality', label: tr('الخدمة دون المتّفق عليه')),
  (value: 'payment', label: tr('مشكلة في مبلغ أو استرجاع')),
  (value: 'cancellation', label: tr('خلاف على الإلغاء')),
  (value: 'behaviour', label: tr('سلوك غير لائق')),
  (value: 'other', label: tr('سبب آخر')),
];

String disputeCategoryLabel(String value) =>
    disputeCategories().where((c) => c.value == value).firstOrNull?.label ?? value;

String disputeStatusLabel(String s) => switch (s) {
  'investigating' => tr('قيد النظر'),
  'resolved' => tr('حُسم'),
  'closed' => tr('مغلق'),
  _ => tr('مفتوح'),
};

Color disputeStatusColor(String s) => switch (s) {
  'investigating' => AppColors.warning,
  'resolved' => AppColors.good,
  'closed' => AppColors.muted,
  _ => AppColors.critical,
};
