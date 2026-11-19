import 'package:mapeleven/mapeleven.dart';

/// UI text in Arabic and English. The map language follows the UI language.
class S {
  const S(this.lang);
  final MapelevenLanguage lang;

  bool get ar => lang == MapelevenLanguage.ar;
  String _(String a, String e) => ar ? a : e;

  String get appName => _('ماب إليفن', 'Mapeleven');
  String get searchHint => _('ابحث عن مكان أو عنوان', 'Search places and addresses');
  String get explore => _('استكشف', 'Explore');
  String get saved => _('المحفوظة', 'Saved');
  String get delivery => _('توصيل', 'Delivery');
  String get layers => _('نمط الخريطة', 'Map style');
  String get language => _('اللغة', 'Language');
  String get satellite => _('قمر صناعي', 'Satellite');
  String get mapType => _('نوع الخريطة', 'Map type');
  String get directions => _('الاتجاهات', 'Directions');
  String get save => _('حفظ', 'Save');
  String get unsave => _('محفوظ', 'Saved');
  String get share => _('مشاركة', 'Share');
  String get copied => _('تم النسخ', 'Copied');
  String get whatsHere => _('ما هذا المكان؟', "What's here?");
  String get droppedPin => _('دبوس', 'Dropped pin');
  String get noResults => _('لا توجد نتائج', 'No results');
  String get searching => _('جارٍ البحث…', 'Searching…');
  String get recent => _('عمليات البحث الأخيرة', 'Recent searches');
  String get nothingSaved => _(
    'لم تحفظ أي مكان بعد. اضغط "حفظ" في أي مكان لتجده هنا.',
    'Nothing saved yet. Tap Save on any place to keep it here.',
  );
  String get zoomInForPlaces => _('قرّب الخريطة لعرض الأماكن', 'Zoom in to see places');
  String nPlaces(int n) => _('$n مكان قريب', '$n places nearby');
  String get locationOff => _(
    'لم نتمكن من تحديد موقعك. فعّل خدمة الموقع ثم حاول مرة أخرى.',
    "Couldn't get your location. Turn on location services and try again.",
  );
  String get poweredBy =>
      _('خرائط مفتوحة من OpenStreetMap عبر Mapeleven', 'Open maps from OpenStreetMap via Mapeleven');
  String km(double v) => v < 1
      ? _('${(v * 1000).round()} م', '${(v * 1000).round()} m')
      : _('${v.toStringAsFixed(1)} كم', '${v.toStringAsFixed(1)} km');
  String minutes(int m) => _('$m د', '$m min');

  // Theme names
  String theme(MapelevenTheme t) => switch (t) {
    MapelevenTheme.light => _('فاتح', 'Light'),
    MapelevenTheme.dark => _('داكن', 'Dark'),
    MapelevenTheme.white => _('أبيض', 'White'),
    MapelevenTheme.grayscale => _('رمادي', 'Grayscale'),
    MapelevenTheme.black => _('أسود', 'Black'),
  };

  // Delivery demo
  String get deliverTo => _('التوصيل إلى', 'Deliver to');
  String get movePin => _('حرّك الخريطة لوضع الدبوس على باب منزلك', 'Move the map to put the pin on your door');
  String get confirmAddress => _('تأكيد العنوان', 'Confirm address');
  String get locating => _('جارٍ تحديد العنوان…', 'Finding the address…');
  String get outOfZone => _('هذا العنوان خارج منطقة التغطية', 'This address is outside the delivery zone');
  String get inZone => _('ضمن منطقة التغطية', 'Inside the delivery zone');
  String get distributors => _('الموزعون', 'Distributors');
  String get onTheWay => _('السائق في الطريق', 'Driver on the way');
  String get arrived => _('وصل السائق', 'Driver has arrived');
  String get newOrder => _('طلب جديد', 'New order');
  String get simulated =>
      _('محاكاة: موقع السائق والموزعون بيانات تجريبية', 'Simulation: driver and distributors are sample data');
  String driverAway(String d, String eta) => _('على بعد $d · حوالي $eta', '$d away · about $eta');
  String nearest(String name) => _('أقرب موزع: $name', 'Nearest distributor: $name');

  // Categories
  String category(String key) => switch (key) {
    'restaurant' => _('مطاعم', 'Restaurants'),
    'cafe' => _('مقاهٍ', 'Cafés'),
    'pharmacy' => _('صيدليات', 'Pharmacies'),
    'hospital' => _('مستشفيات', 'Hospitals'),
    'fuel' => _('محطات وقود', 'Fuel'),
    'atm' => _('صرّاف آلي', 'ATMs'),
    'place_of_worship' => _('مساجد', 'Mosques'),
    'supermarket' => _('بقالات', 'Groceries'),
    'hotel' => _('فنادق', 'Hotels'),
    'bank' => _('بنوك', 'Banks'),
    _ => key,
  };

  /// A readable label for an OSM kind (`fast_food` → Fast food).
  String kind(String? k) {
    if (k == null) return '';
    const arKinds = {
      'restaurant': 'مطعم',
      'fast_food': 'وجبات سريعة',
      'cafe': 'مقهى',
      'pharmacy': 'صيدلية',
      'chemist': 'صيدلية',
      'hospital': 'مستشفى',
      'clinic': 'عيادة',
      'doctors': 'طبيب',
      'dentist': 'طبيب أسنان',
      'fuel': 'محطة وقود',
      'atm': 'صرّاف آلي',
      'bank': 'بنك',
      'place_of_worship': 'مكان عبادة',
      'supermarket': 'سوبرماركت',
      'convenience': 'بقالة',
      'hotel': 'فندق',
      'school': 'مدرسة',
      'university': 'جامعة',
      'park': 'حديقة',
      'museum': 'متحف',
      'mall': 'مركز تسوق',
      'bakery': 'مخبز',
      'police': 'شرطة',
      'clothes': 'ملابس',
      'electronics': 'إلكترونيات',
      'bus_stop': 'موقف حافلات',
      'post_office': 'بريد',
      'library': 'مكتبة',
      'city': 'مدينة',
      'town': 'بلدة',
      'village': 'قرية',
      'suburb': 'حي',
      'neighbourhood': 'حي',
      'residential': 'سكني',
      'attraction': 'معلم',
      'stadium': 'ملعب',
      'hairdresser': 'حلاق',
      'beauty': 'تجميل',
      'mobile_phone': 'هواتف',
    };
    if (ar) return arKinds[k] ?? '';
    final s = k.replaceAll('_', ' ');
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }
}
