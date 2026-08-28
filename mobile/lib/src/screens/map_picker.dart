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

import '../core/device_location.dart';
import '../core/geo.dart';
import '../core/place_search.dart';
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

  /// أيُقرأ الموقعُ الآن؟ — الزرُّ يدور ولا يُضغط مرّتين.
  bool _locating = false;

  /// نتائجُ البحث باسم المكان، وحالتُه.
  List<Place> _results = const [];
  bool _searching = false;

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

  /// حقلٌ واحدٌ يقبل الاثنين: **اسمَ مكانٍ أو رابطَه**.
  ///
  /// **وحقلان كانا سيصيران عبئاً.** قوقل ماب فيه صندوقٌ واحد، ومن يفتح شاشةً
  /// فيها صندوقان يقف ليقرأ أيُّهما لأيّ. والفرقُ بينهما يُعرف من النصّ نفسه
  /// لا من صاحبه: ما فيه إحداثيّةٌ يُقرأ إحداثيّة، وما سواه يُبحث اسماً.
  Future<void> _readField() async {
    final text = _paste.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();

    // ١) أهو رابطٌ أو إحداثيّتان؟ فذاك جوابٌ فوريٌّ بلا شبكة.
    final found = parseGeoLink(text);
    if (found != null) {
      setState(() => _results = const []);
      _moveTo(found, zoom: 16);
      return;
    }

    // ٢) والرابطُ المختصر يُقال فيه ما يُفعل — ولا يُبحث اسماً، فليس اسماً.
    if (text.contains('goo.gl') || text.contains('http')) {
      setState(() {
        _results = const [];
        _pasteError = text.contains('goo.gl')
            ? 'هذا رابطٌ مختصر — افتحه في الخرائط أوّلاً ثمّ انسخ الرابط الكامل.'
            : 'لم أجد موقعاً في هذا الرابط.';
      });
      return;
    }

    // ٣) وما سواه اسمُ مكان.
    setState(() {
      _searching = true;
      _pasteError = null;
      _results = const [];
    });
    try {
      final places = await searchPlaces(text);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = places;
        // **و«لا نتائج» تُقال، ولا تُترك القائمةُ فارغةً بلا خبر.**
        _pasteError = places.isEmpty
            ? 'لم أجد مكاناً بهذا الاسم. جرّب اسم الحيّ أو المدينة، أو حرّك '
                'الخريطة بإصبعك.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _pasteError = e is String ? e : 'تعذّر البحث الآن.';
      });
    }
  }

  /// يكبّر أو يصغّر درجةً — **ويلتزم حدَّي الخريطة**.
  ///
  /// ولولا القصُّ لَطُلبت بلاطاتٌ في مستوىً لا وجودَ له، فتظهر الخريطةُ
  /// رماديّةً ولا يُقال لماذا.
  void _zoomBy(double delta) {
    final target = (_map.camera.zoom + delta).clamp(4.0, 19.0);
    _map.move(_map.camera.center, target);
  }

  void _pickPlace(Place place) {
    setState(() {
      _results = const [];
      _paste.text = shortPlaceName(place.name);
    });
    _moveTo(place.point, zoom: 15);
  }

  /// «موقعي الحالي» — يقرأ موقعَ الجهاز وينقل الخريطةَ إليه.
  ///
  /// **وكلُّ فشلٍ يُقال نصّاً.** أربعةُ أسبابٍ مختلفةٍ لكلٍّ علاجُه، وزرٌّ
  /// يُضغط فلا يقع شيءٌ ولا تظهر رسالةٌ يجعل صاحبَه يضغط مرّاتٍ يظنّ التطبيق
  /// معلّقاً. وهذا ما يُفرّق زرَّ موقعٍ يعمل من زرٍّ موجود.
  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final result = await currentLocation();
    if (!mounted) return;
    setState(() => _locating = false);

    final point = result.point;
    if (point == null) {
      showMessage(context, locationFailureText(result.reason!));
      return;
    }
    // **وستَّ عشرةَ درجةَ تقريبٍ لا تسعَ عشرة.** دقّةُ `medium` عشراتُ
    // أمتار، وتقريبٌ إلى أقصى الحدّ يُري صاحبَه دبّوساً على سطح جارِه
    // فيظنّه خطأً — والصوابُ أن يُفتح على الحيّ ثمّ يضبطه بإصبعه.
    _moveTo(point, zoom: 16);
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

                // ── «موقعي الحالي» ────────────────────────────────────
                //
                // **في أسفل الخريطة إلى اليسار** — حيث يضعه Google Maps وحيث
                // تبحث عنه العين. ولو وُضع في الشريط العلويّ لَكان زرّاً
                // ثالثاً بين «رجوع» و«أزل الموقع» لا يُقرأ أيُّها أيّ.
                //
                // ويرتفع عن الحافّة بما يكفي ألّا يغطّي نسبةَ حقّ OSM، وهي
                // واجبةٌ في الرخصة لا زينة.
                Positioned(
                  left: Space.md,
                  bottom: 34,
                  child: FloatingActionButton.small(
                    key: const ValueKey('my-location'),
                    heroTag: 'my-location',
                    onPressed: _locating ? null : _useMyLocation,
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.accent,
                    tooltip: 'موقعي الحالي',
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 20),
                  ),
                ),

                // ── أزرارُ التكبير ────────────────────────────────────
                //
                // **والإصبعان ليسا بديلاً عنهما.** من يمسك جواله بيدٍ واحدة —
                // وهو حالُ من يقف في قاعةٍ يسأل ويكتب — لا يستطيع القرصَ
                // بإصبعين. وهما في قوقل ماب لهذا السبب نفسه.
                Positioned(
                  right: Space.md,
                  bottom: 34,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ZoomButton(
                        key: const ValueKey('zoom-in'),
                        icon: Icons.add,
                        tooltip: 'تكبير',
                        onTap: () => _zoomBy(1),
                      ),
                      const SizedBox(height: Space.sm),
                      _ZoomButton(
                        key: const ValueKey('zoom-out'),
                        icon: Icons.remove,
                        tooltip: 'تصغير',
                        onTap: () => _zoomBy(-1),
                      ),
                    ],
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
                  key: const ValueKey('place-field'),
                  controller: _paste,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'ابحث عن مكان، أو الصق رابطه',
                    hintText: 'حدة، السنينة، جامع الصالح…',
                    errorText: _pasteError,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton(
                            onPressed: _readField,
                            child: const Text('ابحث'),
                          ),
                  ),
                  onSubmitted: (_) => _readField(),
                ),

                // ── نتائجُ البحث ──────────────────────────────────────────
                //
                // **ستٌّ على الأكثر وفي صندوقٍ محدود الارتفاع.** قائمةٌ تطول
                // تدفع زرَّ التأكيد تحت الطيّة، فيبحث صاحبُها عنه.
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: Space.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 190),
                    child: Material(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.hairline),
                        itemBuilder: (context, i) {
                          final place = _results[i];
                          return ListTile(
                            key: ValueKey('place-$i'),
                            dense: true,
                            leading: const Icon(Icons.place_outlined,
                                size: 18, color: AppColors.accent),
                            title: Text(
                              shortPlaceName(place.name),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, height: 1.5),
                            ),
                            onTap: () => _pickPlace(place),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: Space.md),
                // **الإحداثيّاتُ سطرٌ والزرُّ سطرٌ تحته، لا صفٌّ يجمعهما.**
                //
                // وكانا في `Row`، فكان الزرُّ يُعطى عرضاً **لا نهائيّاً**:
                // نمطُ `FilledButton` في هذا التطبيق فيه
                // `minimumSize: Size.fromHeight(48)` — أي عرضٌ لا نهائيّ —
                // وهو صوابٌ داخل عمودٍ محدود العرض، ويرمي داخل صفٍّ يعطي
                // أبناءه عرضاً غيرَ محدود. فكانت الشاشةُ ترمي ثلاثةَ عشرَ
                // استثناءَ تخطيطٍ عند فتحها.
                //
                // ولم يكشفه أحد لأنّ هذه الشاشة لم تُركَّب في اختبارٍ قطّ —
                // وهي الشاشةُ الوحيدة كذلك في التطبيق.
                Text(
                  // **ومفتاحٌ عليه:** النصُّ هنا إحداثيّتان، وحقلُ البحث فوقه
                  // قد يحمل الإحداثيّتين نفسَهما إن لُصقتا — فباحثٌ يسأل عن
                  // النصّ وحده يجد اثنين ولا يدري أيُّهما قرأه.
                  key: const ValueKey('point-text'),
                  _placed ? _point.text : 'لم يُحدَّد موقعٌ بعد',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 12,
                    color: _placed ? AppColors.ink2 : AppColors.muted,
                  ),
                ),
                const SizedBox(height: Space.md),
                FilledButton(
                  // **ولا يُؤكَّد ما لم يُوضع.** الزرُّ معطَّلٌ حتى يحرّك
                  // الخريطةَ أو يلصق رابطاً، فلا يُحفظ مركزُ المحافظة
                  // موقعاً للعرس.
                  onPressed:
                      _placed ? () => Navigator.of(context).pop(_point) : null,
                  child: const Text('تأكيد الموقع'),
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

/// زرُّ تكبيرٍ صغيرٌ أبيضُ على الخريطة.
class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
