import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/extensions/extension.dart';
import '../../data/extensions/extension_repository.dart';

// ── Providers ───────────────────────────────────────────────────────────────────

final _extensionRepoProvider = Provider<ExtensionRepository>(
  (ref) => ExtensionRepository(),
);

/// Extensions grouped by repo. Rebuilds whenever _repoListProvider changes.
final extensionListProvider =
    FutureProvider<List<RepoExtensions>>((ref) async {
  final repo = ref.watch(_extensionRepoProvider);
  ref.watch(_repoListProvider); // invalidate when repos change
  return repo.fetchGrouped();
});

/// List of repos (default + custom). Persisted in SharedPreferences.
final _repoListProvider =
    StateNotifierProvider<_RepoListNotifier, List<ExtensionRepo>>(
  (ref) => _RepoListNotifier(ref.watch(_extensionRepoProvider)),
);

class _RepoListNotifier extends StateNotifier<List<ExtensionRepo>> {
  _RepoListNotifier(this._repo) : super([ExtensionRepository.defaultRepo]) {
    _load();
  }

  final ExtensionRepository _repo;

  Future<void> _load() async {
    final repos = await _repo.getRepos();
    if (mounted) state = repos;
  }

  Future<void> add(String url, String name) async {
    await _repo.addCustomRepo(url, name);
    await _load();
  }

  Future<void> remove(String url) async {
    await _repo.removeCustomRepo(url);
    await _load();
  }
}

/// Installed package IDs.
final _installedPkgsProvider =
    StateNotifierProvider<_InstalledNotifier, Set<String>>(
  (ref) => _InstalledNotifier(ref.watch(_extensionRepoProvider)),
);

class _InstalledNotifier extends StateNotifier<Set<String>> {
  _InstalledNotifier(this._repo) : super({}) {
    _load();
  }

  final ExtensionRepository _repo;

  Future<void> _load() async {
    final s = await _repo.getInstalledSet();
    if (mounted) state = s;
  }

  Future<void> toggle(String pkg) async {
    if (state.contains(pkg)) {
      await _repo.uninstall(pkg);
      state = Set.from(state)..remove(pkg);
    } else {
      await _repo.install(pkg);
      state = {...state, pkg};
    }
  }
}

// ── Screen ──────────────────────────────────────────────────────────────────────

class ExtensionsScreen extends ConsumerStatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _query = '';

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listAsync = ref.watch(extensionListProvider);
    final installed = ref.watch(_installedPkgsProvider);

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
          child: listAsync.when(
            loading: () => Center(child: Text(l10n.loadingExtensions)),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.failedToLoadExtensions),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(extensionListProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
            data: (groups) => _buildTabs(context, groups, installed),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(
    BuildContext context,
    List<RepoExtensions> groups,
    Set<String> installed,
  ) {
    final nativePkgs = ExtensionRepository.nativePackages;
    final q = _query;

    bool matchesQuery(Extension e) {
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.lang.toLowerCase().contains(q);
    }

    // ── Installed tab: native built-ins + user-installed entries ──────────────
    final nativeItems = nativePkgs.map((pkg) => _ExtItem(
          ext: Extension(
            name: _pkgToName(pkg),
            pkg: pkg,
            apk: '',
            lang: _pkgToLang(pkg),
            code: 0,
            version: 'built-in',
            installed: true,
          ),
          repoName: null,
          isNative: true,
        ));

    final installedItems = groups
        .expand((g) => g.extensions.where((e) =>
            !nativePkgs.contains(e.pkg) &&
            installed.contains(e.pkg) &&
            matchesQuery(e)))
        .map((e) => _ExtItem(ext: e, repoName: null, isNative: false));

    final installedFiltered = [
      ...nativeItems.where((i) => matchesQuery(i.ext)),
      ...installedItems,
    ];

    // ── Browse tab: all repos, grouped by repo ────────────────────────────────
    final browseGroups = groups.map((g) {
      final filtered = g.extensions
          .where((e) => !nativePkgs.contains(e.pkg) && matchesQuery(e))
          .toList();
      return _RepoGroup(repo: g.repo, extensions: filtered);
    }).where((g) => g.extensions.isNotEmpty).toList();

    return TabBarView(
      controller: _tabController,
      children: [
        _InstalledList(
          items: installedFiltered,
          installed: installed,
          onToggle: (pkg) =>
              ref.read(_installedPkgsProvider.notifier).toggle(pkg),
        ),
        _BrowseList(
          groups: browseGroups,
          installed: installed,
          onToggle: (pkg) =>
              ref.read(_installedPkgsProvider.notifier).toggle(pkg),
        ),
      ],
    );
  }

  String _pkgToName(String pkg) {
    final raw = pkg.split('.').last;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String _pkgToLang(String pkg) {
    final parts = pkg.split('.');
    return parts.length >= 6 ? parts[parts.length - 2] : 'en';
  }
}

// ── Data helpers ─────────────────────────────────────────────────────────────────

class _ExtItem {
  const _ExtItem(
      {required this.ext, required this.repoName, required this.isNative});
  final Extension ext;
  final String? repoName;
  final bool isNative;
}

class _RepoGroup {
  const _RepoGroup({required this.repo, required this.extensions});
  final ExtensionRepo repo;
  final List<Extension> extensions;
}

// ── Installed Tab ────────────────────────────────────────────────────────────────

class _InstalledList extends StatelessWidget {
  const _InstalledList(
      {required this.items,
      required this.installed,
      required this.onToggle});

  final List<_ExtItem> items;
  final Set<String> installed;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(icon: Icons.extension_off, label: context.l10n.installed);
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) => _Tile(
        ext: items[i].ext,
        repoName: items[i].repoName,
        isInstalled: installed.contains(items[i].ext.pkg) || items[i].ext.installed,
        isNative: items[i].isNative,
        onToggle: () => onToggle(items[i].ext.pkg),
      ),
    );
  }
}

// ── Browse Tab (grouped) ─────────────────────────────────────────────────────────

class _BrowseList extends StatelessWidget {
  const _BrowseList(
      {required this.groups,
      required this.installed,
      required this.onToggle});

  final List<_RepoGroup> groups;
  final Set<String> installed;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _EmptyState(icon: Icons.cloud_off, label: context.l10n.browse);
    }

    // Build a flat list with section headers
    final items = <Widget>[];
    for (final group in groups) {
      items.add(_SectionHeader(
        repo: group.repo,
        count: group.extensions.length,
      ));
      for (final ext in group.extensions) {
        items.add(_Tile(
          ext: ext,
          repoName: group.repo.isDefault ? null : group.repo.name,
          isInstalled: installed.contains(ext.pkg) || ext.installed,
          isNative: ExtensionRepository.nativePackages.contains(ext.pkg),
          onToggle: () => onToggle(ext.pkg),
        ));
      }
    }

    return ListView(children: items);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.repo, required this.count});
  final ExtensionRepo repo;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(
            repo.isDefault ? Icons.star_rounded : Icons.extension,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            repo.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Extension Tile ───────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  const _Tile({
    required this.ext,
    required this.repoName,
    required this.isInstalled,
    required this.isNative,
    required this.onToggle,
  });

  final Extension ext;
  final String? repoName;
  final bool isInstalled;
  final bool isNative;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: _Icon(name: ext.name),
      title: Row(
        children: [
          Flexible(child: Text(ext.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          if (ext.nsfw != 0)
            _Chip(ext.nsfw != 0 ? l10n.extensionsNsfw : '',
                cs.errorContainer, cs.onErrorContainer),
          if (isNative)
            _Chip(l10n.builtIn, cs.primaryContainer, cs.onPrimaryContainer),
          if (repoName != null)
            _Chip(repoName!, cs.tertiaryContainer, cs.onTertiaryContainer),
        ],
      ),
      subtitle: Text(
        '${ext.lang.toUpperCase()} · v${ext.version}',
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
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
            color: cs.onSecondaryContainer, fontWeight: FontWeight.bold),
      ),
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
    if (label.isEmpty) return const SizedBox.shrink();
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

// ── Manage Repos Sheet ────────────────────────────────────────────────────────────

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

    if (url.isEmpty ||
        (!url.startsWith('http://') && !url.startsWith('https://'))) {
      setState(() => _urlError = l10n.invalidRepositoryUrl);
      return;
    }
    setState(() {
      _urlError = null;
      _adding = true;
    });

    try {
      final repo = ref.read(_extensionRepoProvider);
      // Validate URL first
      final count = await repo.validateRepoUrl(url);
      await ref
          .read(_repoListProvider.notifier)
          .add(url, name.isEmpty ? _nameFromUrl(url) : name);
      ref.invalidate(extensionListProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.addRepository}: $count ${l10n.extensions}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  String _nameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repos = ref.watch(_repoListProvider);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          // Existing repos
          ...repos.map((repo) => ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: repo.isDefault
                      ? cs.primaryContainer
                      : cs.secondaryContainer,
                  child: Icon(
                    repo.isDefault ? Icons.star_rounded : Icons.extension,
                    size: 16,
                    color: repo.isDefault
                        ? cs.onPrimaryContainer
                        : cs.onSecondaryContainer,
                  ),
                ),
                title: Text(repo.name),
                subtitle: Text(
                  repo.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: repo.isDefault
                    ? _Chip(l10n.defaultRepo, cs.primaryContainer,
                        cs.onPrimaryContainer)
                    : TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: cs.error,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          await ref
                              .read(_repoListProvider.notifier)
                              .remove(repo.url);
                          ref.invalidate(extensionListProvider);
                        },
                        child: Text(l10n.removeRepository),
                      ),
              )),
          const Divider(height: 24),
          // Add new repo form
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
                hintText: '(${l10n.defaultRepo}: URL host)',
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
