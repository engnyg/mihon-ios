import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/extensions/extension.dart';
import '../../data/extensions/extension_repository.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final _extensionRepoProvider = Provider<ExtensionRepository>(
  (ref) => ExtensionRepository(),
);

final _extensionListProvider =
    FutureProvider<List<Extension>>((ref) async {
  final repo = ref.watch(_extensionRepoProvider);
  return repo.fetchIndex();
});

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
    final prefs = await _repo.getInstalledSet();
    if (mounted) state = prefs;
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

// ── Screen ─────────────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listAsync = ref.watch(_extensionListProvider);
    final installed = ref.watch(_installedPkgsProvider);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.installed),
            Tab(text: l10n.browse),
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
                    onPressed: () => ref.invalidate(_extensionListProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
            data: (exts) {
              final nativePkgs = ExtensionRepository.nativePackages;

              // Built-in native sources shown as pseudo-extensions
              final nativeExts = nativePkgs.map((pkg) {
                final name = _pkgToName(pkg);
                return Extension(
                  name: name,
                  pkg: pkg,
                  apk: '',
                  lang: _pkgToLang(pkg),
                  code: 0,
                  version: 'built-in',
                  installed: true,
                );
              }).toList();

              final catalogExts = exts
                  .where((e) => !nativePkgs.contains(e.pkg))
                  .toList();

              List<Extension> filterList(List<Extension> list) {
                if (_query.isEmpty) return list;
                return list
                    .where((e) =>
                        e.name.toLowerCase().contains(_query) ||
                        e.lang.toLowerCase().contains(_query))
                    .toList();
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  // ── Installed tab ──────────────────────────────────────────
                  _ExtensionList(
                    extensions: filterList([
                      ...nativeExts,
                      ...catalogExts.where((e) => installed.contains(e.pkg)),
                    ]),
                    installed: installed,
                    nativePkgs: nativePkgs,
                    onToggle: (pkg) =>
                        ref.read(_installedPkgsProvider.notifier).toggle(pkg),
                  ),
                  // ── Browse tab ─────────────────────────────────────────────
                  _ExtensionList(
                    extensions: filterList(catalogExts),
                    installed: installed,
                    nativePkgs: nativePkgs,
                    onToggle: (pkg) =>
                        ref.read(_installedPkgsProvider.notifier).toggle(pkg),
                  ),
                ],
              );
            },
          ),
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
    // e.g. eu.kanade.tachiyomi.extension.en.mangadex → 'en'
    // e.g. eu.kanade.tachiyomi.extension.all.mangadex → 'all'
    if (parts.length >= 6) return parts[parts.length - 2];
    return 'en';
  }
}

// ── Extension List Widget ──────────────────────────────────────────────────────

class _ExtensionList extends StatelessWidget {
  const _ExtensionList({
    required this.extensions,
    required this.installed,
    required this.nativePkgs,
    required this.onToggle,
  });

  final List<Extension> extensions;
  final Set<String> installed;
  final Set<String> nativePkgs;
  final void Function(String pkg) onToggle;

  @override
  Widget build(BuildContext context) {
    if (extensions.isEmpty) {
      return Center(
        child: Text(
          context.l10n.emptyLibrary,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      itemCount: extensions.length,
      itemBuilder: (context, i) => _ExtensionTile(
        extension: extensions[i],
        isInstalled: installed.contains(extensions[i].pkg) ||
            extensions[i].installed,
        isNative: nativePkgs.contains(extensions[i].pkg),
        onToggle: () => onToggle(extensions[i].pkg),
      ),
    );
  }
}

// ── Extension Tile Widget ──────────────────────────────────────────────────────

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({
    required this.extension,
    required this.isInstalled,
    required this.isNative,
    required this.onToggle,
  });

  final Extension extension;
  final bool isInstalled;
  final bool isNative;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: _ExtensionIcon(name: extension.name, lang: extension.lang),
      title: Row(
        children: [
          Flexible(child: Text(extension.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          if (extension.nsfw != 0)
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
        ],
      ),
      subtitle: Text(
        '${extension.lang.toUpperCase()} · v${extension.version}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: isNative
          ? null
          : OutlinedButton(
              onPressed: onToggle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                foregroundColor: isInstalled
                    ? colorScheme.error
                    : colorScheme.primary,
                side: BorderSide(
                  color: isInstalled
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
              ),
              child: Text(isInstalled ? l10n.uninstall : l10n.install),
            ),
    );
  }
}

class _ExtensionIcon extends StatelessWidget {
  const _ExtensionIcon({required this.name, required this.lang});
  final String name;
  final String lang;

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
