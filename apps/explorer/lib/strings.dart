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
  String get printMap => _('اطبع خريطة ورقية', 'Print a paper map');
  String get printMapHint => _('لوقت انقطاع الإنترنت أو GPS', 'For when the internet or GPS is down');

  // Offline maps
  String get offlineMaps => _('خرائط بلا إنترنت', 'Offline maps');
  String get offlineMapsHint => _('احفظ الخريطة على الهاتف', 'Save the map on this phone');
  String get offlineIntro => _(
    'احفظ الخريطة على هاتفك لتعمل دون إنترنت، بالنمطين الفاتح والداكن وباللغتين. البحث والاتجاهات ما زالا يحتاجان إلى الإنترنت، أما موقعك بيدك والبوصلة فيعملان دونه.',
    'Save the map on your phone so it works with no internet, in light and dark and in both languages. Search and directions still need the internet; setting your position by hand and the compass work without it.',
  );
  String get jordan => _('الأردن كاملاً', 'All of Jordan');
  String get jordanHint => _('كل الشوارع، نحو 100 ميغابايت', 'Every street, about 100 MB');
  String get thisArea => _('المنطقة الظاهرة بتفصيل كامل', 'The area on screen, in full detail');
  String get thisAreaHint =>
      _('يضيف المباني ومزيداً من المحلات والأماكن', 'Adds buildings and more shops and places');
  String get zoomInFirst => _('المنطقة كبيرة: كبّر الخريطة على مدينة أولاً', 'Too big: zoom the map in on a city first');
  String get download => _('تنزيل', 'Download');
  String get downloading => _('جارٍ التنزيل…', 'Downloading…');
  String get keepOpen => _('أبقِ التطبيق مفتوحاً حتى ينتهي التنزيل.', 'Keep the app open until the download finishes.');
  String get savedMaps => _('الخرائط المحفوظة', 'Saved maps');
  String get noSavedMaps => _('لا خرائط محفوظة بعد.', 'No saved maps yet.');
  String get unfinished => _('لم يكتمل', 'Unfinished');
  String get resume => _('أكمل', 'Resume');
  String get delete => _('احذف', 'Delete');
  String get offlineDone => _('حُفظت الخريطة. ستعمل دون إنترنت.', 'Map saved. It works with no internet now.');
  String get offlineFailed => _('توقف التنزيل. تحقق من الاتصال ثم أكمل.', 'The download stopped. Check the connection, then resume.');
  String get offlineWebOnly =>
      _('حفظ الخرائط متاح في تطبيق الهاتف فقط.', 'Saving maps works in the phone app only.');
  String areaAround(String lat, String lng) => _('منطقة حول $lat، $lng', 'Area around $lat, $lng');
  String mb(int bytes) {
    final v = bytes / 1e6;
    final t = v < 10 ? v.toStringAsFixed(1) : v.round().toString();
    return _('$t ميغابايت', '$t MB');
  }

  // Contribute (OpenStreetMap notes)
  String get addPlace => _('إضافة مكان ناقص', 'Add a missing place');
  String get addPlaceShort => _('إضافة مكان', 'Add place');
  String get suggestEdit => _('اقتراح تعديل', 'Suggest an edit');
  String get placeName => _('اسم المكان', 'Place name');
  String get placeType => _('نوع المكان', 'Type of place');
  String get whatsWrong => _('ما المشكلة؟', "What's wrong?");
  String get problemClosed => _('مغلق نهائياً', 'Closed for good');
  String get problemName => _('الاسم خاطئ', 'Wrong name');
  String get problemLocation => _('الموقع خاطئ', 'Wrong location');
  String get problemDetails => _('معلومات خاطئة', 'Wrong details');
  String get problemOther => _('شيء آخر', 'Something else');
  String get details => _('تفاصيل', 'Details');
  String get detailsHintAdd => _('مثلاً: رقم الهاتف، ساعات العمل، الطابق', 'For example: phone, opening hours, floor');
  String get detailsHintEdit => _('ما الصحيح؟', 'What is correct?');
  String get publicNotice => _(
    'يُرسل اقتراحك كملاحظة عامة إلى OpenStreetMap ليراجعها متطوعون. لا تكتب معلومات شخصية.',
    'Your suggestion is sent as a public note to OpenStreetMap, where volunteers review it. Do not include personal information.',
  );
  String get send => _('إرسال', 'Send');
  String get nameRequired => _('اكتب اسم المكان', 'Enter the place name');
  String get sendFailed => _('تعذّر الإرسال. حاول مرة أخرى.', 'Could not send. Try again.');
  String get thanks => _('شكراً لك', 'Thank you');
  String get sentExplain => _(
    'وصل اقتراحك إلى OpenStreetMap. بعد أن يراجعه المتطوعون يظهر على الخريطة مع التحديث الشهري.',
    'Your suggestion reached OpenStreetMap. Once volunteers review it, it appears on the map with the monthly update.',
  );
  String get viewNote => _('عرض الملاحظة', 'View note');
  String get done => _('تم', 'Done');
  String placeTypeLabel(String key) => switch (key) {
    'restaurant' => _('مطعم', 'Restaurant'),
    'cafe' => _('مقهى', 'Café'),
    'supermarket' => _('سوبرماركت أو بقالة', 'Supermarket or grocery'),
    'pharmacy' => _('صيدلية', 'Pharmacy'),
    'clinic' => _('عيادة', 'Clinic'),
    'hospital' => _('مستشفى', 'Hospital'),
    'place_of_worship' => _('مسجد أو مكان عبادة', 'Mosque or place of worship'),
    'fuel' => _('محطة وقود', 'Fuel station'),
    'bank' => _('بنك', 'Bank'),
    'atm' => _('صرّاف آلي', 'ATM'),
    'hotel' => _('فندق', 'Hotel'),
    'school' => _('مدرسة', 'School'),
    'shop' => _('متجر', 'Shop'),
    'office' => _('مكتب أو شركة', 'Office or company'),
    _ => _('آخر', 'Other'),
  };
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
  // Directions
  String travelMode(MapelevenTravelMode m) => switch (m) {
    MapelevenTravelMode.car => _('سيارة', 'Car'),
    MapelevenTravelMode.walk => _('مشي', 'Walk'),
    MapelevenTravelMode.bike => _('دراجة', 'Bike'),
  };
  String get from => _('من', 'From');
  String get to => _('إلى', 'To');
  String get yourLocation => _('موقعك', 'Your location');
  String get mapCentre => _('وسط الخريطة', 'Map centre');
  String get chooseStart => _('اختر نقطة البداية', 'Choose a starting point');
  String get routing => _('جارٍ حساب الطريق…', 'Finding a route…');
  String get noRoute => _('لا يوجد طريق بين النقطتين.', 'No route connects these points.');
  String get routeFailed => _('تعذّر حساب الطريق. حاول مرة أخرى.', "Couldn't get a route. Try again.");
  String get steps => _('الخطوات', 'Steps');
  String get noTraffic => _('الوقت تقديري ولا يشمل الازدحام.', 'Times are estimates without live traffic.');
  String routeN(int n) => _('طريق $n', 'Route $n');
  String duration(Duration d) {
    final m = (d.inSeconds / 60).round();
    if (m < 60) return _('$m د', '$m min');
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? _('$h س', '$h h') : _('$h س $r د', '$h h $r min');
  }

  String get locationOff => _(
    'لم نتمكن من تحديد موقعك. فعّل خدمة الموقع ثم حاول مرة أخرى.',
    "Couldn't get your location. Turn on location services and try again.",
  );
  // Position by hand and compass (for when GPS is off or wrong)
  String get imHere => _('أنا هنا', "I'm here");
  String get compass => _('البوصلة', 'Compass');
  String get setByHand => _('حدده بنفسك', 'Set it by hand');
  String get pickHint => _(
    'اضغط على معلم تراه قربك: دوار، مسجد، محطة وقود…',
    'Tap a landmark you can see near you: a roundabout, a mosque, a petrol station…',
  );
  String get cancel => _('إلغاء', 'Cancel');
  String get change => _('تغيير', 'Change');
  String get pickedPoint => _('النقطة التي اخترتها', 'The point you picked');
  String hereSet(String name) => _('موقعك الآن: $name. المسافات والاتجاهات تبدأ من هنا.', 'You are at $name. Distances and directions start here.');
  String youSetHere(String name) => _('موقعك (حددته بنفسك): $name', 'Your position (set by you): $name');
  String straightLine(String d) => _('$d بخط مستقيم', '$d in a straight line');
  String get fromGps => _('من موقعك على GPS (يتحدث)', 'From your GPS position (live)');
  String fromManual(String name) => _('نقطة البداية: $name، وقد حددتها بنفسك', 'From $name, which you set');
  String get fromCentre => _('من وسط الخريطة. حدد موقعك لنتيجة أدق.', 'From the map centre. Set your position for a better answer.');
  String get turnHint => _('استدر حتى يشير السهم إلى الأمام، ثم امشِ باستقامة.', 'Turn until the arrow points ahead, then walk straight.');
  String get facingIt => _('أنت متجه نحوه', "You're facing it");
  String get calibrate => _(
    'قد تكون البوصلة غير دقيقة: حرّك الهاتف على شكل رقم 8، وابتعد عن السيارات والحديد.',
    'The compass may be off: move the phone in a figure 8, away from cars and metal.',
  );
  String noCompass(String dir, int deg) => _(
    'لا توجد بوصلة في هذا الجهاز. ببوصلة يدوية، اتجه نحو $dir (${_deg(deg)}) وامشِ.',
    'This device has no compass. With a hand compass, face $dir ($deg°) and walk.',
  );
  String get compassNote => _(
    'البوصلة تعمل بلا إنترنت ولا GPS. أعلى الخريطة الورقية هو الشمال.',
    'The compass works without internet or GPS. The top of a paper map is north.',
  );
  /// Degrees kept left-to-right inside Arabic text, so the sign stays after the number.
  String _deg(int d) => '\u2066$d°\u2069';
  String head(String dir, int deg) => _('باتجاه $dir (${_deg(deg)})', 'Head $dir ($deg°)');

  // GPS jump warning
  String get gpsDoubtTitle => _('قد يكون موقعك غير صحيح', 'Your location may be wrong');
  String gpsDoubtMocked() => _(
    'يقول الهاتف إن الموقع يأتي من تطبيق وليس من GPS.',
    'The phone says this location comes from an app, not from GPS.',
  );
  String gpsDoubtHand(String d, String name) => _(
    'يضعك GPS على بعد $d من $name، الموقع الذي حددته بنفسك.',
    'GPS puts you $d from $name, the position you set by hand.',
  );
  String gpsDoubtJump(String d, String since) => _(
    'يضعك GPS على بعد $d من مكانك قبل $since. لا تقطع سيارة هذه المسافة بهذه السرعة.',
    'GPS puts you $d from where you were $since ago. No car covers that so fast.',
  );
  String get gpsDoubtWhy => _(
    'قد يكون GPS مشوشًا أو مزيفًا في منطقتك. إن كنت تعرف مكانك، حدده بنفسك.',
    'GPS may be jammed or faked where you are. If you know where you are, set it by hand.',
  );
  String get useAnyway => _('استخدمه رغم ذلك', 'Use it anyway');
  String get ignore => _('تجاهل', 'Ignore');
  String get gpsJumped => _('قفز GPS إلى مكان بعيد فتجاهلناه.', 'GPS jumped far away, so it is being ignored.');

  String cardinal(double deg) {
    final i = ((deg % 360) / 45).round() % 8;
    return ar
        ? const ['الشمال', 'الشمال الشرقي', 'الشرق', 'الجنوب الشرقي', 'الجنوب', 'الجنوب الغربي', 'الغرب', 'الشمال الغربي'][i]
        : const ['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'][i];
  }

  /// Compass letters: N, E, S, W.
  List<String> get compassPoints => ar ? const ['ش', 'شر', 'ج', 'غ'] : const ['N', 'E', 'S', 'W'];

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
