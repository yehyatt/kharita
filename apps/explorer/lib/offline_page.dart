import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapeleven/mapeleven.dart';

import 'app_state.dart';
import 'strings.dart';

/// One download at a time, kept outside the page so leaving and coming back
/// still shows its progress.
class OfflineJob extends ChangeNotifier {
  OfflineJob._();
  static final instance = OfflineJob._();

  String? name;
  MapelevenOfflineProgress? progress;
  Object? error;
  bool justFinished = false;

  bool get running => name != null;

  Future<void> run(String label, Future<void> Function(void Function(MapelevenOfflineProgress)) work) async {
    if (running) return;
    name = label;
    progress = null;
    error = null;
    justFinished = false;
    notifyListeners();
    try {
      await work((p) {
        progress = p;
        notifyListeners();
      });
      justFinished = true;
    } catch (e) {
      error = e;
    } finally {
      name = null;
      notifyListeners();
    }
  }
}

/// Saves Jordan, or the area on screen, for use with no internet.
class OfflinePage extends StatefulWidget {
  const OfflinePage({super.key, required this.state, this.view, this.map});
  final AppState state;

  /// The area the map showed when the page opened.
  final LatLngBounds? view;
  final MapelevenController? map;

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  final job = OfflineJob.instance;
  List<MapelevenOfflinePack>? _packs;

  /// Full detail stops here: a city fits, a whole country does not.
  static const _areaTileLimit = 40000;

  S get s => S(widget.state.language);

  @override
  void initState() {
    super.initState();
    job.addListener(_onJob);
    _reload();
  }

  @override
  void dispose() {
    job.removeListener(_onJob);
    super.dispose();
  }

  void _onJob() {
    if (!mounted) return;
    setState(() {});
    if (!job.running) {
      _reload();
      if (job.justFinished || job.error != null) {
        final ok = job.error == null;
        job.justFinished = false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? s.offlineDone : s.offlineFailed)));
      }
    }
  }

  Future<void> _reload() async {
    final packs = await MapelevenOffline.packs().catchError((_) => <MapelevenOfflinePack>[]);
    if (mounted) setState(() => _packs = packs);
  }

  Future<void> _save(MapelevenOfflineArea area, double maxZoom) => job.run(
        area.name,
        (onProgress) => MapelevenOffline.download(
          provider,
          area,
          maxZoom: maxZoom,
          themes: AppState.themes,
          onProgress: onProgress,
        ),
      );

  Future<void> _saveView() async {
    final view = widget.view!;
    final c = LatLng(
      (view.southwest.latitude + view.northeast.latitude) / 2,
      (view.southwest.longitude + view.northeast.longitude) / 2,
    );
    // Name it after the place in the middle, else its coordinates.
    final place = await widget.map?.search
        .reverse(c, language: widget.state.language)
        .timeout(const Duration(seconds: 5))
        .catchError((_) => null);
    final name = [place?.city, place?.locality, place?.district, place?.name]
            .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null) ??
        s.areaAround(c.latitude.toStringAsFixed(3), c.longitude.toStringAsFixed(3));
    await _save(MapelevenOfflineArea(name, view), 15);
  }

  Future<void> _resume(MapelevenOfflinePack p) =>
      job.run(p.name, (onProgress) => MapelevenOffline.resume(p, onProgress: onProgress));

  Future<void> _delete(MapelevenOfflinePack p) async {
    await MapelevenOffline.delete(p);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final view = widget.view;
    final viewFits = view != null && MapelevenOffline.tileCount(view, 15) <= _areaTileLimit;

    return Scaffold(
      appBar: AppBar(title: Text(s.offlineMaps)),
      body: SafeArea(
        child: !MapelevenOffline.isSupported
            ? Padding(padding: const EdgeInsets.all(24), child: Text(s.offlineWebOnly, style: text.bodyLarge))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(s.offlineIntro, style: text.bodyMedium?.copyWith(color: Colors.black54)),
                  const SizedBox(height: 16),
                  _Choice(
                    icon: Icons.public,
                    title: s.jordan,
                    subtitle: s.jordanHint,
                    action: s.download,
                    onPressed: job.running ? null : () => _save(MapelevenOfflineArea.jordan, 14),
                  ),
                  if (view != null)
                    _Choice(
                      icon: Icons.crop_free,
                      title: s.thisArea,
                      subtitle: viewFits ? s.thisAreaHint : s.zoomInFirst,
                      action: s.download,
                      onPressed: job.running || !viewFits ? null : _saveView,
                    ),
                  if (job.running) ...[
                    const SizedBox(height: 16),
                    Text('${s.downloading} ${job.name}', style: text.titleSmall),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: job.progress?.fraction),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (job.progress != null) '${(job.progress!.fraction * 100).floor()}%',
                        if (job.progress != null) s.mb(job.progress!.bytes),
                        s.keepOpen,
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(s.savedMaps, style: text.titleMedium),
                  const SizedBox(height: 4),
                  if (_packs == null)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                  else if (_packs!.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(s.noSavedMaps))
                  else
                    for (final p in _packs!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(p.complete ? Icons.offline_pin : Icons.downloading,
                            color: p.complete ? const Color(0xFF16A34A) : const Color(0xFFB45309)),
                        title: Text(p.name),
                        subtitle: Text([s.mb(p.bytes), if (!p.complete) s.unfinished].join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!p.complete)
                              TextButton(onPressed: job.running ? null : () => _resume(p), child: Text(s.resume)),
                            IconButton(
                              tooltip: s.delete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: job.running ? null : () => _delete(p),
                            ),
                          ],
                        ),
                        onTap: () {
                          final b = p.bounds;
                          Navigator.of(context).pop();
                          widget.map?.flyTo(
                            LatLng((b.southwest.latitude + b.northeast.latitude) / 2,
                                (b.southwest.longitude + b.northeast.longitude) / 2),
                            zoom: p.maxZoom >= 15 ? 13 : 7,
                          );
                        },
                      ),
                ],
              ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.subtitle, required this.action, this.onPressed});
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: FilledButton.tonal(onPressed: onPressed, child: Text(action)),
      ),
    );
  }
}
