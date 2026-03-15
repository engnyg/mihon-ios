import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader(title: 'Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark mode'),
            value: _darkMode,
            onChanged: (v) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('dark_mode', v);
              setState(() => _darkMode = v);
            },
          ),
          const Divider(),
          _SectionHeader(title: 'Reader'),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Reading direction'),
            subtitle: Text(_readerMode == 'horizontal'
                ? 'Left to right'
                : _readerMode == 'rtl'
                    ? 'Right to left'
                    : 'Vertical scroll'),
            onTap: () => _showReaderModeDialog(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait_outlined),
            title: const Text('Keep screen on'),
            value: _keepScreenOn,
            onChanged: (v) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('keep_screen_on', v);
              setState(() => _keepScreenOn = v);
            },
          ),
          const Divider(),
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('0.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Based on Mihon'),
            subtitle: const Text('github.com/mihonapp/mihon'),
          ),
        ],
      ),
    );
  }

  void _showReaderModeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Reading direction'),
        children: [
          _RadioOption(
            label: 'Left to right',
            value: 'horizontal',
            groupValue: _readerMode,
            onChanged: _setReaderMode,
          ),
          _RadioOption(
            label: 'Right to left',
            value: 'rtl',
            groupValue: _readerMode,
            onChanged: _setReaderMode,
          ),
          _RadioOption(
            label: 'Vertical scroll',
            value: 'vertical',
            groupValue: _readerMode,
            onChanged: _setReaderMode,
          ),
        ],
      ),
    );
  }

  Future<void> _setReaderMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_mode', mode);
    setState(() => _readerMode = mode);
    if (mounted) Navigator.pop(context);
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
