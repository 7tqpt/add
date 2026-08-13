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
