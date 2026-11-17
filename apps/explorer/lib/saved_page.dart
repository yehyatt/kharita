import 'package:flutter/material.dart';

import 'app_state.dart';
import 'main.dart';
import 'strings.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key, required this.state, required this.onOpen});
  final AppState state;
  final void Function(SavedPlace) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = S(state.language);
        return Scaffold(
          appBar: AppBar(title: Text(s.saved)),
          body: state.saved.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bookmark_border, size: 56, color: Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          s.nothingSaved,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: state.saved.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) {
                    final p = state.saved[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: brand.withValues(alpha: 0.1),
                        child: const Icon(Icons.bookmark, color: brand),
                      ),
                      title: Text(p.name),
                      subtitle: Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => state.toggleSaved(p),
                      ),
                      onTap: () => onOpen(p),
                    );
                  },
                ),
        );
      },
    );
  }
}
