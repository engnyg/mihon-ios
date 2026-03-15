import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/sources/source_registry.dart';
import '../../data/sources/base/manga_source.dart';
import '../router/app_router.dart';
import 'extensions_screen.dart';

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

class _SourcesTab extends StatelessWidget {
  const _SourcesTab();

  @override
  Widget build(BuildContext context) {
    final sources = SourceRegistry.instance.allSources;
    return ListView(
      children: [
        _SectionHeader(title: context.l10n.sources),
        ...sources.map((source) => _SourceTile(source: source)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});
  final MangaSource source;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          source.name[0].toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(source.name),
      subtitle: Text(source.lang.toUpperCase()),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('${Routes.browse}/source/${source.id}'),
    );
  }
}
