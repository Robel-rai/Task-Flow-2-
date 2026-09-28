import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/color_wheel_picker.dart';
import 'theme_mode_preview.dart';

/// Dedicated page for customizing colors (dark & light mode) and fonts.
class CustomizationPage extends StatefulWidget {
  const CustomizationPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<CustomizationPage> createState() => _CustomizationPageState();
}

class _CustomizationPageState extends State<CustomizationPage> {
  bool _darkTab = true; // true = dark mode, false = light mode

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final settings = context.watch<SettingsProvider>();

    return Column(
      children: [
        // Header
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Customization',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Colors & fonts',
                      style:
                          TextStyle(fontSize: 12, color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Font Selection ──
                Text('Font',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _FontSection(settings: settings),
                const SizedBox(height: 32),

                // ── Theme preview (dark vs light, side by side) ──
                Text('Preview',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const ThemeModePreviewCard(),
                const SizedBox(height: 32),

                // ── Color Theme ──
                Text('Color Theme',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                // Dark / Light tab toggle
                _DarkLightToggle(
                  darkTab: _darkTab,
                  onChanged: (dark) => setState(() => _darkTab = dark),
                ),
                const SizedBox(height: 16),

                // Preset palettes
                _PresetGrid(
                  darkMode: _darkTab,
                  settings: settings,
                ),
                const SizedBox(height: 24),

                // Custom color pickers
                _CustomColorSection(
                  darkMode: _darkTab,
                  settings: settings,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Font Section ───

class _FontSection extends StatelessWidget {
  const _FontSection({required this.settings});
  final SettingsProvider settings;

  static const _systemFonts = [
    'Montserrat',
    'Roboto',
    'Open Sans',
    'Lato',
    'Poppins',
    'Inter',
    'Nunito',
    'Raleway',
    'Ubuntu',
    'Source Sans 3',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          // Current font display
          ListTile(
            leading: Icon(Icons.font_download_outlined,
                color: colors.primary),
            title: const Text('Current Font',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              settings.fontFamily,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                fontFamily: settings.fontFamily,
              ),
            ),
          ),
          const Divider(height: 1),
          // System fonts
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Built-in Fonts',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textTertiary)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final font in _systemFonts)
                  _FontChip(
                    name: font,
                    current: settings.fontFamily,
                    onTap: () => settings.setCustomFont(font),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Load custom font
          ListTile(
            leading: Icon(Icons.upload_file, color: colors.primary),
            title: const Text('Load Custom Font',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Import a .ttf or .otf font file'),
            onTap: () => _pickCustomFont(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomFont(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select a font file',
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    if (result.isEmpty) return;
    final file = result.first;

    final name = file.name.replaceAll(RegExp(r'\.(ttf|otf)$'), '');
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Font "$name" selected')),
    );

    await context.read<SettingsProvider>().setCustomFont(name);
  }
}

class _FontChip extends StatelessWidget {
  const _FontChip({
    required this.name,
    required this.current,
    required this.onTap,
  });

  final String name;
  final String current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final selected = name == current;

    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.15)
          : colors.surfaceVariant.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontFamily: name,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? colors.primary : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dark / Light Toggle ───

class _DarkLightToggle extends StatelessWidget {
  const _DarkLightToggle({required this.darkTab, required this.onChanged});
  final bool darkTab;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Dark Mode',
              icon: Icons.dark_mode_outlined,
              selected: darkTab,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Light Mode',
              icon: Icons.light_mode_outlined,
              selected: !darkTab,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Material(
      color: selected ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Preset Grid ───

class _PresetGrid extends StatelessWidget {
  const _PresetGrid({required this.darkMode, required this.settings});
  final bool darkMode;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final presets = ColorPreset.presets;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: presets.length + 1,
      itemBuilder: (context, index) {
        // First cell: the user's personal theme (beside the built-ins).
        if (index == 0) {
          return _PersonalThemeTile(darkMode: darkMode, settings: settings);
        }
        final preset = presets[index - 1];
        final presetColors = darkMode ? preset.darkColors : preset.lightColors;

        return Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () {
              if (darkMode) {
                settings.applyDarkPreset(preset);
              } else {
                settings.applyLightPreset(preset);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  // Color swatch preview
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          presetColors.primary,
                          presetColors.background,
                        ],
                      ),
                    ),
                    child: Icon(
                      preset.icon,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Custom Color Section ───

class _CustomColorSection extends StatelessWidget {
  const _CustomColorSection({required this.darkMode, required this.settings});
  final bool darkMode;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final colorRoles = [
      _ColorRole('Background', 'bg', darkMode ? settings.darkBackground : settings.lightBackground),
      _ColorRole('Surface', 'surface', darkMode ? settings.darkSurface : settings.lightSurface),
      _ColorRole('Surface Variant', 'surfaceVariant', darkMode ? settings.darkSurfaceVariant : settings.lightSurfaceVariant),
      _ColorRole('Border', 'border', darkMode ? settings.darkBorder : settings.lightBorder),
      _ColorRole('Primary', 'primary', darkMode ? settings.darkPrimary : settings.lightPrimary),
      _ColorRole('Text Primary', 'textPrimary', darkMode ? settings.darkTextPrimary : settings.lightTextPrimary),
      _ColorRole('Text Secondary', 'textSecondary', darkMode ? settings.darkTextSecondary : settings.lightTextSecondary),
      _ColorRole('Text Tertiary', 'textTertiary', darkMode ? settings.darkTextTertiary : settings.lightTextTertiary),
      _ColorRole('Sidebar', 'sidebarBg', darkMode ? settings.darkSidebarBackground : settings.lightSidebarBackground),
      _ColorRole('Nav Active', 'navActive', darkMode ? settings.darkNavActive : settings.lightNavActive),
      _ColorRole('Nav Active Text', 'navActiveText', darkMode ? settings.darkNavActiveText : settings.lightNavActiveText),
      _ColorRole('Nav Inactive Text', 'navInactiveText', darkMode ? settings.darkNavInactiveText : settings.lightNavInactiveText),
    ];

    final hasCustom = darkMode ? settings.hasCustomDarkColors : settings.hasCustomLightColors;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(
                  darkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${darkMode ? "Dark" : "Light"} Mode Colors',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (hasCustom)
                  TextButton(
                    onPressed: () {
                      if (darkMode) {
                        settings.resetDarkColors();
                      } else {
                        settings.resetLightColors();
                      }
                    },
                    child: const Text('Reset'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < colorRoles.length; i++) ...[
            _ColorPickerRow(
              role: colorRoles[i],
              darkMode: darkMode,
              settings: settings,
            ),
            if (i < colorRoles.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _ColorRole {
  const _ColorRole(this.label, this.key, this.current);
  final String label;
  final String key;
  final Color? current;
}

class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({
    required this.role,
    required this.darkMode,
    required this.settings,
  });

  final _ColorRole role;
  final bool darkMode;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: role.current,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
      ),
      title: Text(role.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
        role.current != null ? AppTheme.colorToHex(role.current!) : 'Default',
        style: TextStyle(
          fontSize: 12,
          color: colors.textTertiary,
          fontFamily: 'monospace',
        ),
      ),
      trailing: const Icon(Icons.color_lens_outlined, size: 20),
      onTap: () => _openColorPicker(context),
    );
  }

  Future<void> _openColorPicker(BuildContext context) async {
    final initial =
        role.current ?? SettingsProvider.defaultForRole(role.key, darkMode);
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(initialColor: initial),
    );
    if (picked == null || !context.mounted) return;

    if (darkMode) {
      await context.read<SettingsProvider>().setDarkColor(role.key, picked);
    } else {
      await context.read<SettingsProvider>().setLightColor(role.key, picked);
    }
  }
}

/// Dialog that shows the ColorWheel picker with a live preview and confirm/cancel.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialColor});
  final Color initialColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick Color',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              ColorWheel(
                color: _color,
                onChanged: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(color: colors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _color),
                    child: const Text('Select'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Personal Theme Tile ───

/// Grid tile beside the built-in presets representing the user's own saved
/// theme for the active Dark/Light tab. When nothing is saved yet, tapping
/// snapshots the colors currently in effect. Once saved, tapping applies the
/// snapshot back; the overflow menu can update or delete it.
class _PersonalThemeTile extends StatelessWidget {
  const _PersonalThemeTile({required this.darkMode, required this.settings});

  final bool darkMode;
  final SettingsProvider settings;

  bool get _hasPersonal =>
      darkMode ? settings.hasPersonalDarkTheme : settings.hasPersonalLightTheme;

  Color? _personalColor(String role) => darkMode
      ? settings.personalDarkColor(role)
      : settings.personalLightColor(role);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _hasPersonal
            ? settings.applyPersonalTheme(darkMode: darkMode)
            : settings.savePersonalTheme(darkMode: darkMode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hasPersonal ? colors.primary : colors.border,
              width: _hasPersonal ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: _hasPersonal
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _personalColor('primary') ?? colors.primary,
                            _personalColor('bg') ?? colors.background,
                          ],
                        )
                      : null,
                  color: _hasPersonal ? null : colors.surfaceVariant,
                ),
                child: Icon(
                  _hasPersonal ? Icons.person : Icons.add,
                  size: 18,
                  color: _hasPersonal ? Colors.white : colors.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _hasPersonal ? 'Personal' : 'Personal (save current)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hasPersonal)
                PopupMenuButton<String>(
                  tooltip: 'Personal theme options',
                  icon: Icon(Icons.more_vert,
                      size: 18, color: colors.textTertiary),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    switch (value) {
                      case 'apply':
                        settings.applyPersonalTheme(darkMode: darkMode);
                      case 'update':
                        settings.savePersonalTheme(darkMode: darkMode);
                      case 'delete':
                        settings.deletePersonalTheme(darkMode: darkMode);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'apply', child: Text('Apply personal theme')),
                    PopupMenuItem(
                        value: 'update',
                        child: Text('Update with current colors')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
