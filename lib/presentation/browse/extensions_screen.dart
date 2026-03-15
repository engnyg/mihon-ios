import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/extensions/default_extensions.dart';
import '../../data/extensions/tachi_ext_repository.dart';
import '../../data/sources/source_registry.dart';
import '../../data/sources/tachi_ext/tachi_ext_source.dart';
import '../../data/sources/tachi_ext/tachi_extension_def.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final tachiExtRepoProvider = Provider<TachiExtRepository>(
  (ref) => TachiExtRepository(),
);

/// Installed JSON extension defs — also keeps SourceRegistry in sync.
final tachiExtListProvider =
    StateNotifierProvider<_TachiExtNotifier, List<TachiExtDef>>(
  (ref) => _TachiExtNotifier(ref.watch(tachiExtRepoProvider)),
);

class _TachiExtNotifier extends StateNotifier<List<TachiExtDef>> {
  _TachiExtNotifier(this._repo) : super([]) {
    _load();
  }

  final TachiExtRepository _repo;

  Future<void> _load() async {
    final defs = await _repo.getInstalled();
    if (mounted) state = defs;
    // Register bundled default extensions first (installed version takes precedence)
    for (final def in kDefaultExtensions) {
      if (!SourceRegistry.instance.hasSource(def.id)) {
        SourceRegistry.instance.registerSource(TachiExtSource(def));
      }
    }
    // Register user-installed extensions (overrides defaults with same id)
    for (final def in defs) {
      SourceRegistry.instance.registerSource(TachiExtSource(def));
    }
  }

  Future<void> install(TachiExtDef def) async {
    await _repo.install(def);
    SourceRegistry.instance.registerSource(TachiExtSource(def));
    if (mounted) state = [...state.where((d) => d.id != def.id), def];
  }

  Future<TachiExtDef> installFromUrl(String url) async {
    final def = await _repo.installFromUrl(url);
    SourceRegistry.instance.registerSource(TachiExtSource(def));
    if (mounted) state = [...state.where((d) => d.id != def.id), def];
    return def;
  }

  Future<void> uninstall(String id) async {
    await _repo.uninstall(id);
    final existing = SourceRegistry.instance.getSource(id);
    if (existing is TachiExtSource) {
      SourceRegistry.instance.unregisterSource(id);
    }
    if (mounted) state = state.where((d) => d.id != id).toList();
  }
}

/// Tachi repo list — controls which repos appear in Browse.
final _tachiRepoListProvider =
    StateNotifierProvider<_TachiRepoListNotifier, List<TachiExtRepo>>(
  (ref) => _TachiRepoListNotifier(ref.watch(tachiExtRepoProvider)),
);

class _TachiRepoListNotifier extends StateNotifier<List<TachiExtRepo>> {
  _TachiRepoListNotifier(this._repo) : super([]) {
    _load();
  }

  final TachiExtRepository _repo;

  Future<void> _load() async {
    final repos = await _repo.getRepos();
    if (mounted) state = repos;
  }

  Future<void> add(String url, String name) async {
    await _repo.addRepo(url, name);
    await _load();
  }

  Future<void> remove(String url) async {
    await _repo.removeRepo(url);
    await _load();
  }
}

/// Extensions grouped by Tachi repo for the Browse tab.
final _tachiExtBrowseProvider =
    FutureProvider<List<TachiRepoExtensions>>((ref) async {
  final repo = ref.watch(tachiExtRepoProvider);
  ref.watch(_tachiRepoListProvider); // invalidate when repos change
  return repo.fetchGrouped();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ExtensionsScreen extends ConsumerStatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _query = '';
  String _selectedLang = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showManageRepos() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ManageReposSheet(),
    );
  }

  void _showJsonExtSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _JsonExtSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final browseAsync = ref.watch(_tachiExtBrowseProvider);
    final installed = ref.watch(tachiExtListProvider);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l10n.installed),
                  Tab(text: l10n.browse),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.data_object),
              tooltip: l10n.jsonExtensions,
              onPressed: _showJsonExtSheet,
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: l10n.manageRepos,
              onPressed: _showManageRepos,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.search,
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: browseAsync.when(
            loading: () => _buildContent(context, installed, []),
            error: (e, _) => Column(
              children: [
                _buildContent(context, installed, []),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l10n.failedToLoadExtensions,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            data: (groups) => _buildContent(context, installed, groups),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<TachiExtDef> installed,
    List<TachiRepoExtensions> browseGroups,
  ) {
    final installedIds = installed.map((d) => d.id).toSet();
    final q = _query;
    final selLang = _selectedLang;

    bool matchesDef(TachiExtDef d) {
      final langOk =
          selLang.isEmpty || d.lang.toLowerCase().startsWith(selLang);
      final textOk = q.isEmpty ||
          d.name.toLowerCase().contains(q) ||
          d.lang.toLowerCase().contains(q);
      return langOk && textOk;
    }

    // ── Language filter chips ──────────────────────────────────────────────
    final allLangs = <String>{};
    for (final d in installed) {
      allLangs.add(d.lang.toLowerCase());
    }
    for (final g in browseGroups) {
      for (final d in g.extensions) {
        allLangs.add(d.lang.toLowerCase());
      }
    }
    const priority = ['zh', 'en', 'ja', 'ko', 'fr', 'de', 'es', 'pt'];
    final sortedLangs = [
      ...priority.where(allLangs.contains),
      ...(allLangs
          .where((l) => !priority.contains(l) && l != 'all')
          .toList()
        ..sort()),
      if (allLangs.contains('all')) 'all',
    ];

    // ── Installed tab ──────────────────────────────────────────────────────
    final installedList = installed
        .where(matchesDef)
        .map((d) => _ExtItem(
              id: d.id,
              name: d.name,
              lang: d.lang,
              version: d.version,
              nsfw: d.nsfw,
              repoLabel: null,
              isNative: false,
              isInstalled: true,
            ))
        .toList();

    // ── Browse tab ─────────────────────────────────────────────────────────
    final browseRepoGroups = browseGroups
        .map((g) {
          final filtered = g.extensions.where(matchesDef).toList();
          return _TachiRepoGroup(repo: g.repo, extensions: filtered);
        })
        .where((g) => g.extensions.isNotEmpty)
        .toList();

    final onInstall = (TachiExtDef def) =>
        ref.read(tachiExtListProvider.notifier).install(def);
    final onUninstall =
        (String id) => ref.read(tachiExtListProvider.notifier).uninstall(id);

    return Column(
      children: [
        if (sortedLangs.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _LangChip(
                  label: context.l10n.filterAll,
                  selected: selLang.isEmpty,
                  onTap: () => setState(() => _selectedLang = ''),
                ),
                ...sortedLangs.map((lang) => _LangChip(
                      label: lang.toUpperCase(),
                      selected: selLang == lang,
                      onTap: () => setState(
                          () => _selectedLang = selLang == lang ? '' : lang),
                    )),
              ],
            ),
          ),
        const SizedBox(height: 2),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _InstalledList(
                items: installedList,
                onUninstall: onUninstall,
              ),
              _BrowseList(
                groups: browseRepoGroups,
                installedIds: installedIds,
                onInstall: onInstall,
                onUninstall: onUninstall,
              ),
            ],
          ),
        ),
      ],
    );
  }

}

// ── Language chip ──────────────────────────────────────────────────────────────

class _LangChip extends StatelessWidget {
  const _LangChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        selectedColor: cs.primaryContainer,
        checkmarkColor: cs.onPrimaryContainer,
        labelStyle: TextStyle(
          color: selected ? cs.onPrimaryContainer : null,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}

// ── Data helpers ───────────────────────────────────────────────────────────────

class _ExtItem {
  const _ExtItem({
    required this.id,
    required this.name,
    required this.lang,
    required this.version,
    required this.nsfw,
    required this.repoLabel,
    required this.isNative,
    required this.isInstalled,
  });
  final String id;
  final String name;
  final String lang;
  final String version;
  final bool nsfw;
  final String? repoLabel;
  final bool isNative;
  final bool isInstalled;
}

class _TachiRepoGroup {
  const _TachiRepoGroup({required this.repo, required this.extensions});
  final TachiExtRepo repo;
  final List<TachiExtDef> extensions;
}

// ── Installed Tab ──────────────────────────────────────────────────────────────

class _InstalledList extends StatelessWidget {
  const _InstalledList({
    required this.items,
    required this.onUninstall,
  });

  final List<_ExtItem> items;
  final void Function(String id) onUninstall;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(
          icon: Icons.extension_off, label: context.l10n.installed);
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return _Tile(
          name: item.name,
          lang: item.lang,
          version: item.version,
          nsfw: item.nsfw,
          repoLabel: item.repoLabel,
          isNative: item.isNative,
          isInstalled: item.isInstalled,
          onToggle: item.isNative ? null : () => onUninstall(item.id),
        );
      },
    );
  }
}

// ── Browse Tab ─────────────────────────────────────────────────────────────────

class _BrowseList extends StatelessWidget {
  const _BrowseList({
    required this.groups,
    required this.installedIds,
    required this.onInstall,
    required this.onUninstall,
  });

  final List<_TachiRepoGroup> groups;
  final Set<String> installedIds;
  final void Function(TachiExtDef) onInstall;
  final void Function(String) onUninstall;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _EmptyState(icon: Icons.cloud_off, label: context.l10n.browse);
    }
    final items = <Widget>[];
    for (final group in groups) {
      items.add(_SectionHeader(repo: group.repo, count: group.extensions.length));
      for (final def in group.extensions) {
        final installed = installedIds.contains(def.id);
        items.add(_Tile(
          name: def.name,
          lang: def.lang,
          version: def.version,
          nsfw: def.nsfw,
          repoLabel: group.repo.name,
          isNative: false,
          isInstalled: installed,
          onToggle: installed
              ? () => onUninstall(def.id)
              : () => onInstall(def),
        ));
      }
    }
    return ListView(children: items);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.repo, required this.count});
  final TachiExtRepo repo;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(Icons.extension,
              size: 16,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            repo.name,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Extension Tile ─────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  const _Tile({
    required this.name,
    required this.lang,
    required this.version,
    required this.nsfw,
    required this.repoLabel,
    required this.isNative,
    required this.isInstalled,
    required this.onToggle,
  });

  final String name;
  final String lang;
  final String version;
  final bool nsfw;
  final String? repoLabel;
  final bool isNative;
  final bool isInstalled;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: _Icon(name: name),
      title: Row(
        children: [
          Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          if (nsfw)
            _Chip(l10n.extensionsNsfw, cs.errorContainer, cs.onErrorContainer),
          if (isNative)
            _Chip(l10n.builtIn, cs.primaryContainer, cs.onPrimaryContainer),
        ],
      ),
      subtitle: Text(
        '${lang.toUpperCase()} · v$version',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: isNative
          ? null
          : OutlinedButton(
              onPressed: onToggle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                foregroundColor: isInstalled ? cs.error : cs.primary,
                side: BorderSide(color: isInstalled ? cs.error : cs.primary),
              ),
              child: Text(isInstalled ? l10n.uninstall : l10n.install),
            ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: cs.secondaryContainer,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: cs.onSecondaryContainer, fontWeight: FontWeight.bold)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 48,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── JSON Extension Install Sheet ───────────────────────────────────────────────

class _JsonExtSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_JsonExtSheet> createState() => _JsonExtSheetState();
}

class _JsonExtSheetState extends ConsumerState<_JsonExtSheet> {
  final _urlCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    final url = _urlCtrl.text.trim();
    final l10n = context.l10n;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _error = l10n.invalidJsonExtension);
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final repo = ref.read(tachiExtRepoProvider);
      // Try single-extension install first.
      // If the URL returns an array (repo index), fall back to adding as repo.
      try {
        final def = await repo.validateUrl(url);
        await ref.read(tachiExtListProvider.notifier).install(def);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.jsonExtInstalled),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (_) {
        // URL is an array (repo index) — add as repo instead.
        final count = await repo.validateRepoUrl(url);
        final name = Uri.parse(url).host;
        await ref.read(_tachiRepoListProvider.notifier).add(url, name);
        ref.invalidate(_tachiExtBrowseProvider);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${l10n.addRepository}: $count ${l10n.extensions}'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '${l10n.invalidJsonExtension}: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final jsonExts = ref.watch(tachiExtListProvider);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(l10n.jsonExtensions,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          if (jsonExts.isNotEmpty) ...[
            ...jsonExts.map((d) => ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.tertiaryContainer,
                    child: Text(
                      d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: cs.onTertiaryContainer,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(d.name),
                  subtitle: Text('${d.lang.toUpperCase()} · v${d.version}'),
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: cs.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () =>
                        ref.read(tachiExtListProvider.notifier).uninstall(d.id),
                    child: Text(l10n.uninstall),
                  ),
                )),
            const Divider(height: 24),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(l10n.addJsonExtension,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: l10n.jsonExtensionUrl,
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _error,
                errorMaxLines: 3,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _install(),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _install,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Manage Repos Sheet (Tachi JSON repos) ─────────────────────────────────────

class _ManageReposSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ManageReposSheet> createState() => _ManageReposSheetState();
}

class _ManageReposSheetState extends ConsumerState<_ManageReposSheet> {
  final _urlCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _urlError;
  bool _adding = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addRepo() async {
    final url = _urlCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final l10n = context.l10n;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _urlError = l10n.invalidRepositoryUrl);
      return;
    }
    setState(() {
      _urlError = null;
      _adding = true;
    });
    try {
      final repo = ref.read(tachiExtRepoProvider);
      final count = await repo.validateRepoUrl(url);
      await ref.read(_tachiRepoListProvider.notifier).add(
            url,
            name.isEmpty ? _hostFromUrl(url) : name,
          );
      ref.invalidate(_tachiExtBrowseProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${l10n.addRepository}: $count ${l10n.extensions}'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _urlError = '${l10n.invalidRepositoryUrl}: $e';
          _adding = false;
        });
      }
    }
  }

  String _hostFromUrl(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repos = ref.watch(_tachiRepoListProvider);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(l10n.manageRepos,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          if (repos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.repositoryUrl,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ...repos.map((repo) => ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.extension,
                      size: 16, color: cs.onPrimaryContainer),
                ),
                title: Text(repo.name),
                subtitle: Text(repo.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                trailing: TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: cs.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact),
                  onPressed: () async {
                    await ref
                        .read(_tachiRepoListProvider.notifier)
                        .remove(repo.url);
                    ref.invalidate(_tachiExtBrowseProvider);
                  },
                  child: Text(l10n.removeRepository),
                ),
              )),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(l10n.addRepository,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.repositoryName,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: l10n.repositoryUrl,
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _urlError,
                errorMaxLines: 3,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _addRepo(),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _adding ? null : _addRepo,
                child: _adding
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
