import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapeleven/mapeleven.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'main.dart';
import 'strings.dart';

/// OpenStreetMap API host. Test builds pass
/// `--dart-define=OSM_API=master.apis.dev.openstreetmap.org` so trial notes
/// land on the OSM test server, not in front of real mappers.
const osmApi = String.fromEnvironment('OSM_API', defaultValue: 'api.openstreetmap.org');
const _osmWeb = osmApi == 'api.openstreetmap.org' ? 'www.openstreetmap.org' : osmApi;

/// Place types offered when adding a place: OSM tag and label key.
const placeTypes = <(String, String)>[
  ('amenity=restaurant', 'restaurant'),
  ('amenity=cafe', 'cafe'),
  ('shop=supermarket', 'supermarket'),
  ('amenity=pharmacy', 'pharmacy'),
  ('amenity=clinic', 'clinic'),
  ('amenity=hospital', 'hospital'),
  ('amenity=place_of_worship', 'place_of_worship'),
  ('amenity=fuel', 'fuel'),
  ('amenity=bank', 'bank'),
  ('amenity=atm', 'atm'),
  ('tourism=hotel', 'hotel'),
  ('amenity=school', 'school'),
  ('shop=yes', 'shop'),
  ('office=yes', 'office'),
  ('', 'other'),
];

/// Adds a missing place, or reports a problem with an existing one, as an
/// OpenStreetMap note. Volunteer mappers review notes and update the map;
/// Mapeleven picks the change up with its next data refresh.
class ContributePage extends StatefulWidget {
  const ContributePage({super.key, required this.state, required this.position, this.place});
  final AppState state;
  final LatLng position;

  /// The place being corrected, or null to add a new one.
  final SavedPlace? place;

  @override
  State<ContributePage> createState() => _ContributePageState();
}

enum _Problem { closed, wrongName, wrongLocation, wrongDetails, other }

class _ContributePageState extends State<ContributePage> {
  final _name = TextEditingController();
  final _details = TextEditingController();
  String _type = placeTypes.first.$1;
  _Problem _problem = _Problem.closed;
  bool _sending = false;

  bool get _adding => widget.place == null;
  S get s => S(widget.state.language);

  @override
  void dispose() {
    _name.dispose();
    _details.dispose();
    super.dispose();
  }

  String _problemLabel(_Problem p, {bool english = false}) {
    final t = english ? const S(MapelevenLanguage.en) : s;
    return switch (p) {
      _Problem.closed => t.problemClosed,
      _Problem.wrongName => t.problemName,
      _Problem.wrongLocation => t.problemLocation,
      _Problem.wrongDetails => t.problemDetails,
      _Problem.other => t.problemOther,
    };
  }

  /// Note text: English first for mappers worldwide, with what the user typed.
  String _noteText() {
    final details = _details.text.trim();
    final lines = <String>[];
    if (_adding) {
      final type = placeTypes.firstWhere((t) => t.$1 == _type);
      lines.add('Missing place: ${_name.text.trim()}');
      if (type.$1.isNotEmpty) lines.add('Suggested tag: ${type.$1}');
    } else {
      final p = widget.place!;
      lines.add('Problem with "${p.name}"${p.kind == null ? '' : ' (${p.kind})'}: ${_problemLabel(_problem, english: true)}');
    }
    if (details.isNotEmpty) lines.add('Details: $details');
    lines.add('');
    lines.add('Reported by a user of the Mapeleven Explorer app. #mapeleven');
    return lines.join('\n');
  }

  Future<void> _send() async {
    if (_adding && _name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.nameRequired)));
      return;
    }
    setState(() => _sending = true);
    final uri = Uri.https(osmApi, '/api/0.6/notes.json', {
      'lat': widget.position.latitude.toStringAsFixed(7),
      'lon': widget.position.longitude.toStringAsFixed(7),
    });
    try {
      final res = await http.post(uri, body: {'text': _noteText()}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}: ${res.body}');
      final id = RegExp(r'"id":(\d+)').firstMatch(res.body)?.group(1);
      await _done(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.sendFailed}\n$e')));
    }
  }

  Future<void> _done(String? id) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: brand, size: 40),
        title: Text(s.thanks),
        content: Text(s.sentExplain),
        actions: [
          if (id != null)
            TextButton(
              onPressed: () => launchUrl(Uri.parse('https://$_osmWeb/note/$id'),
                  mode: LaunchMode.externalApplication),
              child: Text(s.viewNote),
            ),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(s.done)),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_adding ? s.addPlace : s.suggestEdit)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place, color: Color(0xFFDC2626)),
            title: Text(p?.name ?? s.droppedPin),
            subtitle: Text(
              '${widget.position.latitude.toStringAsFixed(5)}, ${widget.position.longitude.toStringAsFixed(5)}',
              textDirection: TextDirection.ltr,
              textAlign: s.ar ? TextAlign.right : TextAlign.left,
            ),
          ),
          const SizedBox(height: 8),
          if (_adding) ...[
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s.placeName, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: s.placeType, border: const OutlineInputBorder()),
              items: [
                for (final (tag, key) in placeTypes) DropdownMenuItem(value: tag, child: Text(s.placeTypeLabel(key))),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
          ] else ...[
            Text(s.whatsWrong, style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final problem in _Problem.values)
                  ChoiceChip(
                    label: Text(_problemLabel(problem)),
                    selected: _problem == problem,
                    onSelected: (_) => setState(() => _problem = problem),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _details,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: s.details,
              hintText: _adding ? s.detailsHintAdd : s.detailsHintEdit,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(s.publicNotice, style: text.bodySmall?.copyWith(color: Colors.black54)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(s.send),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }
}
