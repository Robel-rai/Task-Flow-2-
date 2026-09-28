import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_version.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';

/// Sub-setting page showing app version, credits, and license info.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      children: [
        // Header
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to settings',
                icon: Icon(Icons.arrow_back, color: colors.textSecondary),
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('About',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'TaskFlow v${AppVersion.version}',
                      style: TextStyle(
                          fontSize: 12, color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App icon + name
                Center(
                  child: Column(
                    children: [
                      const AppLogo(size: 80),
                      const SizedBox(height: 16),
                      Text(
                        AppVersion.appName,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version ${AppVersion.version} (build ${AppVersion.build})',
                        style: TextStyle(
                            fontSize: 14, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Version info card
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            Icon(Icons.info_outline, color: colors.primary),
                        title: const Text('App Version',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (ctx, snap) {
                            final info = snap.data;
                            if (info == null) {
                              return const Text('Loading...');
                            }
                            return Text(
                              '${info.version}+${info.buildNumber}',
                              style: TextStyle(
                                  fontSize: 12, color: colors.textTertiary),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.code_outlined,
                            color: AppTheme.emerald),
                        title: const Text('Platform',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Flutter Desktop • Windows',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Features
                Text('Features',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FeatureChip(label: 'Task Management', icon: Icons.check_circle_outline),
                        _FeatureChip(label: 'Projects & Kanban', icon: Icons.dashboard_outlined),
                        _FeatureChip(label: 'Calendar', icon: Icons.calendar_today),
                        _FeatureChip(label: 'Focus Timer', icon: Icons.timer_outlined),
                        _FeatureChip(label: 'Routines', icon: Icons.repeat),
                        _FeatureChip(label: 'Analytics', icon: Icons.bar_chart),
                        _FeatureChip(label: 'Tags', icon: Icons.label_outline),
                        _FeatureChip(label: 'Backup & Restore', icon: Icons.backup_outlined),
                        _FeatureChip(label: 'Custom Themes', icon: Icons.palette_outlined),
                        _FeatureChip(label: 'CSV Export', icon: Icons.file_download_outlined),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // License
                Text('License',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'MIT License\n\n'
                      'Copyright © 2026 TaskFlow\n\n'
                      'Permission is hereby granted, free of charge, to any person obtaining a copy '
                      'of this software and associated documentation files (the "Software"), to deal '
                      'in the Software without restriction, including without limitation the rights '
                      'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
                      'copies of the Software, and to permit persons to whom the Software is '
                      'furnished to do so, subject to the following conditions:\n\n'
                      'The above copyright notice and this permission notice shall be included in all '
                      'copies or substantial portions of the Software.\n\n'
                      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR '
                      'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, '
                      'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: colors.textPrimary)),
        ],
      ),
    );
  }
}
