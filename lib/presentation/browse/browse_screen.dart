import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/sources/source_registry.dart';
import '../../data/sources/base/manga_source.dart';
import '../../data/sources/stub_source.dart';
import '../router/app_router.dart';
import 'extensions_screen.dart';

// ── Group key mapping ─────────────────────────────────────────────────────────

/// Sources that share the same extension are grouped under one tile.
/// Returns the display group name for a source.
String _groupKey(MangaSource s) {
  switch (s.id) {
    case 'webtoons':
    case 'webtoons_zh':
      return 'LINE Webtoons';
    default:
      return s.id;
  }
}

class _SourceGroup {
  const _SourceGroup({required this.name, required this.sources});
  final String name;
  final List<MangaSource> sources;
}

List<_SourceGroup> _buildGroups(List<MangaSource> sources) {
  final map = <String, List<MangaSource>>{};
  for (final s in sources) {
    (map[_groupKey(s)] ??= []).add(s);
  }
  return map.entries
      .map((e) => _SourceGroup(name: e.key, sources: e.value))
      .toList();
}

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
    ref.watch(installedPkgsProvider);

    final allSources = SourceRegistry.instance.allSources;
    final nativeSources = allSources.where((s) => s is! StubSource).toList();
    final stubSources = allSources.whereType<StubSource>().toList();

    final groups = _buildGroups(nativeSources);
    final l10n = context.l10n;

    return ListView(
      children: [
        _SectionHeader(title: l10n.builtIn),
        for (final g in groups)
          if (g.sources.length == 1)
            _SourceTile(source: g.sources.first, isStub: false)
          else
            _GroupedTile(group: g),
        if (stubSources.isNotEmpty) ...[
          _SectionHeader(title: l10n.installed),
          ...stubSources.map((s) => _SourceTile(source: s, isStub: true)),
        ],
      ],
    );
  }
}

// ── Single source tile ────────────────────────────────────────────────────────

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
                '"${source.name}" ${context.l10n.notNativelySupported}'),
            behavior: SnackBarBehavior.floating,
          ));
        } else {
          context.push('${Routes.browse}/source/${source.id}');
        }
      },
    );
  }
}

// ── Grouped source tile (multiple sub-sources / languages) ────────────────────

class _GroupedTile extends StatelessWidget {
  const _GroupedTile({required this.group});
  final _SourceGroup group;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final langs = group.sources.map((s) => s.lang.toUpperCase()).join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Text(
          group.name[0].toUpperCase(),
          style: TextStyle(
              color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(group.name),
      subtitle: Text(langs),
      trailing: const Icon(Icons.language),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SourcePickerSheet(group: group),
    );
  }
}

// ── Language picker bottom sheet ──────────────────────────────────────────────

class _SourcePickerSheet extends StatelessWidget {
  const _SourcePickerSheet({required this.group});
  final _SourceGroup group;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              group.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          for (final source in group.sources)
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  source.lang.toUpperCase().substring(0, 2),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(source.name),
              subtitle: Text(source.lang.toUpperCase()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.push('${Routes.browse}/source/${source.id}');
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

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
