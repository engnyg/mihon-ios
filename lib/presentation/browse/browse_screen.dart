import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/sources/source_registry.dart';
import '../../data/sources/base/manga_source.dart';
import '../router/app_router.dart';
import 'extensions_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.browse),
          bottom: TabBar(
            tabs: [
              Tab(text: context.l10n.sources),
              Tab(text: context.l10n.extensions),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SourcesTab(),
            ExtensionsScreen(),
          ],
        ),
      ),
    );
  }
}

// ── Sources tab ───────────────────────────────────────────────────────────────

class _SourcesTab extends ConsumerWidget {
  const _SourcesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tachiExtListProvider);

    final sources = SourceRegistry.instance.allSources;

    if (sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension_off,
                size: 48,
                color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              context.l10n.emptyLibrarySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: sources.map((s) => _SourceTile(source: s)).toList(),
    );
  }
}

// ── Source tile ───────────────────────────────────────────────────────────────

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});
  final MangaSource source;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Text(
          source.name[0].toUpperCase(),
          style: TextStyle(
              color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(source.name),
      subtitle: Text(source.lang.toUpperCase()),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('${Routes.browse}/source/${source.id}'),
    );
  }
}
