import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  String _readerMode = 'horizontal';
  bool _keepScreenOn = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _readerMode = prefs.getString('reader_mode') ?? 'horizontal';
      _keepScreenOn = prefs.getBool('keep_screen_on') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // ── Appearance ──────────────────────────────────────────────────
          _SectionHeader(title: l10n.appearance),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.darkMode),
            value: _darkMode,
            onChanged: (v) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('dark_mode', v);
              setState(() => _darkMode = v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(_localeName(currentLocale, l10n)),
            onTap: () => _showLanguageDialog(context, currentLocale, l10n),
          ),
          const Divider(),

          // ── Reader ───────────────────────────────────────────────────────
          _SectionHeader(title: l10n.readerSection),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.readingDirection),
            subtitle: Text(_readerModeLabel(_readerMode, l10n)),
            onTap: () => _showReaderModeDialog(l10n),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait_outlined),
            title: Text(l10n.keepScreenOn),
            value: _keepScreenOn,
            onChanged: (v) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('keep_screen_on', v);
              setState(() => _keepScreenOn = v);
            },
          ),
          const Divider(),

          // ── About ────────────────────────────────────────────────────────
          _SectionHeader(title: l10n.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
            subtitle: const Text('0.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.basedOnMihon),
            subtitle: const Text('github.com/mihonapp/mihon'),
          ),
        ],
      ),
    );
  }

  String _localeName(Locale locale, AppStrings l10n) {
    if (locale.languageCode == 'zh') return l10n.langTraditionalChinese;
    return l10n.langEnglish;
  }

  String _readerModeLabel(String mode, AppStrings l10n) {
    switch (mode) {
      case 'rtl':
        return l10n.rightToLeft;
      case 'vertical':
        return l10n.verticalScroll;
      default:
        return l10n.leftToRight;
    }
  }

  void _showLanguageDialog(
      BuildContext context, Locale current, AppStrings l10n) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          _LangOption(
            label: l10n.langEnglish,
            locale: const Locale('en'),
            current: current,
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('en'));
              Navigator.pop(ctx);
            },
          ),
          _LangOption(
            label: l10n.langTraditionalChinese,
            locale: const Locale('zh'),
            current: current,
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('zh'));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showReaderModeDialog(AppStrings l10n) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.readingDirection),
        children: [
          _RadioOption(
            label: l10n.leftToRight,
            value: 'horizontal',
            groupValue: _readerMode,
            onChanged: (v) => _setReaderMode(v, ctx),
          ),
          _RadioOption(
            label: l10n.rightToLeft,
            value: 'rtl',
            groupValue: _readerMode,
            onChanged: (v) => _setReaderMode(v, ctx),
          ),
          _RadioOption(
            label: l10n.verticalScroll,
            value: 'vertical',
            groupValue: _readerMode,
            onChanged: (v) => _setReaderMode(v, ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _setReaderMode(String mode, BuildContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_mode', mode);
    setState(() => _readerMode = mode);
    if (ctx.mounted) Navigator.pop(ctx);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.locale,
    required this.current,
    required this.onTap,
  });

  final String label;
  final Locale locale;
  final Locale current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = locale.languageCode == current.languageCode;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _RadioOption extends StatelessWidget {
  const _RadioOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String groupValue;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
