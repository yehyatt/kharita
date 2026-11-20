import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mapeleven/mapeleven.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'delivery_page.dart';
import 'explore_page.dart';
import 'saved_page.dart';
import 'strings.dart';

const brand = Color(0xFF0F766E);
const accent = Color(0xFFF59E0B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(ExplorerApp(state: state));
}

class ExplorerApp extends StatelessWidget {
  const ExplorerApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'Mapeleven',
        debugShowCheckedModeBanner: false,
        locale: Locale(state.language.name),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: brand, primary: brand, secondary: accent),
          useMaterial3: true,
          fontFamily: 'Plex',
        ),
        home: Shell(state: state),
      ),
    );
  }
}

/// Bottom navigation between Explore, Saved and the Delivery demo.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});
  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _explore = GlobalKey<ExplorePageState>();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = S(widget.state.language);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          ExplorePage(key: _explore, state: widget.state),
          SavedPage(
            state: widget.state,
            onOpen: (place) {
              setState(() => _tab = 0);
              _explore.currentState?.showSaved(place);
            },
          ),
          // Built only when opened, so its map does not load in the background.
          _tab == 2 ? DeliveryPage(state: widget.state) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: s.explore,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_border),
            selectedIcon: const Icon(Icons.bookmark),
            label: s.saved,
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping),
            label: s.delivery,
          ),
        ],
      ),
    );
  }
}

/// Small round button floating over the map.
class MapButton extends StatelessWidget {
  const MapButton({super.key, required this.icon, required this.onPressed, this.tooltip, this.color});
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black38,
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.black87),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// Theme and language picker shown from the layers button.
/// [center] and [zoom] place the print page's frame where the map is.
Future<void> showLayersSheet(BuildContext context, AppState state, {LatLng? center, double? zoom}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = S(state.language);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.mapType, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final t in AppState.themes)
                      _ThemeTile(
                        label: s.theme(t),
                        colors: _ThemeTile.swatches[t]!,
                        selected: !state.satellite && state.theme == t,
                        onTap: () {
                          state.setSatellite(false);
                          state.setTheme(t);
                        },
                      ),
                    if (AppState.imagery != null)
                      _ThemeTile(
                        label: s.satellite,
                        colors: const [Color(0xFF3F5F3A), Color(0xFF8C7A5B), Color(0xFF2F4F6F)],
                        icon: Icons.satellite_alt_outlined,
                        selected: state.satellite,
                        onTap: () => state.setSatellite(true),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(s.language, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<MapelevenLanguage>(
                  segments: const [
                    ButtonSegment(value: MapelevenLanguage.ar, label: Text('العربية')),
                    ButtonSegment(value: MapelevenLanguage.en, label: Text('English')),
                  ],
                  selected: {state.language},
                  onSelectionChanged: (v) => state.setLanguage(v.first),
                ),
                const SizedBox(height: 12),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.print_outlined),
                  title: Text(s.printMap),
                  subtitle: Text(s.printMapHint),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    final c = center ?? const LatLng(31.9539, 35.9106);
                    final at = '${c.longitude.toStringAsFixed(4)},${c.latitude.toStringAsFixed(4)},${(zoom ?? 11).toStringAsFixed(1)}';
                    launchUrl(Uri.parse('https://mapeleven.dev/print/#$at'), mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.label, required this.colors, required this.selected, required this.onTap, this.icon});
  final String label;
  final List<Color> colors;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  static const swatches = {
    MapelevenTheme.light: [Color(0xFFF2EFE9), Color(0xFFAAD3DF), Color(0xFFFFFFFF)],
    MapelevenTheme.dark: [Color(0xFF34373D), Color(0xFF1E2024), Color(0xFF5A5D63)],
    MapelevenTheme.white: [Color(0xFFFFFFFF), Color(0xFFDCE6EA), Color(0xFFEDEDED)],
    MapelevenTheme.grayscale: [Color(0xFFE4E4E4), Color(0xFFC9C9C9), Color(0xFFFFFFFF)],
    MapelevenTheme.black: [Color(0xFF111111), Color(0xFF2B2B2B), Color(0xFF3D3D3D)],
  };

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? brand : Colors.black12, width: selected ? 3 : 1),
              gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: icon == null ? null : Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}
