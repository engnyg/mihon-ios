import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/sources/source_registry.dart';
import '../../data/sources/base/manga_source.dart';
import '../../data/sources/stub_source.dart';
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

/// Sources tab — shows native sources + installed extension sources.
/// Rebuilds whenever the installed extensions set changes.
class _SourcesTab extends ConsumerWidget {
  const _SourcesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch installed pkgs so we rebuild when extensions are installed/uninstalled
    ref.watch(installedPkgsProvider);

    final allSources = SourceRegistry.instance.allSources;
    final nativeSources =
        allSources.where((s) => s is! StubSource).toList();
    final stubSources =
        allSources.whereType<StubSource>().toList();

    final l10n = context.l10n;

    return ListView(
      children: [
        _SectionHeader(title: l10n.builtIn),
        ...nativeSources.map((s) => _SourceTile(source: s, isStub: false)),
        if (stubSources.isNotEmpty) ...[
          _SectionHeader(title: l10n.installed),
          ...stubSources.map((s) => _SourceTile(source: s, isStub: true)),
        ],
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
  const _SourceTile({required this.source, required this.isStub});
  final MangaSource source;
  final bool isStub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isStub ? cs.secondaryContainer : cs.primaryContainer,
        child: Text(
          source.name[0].toUpperCase(),
          style: TextStyle(
            color: isStub ? cs.onSecondaryContainer : cs.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(source.name),
      subtitle: Text(source.lang.toUpperCase()),
      trailing: isStub
          ? Icon(Icons.warning_amber_rounded,
              size: 18, color: cs.onSurfaceVariant)
          : const Icon(Icons.chevron_right),
      onTap: () {
        if (isStub) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              '"${source.name}" ${context.l10n.notNativelySupported}',
            ),
            behavior: SnackBarBehavior.floating,
          ));
        } else {
          context.push('${Routes.browse}/source/${source.id}');
        }
      },
    );
  }
}
