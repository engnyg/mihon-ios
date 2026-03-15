import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/extensions/extension.dart';
import '../../data/extensions/extension_repository.dart';

// ── Providers ───────────────────────────────────────────────────────────────────

final _extensionRepoProvider = Provider<ExtensionRepository>(
  (ref) => ExtensionRepository(),
);

/// All extensions from all repos (default + custom).
final extensionListProvider =
    FutureProvider<List<ExtensionEntry>>((ref) async {
  final repo = ref.watch(_extensionRepoProvider);
  // Depend on repo list changes so we re-fetch when repos change.
  ref.watch(_repoListProvider);
  return repo.fetchAllExtensions();
});

/// List of repos (default + custom).
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

/// Installed package set, persisted in SharedPreferences.
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
      state = {...state}..remove(pkg);
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

  // ── Manage repos sheet ──────────────────────────────────────────────────────

  void _showManageRepos(BuildContext context) {
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
        // ── Tab bar + manage repos button ──────────────────────────────────
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
              onPressed: () => _showManageRepos(context),
            ),
          ],
        ),
        // ── Search bar ────────────────────────────────────────────────────
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
        // ── Extension list ────────────────────────────────────────────────
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
            data: (entries) => _buildTabs(context, entries, installed),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(
    BuildContext context,
    List<ExtensionEntry> entries,
    Set<String> installed,
  ) {
    final nativePkgs = ExtensionRepository.nativePackages;

    // Built-in native sources as pseudo-extension entries
    final nativeEntries = nativePkgs.map((pkg) {
      final ext = Extension(
        name: _pkgToName(pkg),
        pkg: pkg,
        apk: '',
        lang: _pkgToLang(pkg),
        code: 0,
        version: 'built-in',
        installed: true,
      );
      return ExtensionEntry(
        extension: ext,
        repo: ExtensionRepository.defaultRepo,
      );
    }).toList();

    final catalogEntries =
        entries.where((e) => !nativePkgs.contains(e.extension.pkg)).toList();

    List<ExtensionEntry> filter(List<ExtensionEntry> list) {
      if (_query.isEmpty) return list;
      return list
          .where((e) =>
              e.extension.name.toLowerCase().contains(_query) ||
              e.extension.lang.toLowerCase().contains(_query) ||
              e.repo.name.toLowerCase().contains(_query))
          .toList();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // ── Installed tab ──────────────────────────────────────────────────
        _ExtensionList(
          entries: filter([
            ...nativeEntries,
            ...catalogEntries.where((e) => installed.contains(e.extension.pkg)),
          ]),
          installed: installed,
          nativePkgs: nativePkgs,
          onToggle: (pkg) =>
              ref.read(_installedPkgsProvider.notifier).toggle(pkg),
        ),
        // ── Browse tab ─────────────────────────────────────────────────────
        _ExtensionList(
          entries: filter(catalogEntries),
          installed: installed,
          nativePkgs: nativePkgs,
          onToggle: (pkg) =>
              ref.read(_installedPkgsProvider.notifier).toggle(pkg),
        ),
      ],
    );
  }

  String _pkgToName(String pkg) {
    final parts = pkg.split('.');
    final raw = parts.last;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String _pkgToLang(String pkg) {
    final parts = pkg.split('.');
    if (parts.length >= 6) return parts[parts.length - 2];
    return 'en';
  }
}

// ── Manage Repositories Sheet ───────────────────────────────────────────────────

class _ManageReposSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ManageReposSheet> createState() => _ManageReposSheetState();
}

class _ManageReposSheetState extends ConsumerState<_ManageReposSheet> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  String? _urlError;
  bool _adding = false;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addRepo() async {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();
    final l10n = context.l10n;

    if (url.isEmpty || !url.startsWith('http')) {
      setState(() => _urlError = l10n.invalidRepositoryUrl);
      return;
    }
    setState(() {
      _urlError = null;
      _adding = true;
    });
    await ref.read(_repoListProvider.notifier).add(url, name.isEmpty ? url : name);
    ref.invalidate(extensionListProvider);
    if (mounted) {
      setState(() => _adding = false);
      _urlController.clear();
      _nameController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repos = ref.watch(_repoListProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              l10n.manageRepos,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // ── Existing repos ───────────────────────────────────────────────
          ...repos.map((repo) => ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: repo.isDefault
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    repo.isDefault ? Icons.star : Icons.extension,
                    size: 16,
                    color: repo.isDefault
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSecondaryContainer,
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
                    ? _Badge(
                        label: l10n.defaultRepo,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        textColor:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      )
                    : TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.error,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
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
          // ── Add new repo form ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              l10n.addRepository,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameController,
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
              controller: _urlController,
              decoration: InputDecoration(
                labelText: l10n.repositoryUrl,
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _urlError,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _addRepo(),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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

// ── Extension List Widget ────────────────────────────────────────────────────────

class _ExtensionList extends StatelessWidget {
  const _ExtensionList({
    required this.entries,
    required this.installed,
    required this.nativePkgs,
    required this.onToggle,
  });

  final List<ExtensionEntry> entries;
  final Set<String> installed;
  final Set<String> nativePkgs;
  final void Function(String pkg) onToggle;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension_off,
                size: 48,
                color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              context.l10n.installed,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) => _ExtensionTile(
        entry: entries[i],
        isInstalled:
            installed.contains(entries[i].extension.pkg) ||
            entries[i].extension.installed,
        isNative: nativePkgs.contains(entries[i].extension.pkg),
        onToggle: () => onToggle(entries[i].extension.pkg),
      ),
    );
  }
}

// ── Extension Tile Widget ────────────────────────────────────────────────────────

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({
    required this.entry,
    required this.isInstalled,
    required this.isNative,
    required this.onToggle,
  });

  final ExtensionEntry entry;
  final bool isInstalled;
  final bool isNative;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ext = entry.extension;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: _ExtensionIcon(name: ext.name),
      title: Row(
        children: [
          Flexible(child: Text(ext.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          if (ext.nsfw != 0)
            _Badge(
              label: l10n.extensionsNsfw,
              color: colorScheme.errorContainer,
              textColor: colorScheme.onErrorContainer,
            ),
          if (isNative)
            _Badge(
              label: l10n.builtIn,
              color: colorScheme.primaryContainer,
              textColor: colorScheme.onPrimaryContainer,
            ),
          if (!entry.repo.isDefault && !isNative)
            _Badge(
              label: entry.repo.name,
              color: colorScheme.tertiaryContainer,
              textColor: colorScheme.onTertiaryContainer,
            ),
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
                foregroundColor:
                    isInstalled ? colorScheme.error : colorScheme.primary,
                side: BorderSide(
                  color: isInstalled ? colorScheme.error : colorScheme.primary,
                ),
              ),
              child: Text(isInstalled ? l10n.uninstall : l10n.install),
            ),
    );
  }
}

class _ExtensionIcon extends StatelessWidget {
  const _ExtensionIcon({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: colorScheme.secondaryContainer,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
