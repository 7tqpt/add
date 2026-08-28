// اختيارُ النقطة على الخريطة.
//
// **وبلا مفتاح خرائط.** البلاطاتُ من OpenStreetMap — مشروعٌ مفتوح، لا مفتاحَ
// له ولا فوترة. وشرطُ استعماله واحدٌ يُلتزم به هنا: تعريفُ التطبيق بنفسه في
// `userAgentPackageName` حتى يُعرف من يطلب، ونسبةُ الحقّ إلى أصحابه ظاهرةً
// على الخريطة كما هو مكتوبٌ في رخصتها.
//
// **وما يجب أن يُعرف قبل النشر الواسع:** خوادمُ بلاطات OSM تطوّعيّةٌ وسياستُها
// تطلب من التطبيقات الكبيرة أن تنتقل إلى مزوّدٍ تجاريّ. فهذا يكفي إطلاقاً
// ويكفي آلافاً، ولا يكفي إلى الأبد — والانتقالُ يومَها تبديلُ عنوانِ بلاطةٍ
// في هذا الملفّ وحده.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/geo.dart';
import '../core/theme.dart';
import '../ui/kit.dart';

/// يفتح الخريطة ويعيد النقطة المختارة، أو `null` إن رجع بلا اختيار.
///
/// و`GeoPoint.zero` ليست قيمةً هنا: من أراد **محوَ** نقطته يضغط «أزل الموقع»
/// فتعود `const GeoPoint(0, 0)` — وهي غيرُ صالحةٍ بتعريفها، فيقرؤها المتصل
/// «أزِلْها» لا «هذه نقطتك».
Future<GeoPoint?> pickLocation(
  BuildContext context, {
  GeoPoint? initial,
  String governorate = '',
}) {
  return Navigator.of(context).push<GeoPoint>(
    MaterialPageRoute(
      builder: (_) => MapPickerScreen(initial: initial, governorate: governorate),
    ),
  );
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initial, this.governorate = ''});

  final GeoPoint? initial;
  final String governorate;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _map = MapController();
  final _paste = TextEditingController();
  late GeoPoint _point = startingPoint(
    saved: widget.initial,
    governorate: widget.governorate,
  );

  /// أوَضع صاحبُها نقطةً فعلاً، أم هي بدايةُ المحافظة وحدها؟
  ///
  /// **والفرقُ ليس تجميلاً:** لو حُفظ مركزُ المحافظة كأنّه موقعُ العرس لَسِيق
  /// المصوّرُ إلى وسط صنعاء بدل بيتٍ في السنينة — وهو أسوأُ من ألّا يكون
  /// هناك موقعٌ أصلاً، لأنّه يبدو دقيقاً.
  late bool _placed = widget.initial != null;

  String? _pasteError;

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _moveTo(GeoPoint point, {double? zoom}) {
    setState(() {
      _point = point;
      _placed = true;
      _pasteError = null;
    });
    _map.move(LatLng(point.lat, point.lng), zoom ?? _map.camera.zoom);
  }

  void _readPasted() {
    final found = parseGeoLink(_paste.text);
    if (found == null) {
      setState(() => _pasteError = _paste.text.contains('goo.gl')
          // الرابطُ المختصر لا رقمَ فيه، وقولُ «غير صحيح» يظلمه.
          ? 'هذا رابطٌ مختصر — افتحه في الخرائط أوّلاً ثمّ انسخ الرابط الكامل.'
          : 'لم أجد موقعاً في هذا النصّ.');
      return;
    }
    _moveTo(found, zoom: 16);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('موقع المناسبة'),
        actions: [
          if (_placed)
            TextButton(
              onPressed: () => Navigator.of(context).pop(const GeoPoint(0, 0)),
              child: const Text('أزل الموقع',
                  style: TextStyle(color: AppColors.critical)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: LatLng(_point.lat, _point.lng),
                    initialZoom: _placed ? 16 : 12,
                    minZoom: 4,
                    maxZoom: 19,
                    // **الدبّوسُ ثابتٌ في وسط الشاشة والخريطةُ تتحرّك تحته.**
                    // وهو أدقُّ من نقرةٍ بالإصبع على الهاتف: الإصبعُ يغطّي ما
                    // يشير إليه، فيقع الدبّوس حيث لا يرى صاحبُه.
                    onPositionChanged: (camera, hasGesture) {
                      if (!hasGesture) return;
                      setState(() {
                        _point = GeoPoint(
                          camera.center.latitude,
                          camera.center.longitude,
                        );
                        _placed = true;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      // شرطُ رخصة OSM: يُعرَّف التطبيقُ بنفسه.
                      userAgentPackageName: 'company.sdd.farhati',
                      maxNativeZoom: 19,
                    ),
                    // نسبةُ الحقّ إلى أصحابه — واجبةٌ في الرخصة لا زينة.
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap',
                          onTap: () => launchUrl(
                            Uri.parse('https://openstreetmap.org/copyright'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // الدبّوس. ويُزاح بنصف ارتفاعه لأنّ طرفه هو ما يشير لا مركزه.
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: _placed ? AppColors.accent : AppColors.muted,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black38),
                      ],
                    ),
                  ),
                ),

                if (!_placed)
                  Positioned(
                    top: Space.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Space.md, vertical: Space.sm),
                      decoration: BoxDecoration(
                        color: AppColors.accentDeep.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'حرّك الخريطة حتى يقف الدبّوس على المكان',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── اللصق والتأكيد ────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(
              Space.lg,
              Space.md,
              Space.lg,
              MediaQuery.of(context).viewInsets.bottom + Space.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // **ولصقُ الرابط بابٌ أوّل لا احتياط.** هكذا تُتبادل المواقع
                // هنا فعلاً: يُرسَل الموقع في واتساب فيصل رابطاً. ومن كان
                // موقعُه في يده لا يُطالَب بأن يبحث عنه من جديد.
                TextField(
                  controller: _paste,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'أو الصق رابط الموقع',
                    hintText: 'https://maps.google.com/…',
                    errorText: _pasteError,
                    suffixIcon: TextButton(
                      onPressed: _readPasted,
                      child: const Text('اقرأ'),
                    ),
                  ),
                  onSubmitted: (_) => _readPasted(),
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _placed ? _point.text : 'لم يُحدَّد موقعٌ بعد',
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontSize: 12,
                          color: _placed ? AppColors.ink2 : AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    FilledButton(
                      // **ولا يُؤكَّد ما لم يُوضع.** الزرُّ معطَّلٌ حتى يحرّك
                      // الخريطةَ أو يلصق رابطاً، فلا يُحفظ مركزُ المحافظة
                      // موقعاً للعرس.
                      onPressed: _placed
                          ? () => Navigator.of(context).pop(_point)
                          : null,
                      child: const Text('تأكيد الموقع'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// صفُّ «موقع على الخريطة» — يُستعمل في دفتر العناوين وفي نموذج الحجز.
///
/// **ومكوّنٌ واحدٌ لا نسختان:** الشاشتان تعرضان الشيء نفسه وتفتحان المنتقي
/// نفسه، ونسختان متطابقتان تفترقان بمرور الوقت — يُعدَّل نصٌّ في إحداهما
/// فتبقى الأخرى، وهذا وقع في هذا المشروع مرّتين.
///
/// وهو هنا مع المنتقي لا في شاشةٍ من الشاشتين: من وضعه في إحداهما جعل
/// الأخرى تستوردها كلَّها لتصل إلى صفّ.
class LocationRow extends StatelessWidget {
  const LocationRow({
    super.key,
    required this.point,
    required this.governorate,
    required this.onChanged,
  });

  final GeoPoint? point;
  final String governorate;
  final ValueChanged<GeoPoint?> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await pickLocation(
      context,
      initial: point,
      governorate: governorate,
    );
    if (picked == null) return;
    // **النقطةُ غيرُ الصالحة تعني «أزِلْها»** — وهي ما يعيده زرُّ «أزل الموقع»
    // في المنتقي. فلا حاجة إلى نوعٍ ثانٍ ولا إلى علمٍ منفصل.
    onChanged(picked.isValid ? picked : null);
  }

  @override
  Widget build(BuildContext context) {
    final set = point != null;
    return InkWell(
      key: const ValueKey('location-row'),
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            Icon(
              set ? Icons.location_on : Icons.add_location_alt_outlined,
              size: 22,
              color: set ? AppColors.accent : AppColors.muted,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(set ? 'الموقع محدَّد على الخريطة' : 'حدّد الموقع على الخريطة'),
                  const SizedBox(height: 2),
                  Muted(
                    set
                        ? point!.text
                        : 'اختياري — ويوفّر على مقدّم الخدمة أن يتّصل ليسأل عن الطريق',
                    size: 11,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
