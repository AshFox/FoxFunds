import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:foxfunds/services/settings_service.dart';
import 'package:foxfunds/services/export_service.dart';
import 'package:foxfunds/services/database_service.dart';
import 'package:foxfunds/screens/manage_categories_screen.dart';
import 'dart:io' show File; // added for reading file bytes when FilePicker returns path only
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';



class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final iconColor = isDestructive ? Colors.red : accent; // use full accent
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: iconColor) : null),
        onTap: onTap,
      ),
    );
  }
  bool _customAccentMode = false;
  String _appVersion = ''; // restored after refactor

  Future<Color?> _pickCustomAccentColor() async {
    Color tempColor = SettingsService.instance.accentColor;
    Color? selected;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick Custom Accent Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (c) => tempColor = c,
              enableAlpha: false,
              displayThumbColor: true,
              pickerAreaHeightPercent: 0.8,
              showLabel: true,
              labelTypes: const [
                ColorLabelType.rgb,
                ColorLabelType.hsv,
                ColorLabelType.hsl,
              ],
              hexInputBar: true,
              paletteType: PaletteType.hsv,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                selected = tempColor;
                Navigator.of(context).pop();
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
    return selected;
  }
  final List<String> _currencies = ['LYD', 'USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'];
  final List<String> _languages = ['English', 'العربية', 'Français', 'Español', 'Deutsch'];
  final List<Color> _accentColors = [
    Color(0xFF1565C0), // Main blue
    Color(0xFFF44336), // Coral
    Color(0xFF43A047), // Green
    Color(0xFFFFC107), // Amber
    Color(0xFF9C27B0), // Purple
    Color(0xFF008B8B), // Teal
    Color(0xFFFFC0CB), // Pink

  ];

  final Map<String, String> _currencyFormats = {
    'standard': 'Standard (1,234.56)',
    'no_decimal': 'No Decimal (1,234)',
    'compact': 'Compact (1.2K)',
  };

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadSettings();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  Future<void> _loadSettings() async {
    await SettingsService.instance.initialize();
    setState(() {
      _customAccentMode = !_accentColors.contains(SettingsService.instance.accentColor);
    });
  }

  String _getCurrencyDisplayText() {
    final Map<String, String> currencySymbols = {
      'LYD': 'LYD',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CAD': 'C\$',
      'AUD': 'A\$',
      'CUSTOM': SettingsService.instance.customCurrencySymbol.isEmpty
          ? 'Custom'
          : SettingsService.instance.customCurrencySymbol,
    };
    final currency = SettingsService.instance.currency;
    final symbol = currencySymbols[currency] ?? currency;
    return '$currency ($symbol)';
  }

  @override
  Widget build(BuildContext context) {
    final currentFormatLabel = _currencyFormats[SettingsService.instance.currencyFormat] ?? 'Standard (1,234.56)';
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final settings = SettingsService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Accent color picker is now only under Appearance section

          _buildSectionHeader('Currency'),
          _buildSettingTile(
            title: 'Currency',
            subtitle: _getCurrencyDisplayText(),
            icon: Icons.attach_money,
            onTap: _showCurrencyDialog,
          ),
          _buildSettingTile(
            title: 'Custom Currency Symbol',
            subtitle: SettingsService.instance.customCurrencySymbol.isEmpty
                ? 'Not set'
                : 'Current: ${SettingsService.instance.customCurrencySymbol}',
            icon: Icons.edit,
            onTap: () async {
              final controller = TextEditingController(text: SettingsService.instance.customCurrencySymbol);
              final res = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Set Custom Currency Symbol'),
                  content: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Symbol',
                      hintText: 'e.g. د.ل, \$, ₿',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    maxLength: 4,
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
                  ],
                ),
              );
              if (res != null) {
                await SettingsService.instance.saveSettings(customCurrencySymbol: res);
                if (mounted) setState(() {});
              }
            },
          ),
          _buildSettingTile(
            title: 'Currency Format',
            subtitle: currentFormatLabel,
            icon: Icons.format_list_numbered,
            onTap: _showCurrencyFormatDialog,
          ),

          _buildSectionHeader('Language'),
          _buildSettingTile(
            title: 'Language',
            subtitle: SettingsService.instance.language,
            icon: Icons.language,
            onTap: _showLanguageDialog,
          ),

          _buildSectionHeader('Appearance'),
          _buildSwitchTile(
            title: 'Dark Mode',
            subtitle: 'Enable dark theme',
            icon: Icons.dark_mode,
            value: SettingsService.instance.isDarkMode,
            onChanged: (val) {
              SettingsService.instance.saveSettings(isDarkMode: val);
              setState(() {}); // rebuild to reflect toggle immediately
            },
          ),
          _buildSettingTile(
            title: 'Accent Color',
            subtitle: 'Customize app accent color',
            icon: Icons.color_lens,
            trailing: CircleAvatar(
              backgroundColor: SettingsService.instance.accentColor,
              radius: 14,
              child: _customAccentMode ? const Icon(Icons.palette, color: Colors.white, size: 16) : null,
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Accent Color'),
                  content: SizedBox(
                    width: 280,
                    child: GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        ...List.generate(_accentColors.length, (index) {
                          final color = _accentColors[index];
                          final isSelected = color.value == SettingsService.instance.accentColor.value && !_customAccentMode;
                          return GestureDetector(
                            onTap: () async {
                              setState(() { _customAccentMode = false; });
                              await SettingsService.instance.saveSettings(accentColor: color);
                              if (mounted) Navigator.pop(context);
                            },
                            child: CircleAvatar(
                              backgroundColor: color,
                              radius: 20,
                              child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: () async {
                            final pickedColor = await _pickCustomAccentColor();
                            if (pickedColor != null) {
                              setState(() { _customAccentMode = true; });
                              await SettingsService.instance.saveSettings(accentColor: pickedColor);
                              if (mounted) Navigator.pop(context);
                            }
                          },
                          child: CircleAvatar(
                            radius: 20,
                            child: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const SweepGradient(colors: [
                                  Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.pink, Colors.red,
                                ]).createShader(bounds);
                              },
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                width: 40,
                                height: 40,
                                child: _customAccentMode ? const Icon(Icons.check, color: Colors.white) : const Icon(Icons.palette, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // New: Home summary period setting as a button that opens a popup
          _buildSettingTile(
            title: 'Home Summary Period',
            subtitle: _homePeriodDisplay(SettingsService.instance.homePeriod),
            icon: Icons.timeline,
            onTap: _showHomePeriodDialog,
          ),

          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            title: 'Notifications',
            subtitle: 'Enable reminders and alerts',
            icon: Icons.notifications,
            value: SettingsService.instance.notificationsEnabled,
            onChanged: (val) {
              SettingsService.instance.saveSettings(notificationsEnabled: val);
              setState(() {});
            },
          ),

          _buildSectionHeader('Data'),
          _buildSettingTile(
            title: 'Import/Export',
            subtitle: 'Backup or restore your data',
            icon: Icons.import_export,
            onTap: _showImportExportDialog,
          ),
          _buildSettingTile(
            title: 'Manage Categories',
            subtitle: 'Edit your categories',
            icon: Icons.category,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
              );
            },
          ),
          _buildSettingTile(
            title: 'Clear All Data',
            subtitle: 'Delete all transactions and reset settings',
            icon: Icons.delete_forever,
            isDestructive: true,
            onTap: _clearAllData,
          ),

          const SizedBox(height: 24),
          Center(
            child: Text('App Version: $_appVersion', style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // Helper: display label for home period
  String _homePeriodDisplay(String p) {
    if (p == '3m') return 'Last 3 months';
    if (p == '6m') return 'Last 6 months';
    if (p == 'year') return 'This year';
    return 'This month';
  }

  void _showHomePeriodDialog() {
    final settings = SettingsService.instance;
    final current = settings.homePeriod;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Home Summary Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Current month'),
              trailing: current == 'month' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () async {
                await settings.saveSettings(homePeriod: 'month');
                if (mounted) setState(() {});
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('3 months'),
              trailing: current == '3m' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () async {
                await settings.saveSettings(homePeriod: '3m');
                if (mounted) setState(() {});
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('6 months'),
              trailing: current == '6m' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () async {
                await settings.saveSettings(homePeriod: '6m');
                if (mounted) setState(() {});
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Year'),
              trailing: current == 'year' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () async {
                await settings.saveSettings(homePeriod: 'year');
                if (mounted) setState(() {});
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary; // saturated accent
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = accent;

    // Thumb = accent; Track = lighter tint of accent
    final activeThumb = accent;
    final activeTrack = accent.withOpacity(isDark ? 0.40 : 0.35);

    final inactiveTrack = theme.colorScheme.onSurface.withOpacity(0.18);
    final inactiveThumb = theme.colorScheme.onSurface.withOpacity(isDark ? 0.55 : 0.50);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeThumb,       // thumb accent
          activeTrackColor: activeTrack,  // tinted accent track
          inactiveThumbColor: inactiveThumb,
          inactiveTrackColor: inactiveTrack,
          splashRadius: 20,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  void _showCurrencyDialog() {
    final Map<String, String> currencySymbols = {
      'LYD': 'LYD',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CAD': 'C\$',
      'AUD': 'A\$',
    };
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _currencies.length,
            itemBuilder: (context, index) {
              final currency = _currencies[index];
              final symbol = currencySymbols[currency] ?? currency;
              return ListTile(
                title: Text('$currency ($symbol)'),
                trailing: SettingsService.instance.currency == currency
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  SettingsService.instance.saveSettings(currency: currency);
                  setState(() {});
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCurrencyFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Currency Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Standard'),
              subtitle: const Text('1,234.56'),
              trailing: SettingsService.instance.currencyFormat == 'standard' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                SettingsService.instance.saveSettings(currencyFormat: 'standard');
                setState(() {});
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('No Decimal'),
              subtitle: const Text('1,234'),
              trailing: SettingsService.instance.currencyFormat == 'no_decimal' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                SettingsService.instance.saveSettings(currencyFormat: 'no_decimal');
                setState(() {});
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Compact'),
              subtitle: const Text('1.2K'),
              trailing: SettingsService.instance.currencyFormat == 'compact' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                SettingsService.instance.saveSettings(currencyFormat: 'compact');
                setState(() {});
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _languages.length,
            itemBuilder: (context, index) {
              final language = _languages[index];
              return ListTile(
                title: Text(language),
                trailing: SettingsService.instance.language == language
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  SettingsService.instance.saveSettings(language: language);
                  setState(() {});
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showImportExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup & Restore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Create Backup'),
              subtitle: const Text('Saves internal copy + timestamped file'),
              leading: const Icon(Icons.save_alt),
              onTap: () async {
                Navigator.pop(context);
                await _exportBackup();
              },
            ),
            ListTile(
              title: const Text('Restore Backup (.ffx)'),
              subtitle: const Text('Pick a file from device storage'),
              leading: const Icon(Icons.folder_open),
              onTap: () async {
                Navigator.pop(context);
                await _importBackup();
              },
            ),
            ListTile(
              title: const Text('Restore Internal Auto-Backup'),
              subtitle: const Text('Use the app-managed backup copy'),
              leading: const Icon(Icons.settings_backup_restore),
              onTap: () async {
                Navigator.pop(context);
                await _restoreFromInternal();
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Export Summary PDF'),
              subtitle: const Text('Share overview report'),
              leading: const Icon(Icons.picture_as_pdf),
              onTap: () async {
                Navigator.pop(context);
                await _exportSummaryPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (result == null) return; // user cancelled
      final file = result.files.single;

      if (!file.name.toLowerCase().endsWith('.ffx')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a .ffx file'), backgroundColor: Colors.red));
        }
        return;
      }
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        try { bytes = await File(file.path!).readAsBytes(); } catch (_) {}
      }
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read file'), backgroundColor: Colors.red));
        }
        return;
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(children:[CircularProgressIndicator(), SizedBox(width:16), Text('Restoring...')]),
        ),
      );
      final res = await ExportService.instance.importBackupBytes(bytes);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']),
            backgroundColor: res['success'] ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreFromInternal() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(children:[CircularProgressIndicator(), SizedBox(width:16), Text('Restoring...')]),
        ),
      );
      final bytes = await ExportService.instance.getInternalAutoBackupBytes();
      if (bytes == null) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internal backup found'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final res = await ExportService.instance.importBackupBytes(bytes);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']),
            backgroundColor: res['success'] ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children:[CircularProgressIndicator(), SizedBox(width:16), Text('Creating backup...')]),
      ),
    );
    final res = await ExportService.instance.exportBackup();
    if (mounted) Navigator.pop(context);
    if (mounted) {
      final publicPath = (res['publicCopyPath'] as String?);
      final internalPath = (res['internalPath'] as String?);
      final msg = res['success']
          ? 'Backup saved.\nInternal: ${internalPath ?? '-'}\nFile: ${res['filePath']}\n${publicPath == null ? 'Public copy not created' : 'Public: $publicPath'}'
          : (res['message'] ?? 'Backup failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: res['success'] ? Theme.of(context).colorScheme.primary : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _exportSummaryPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children:[CircularProgressIndicator(), SizedBox(width:16), Text('Exporting PDF...')]),
      ),
    );
    final res = await ExportService.instance.exportPdfSummary();
    if (mounted) Navigator.pop(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']),
          backgroundColor: res['success'] ? Theme.of(context).colorScheme.primary : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to delete all transactions and goals? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await DatabaseService.instance.clearAllData();
                await SettingsService.instance.clearAllSettings();
                // Restart the app to apply a clean state
                if (mounted) Phoenix.rebirth(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear data: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
