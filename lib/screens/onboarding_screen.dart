import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_shell.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/task.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  static Future<void> resetFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', false);
  }
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  String _name = '';
  ThemeMode _themeMode = ThemeMode.system;
  bool _loadSample = true;

  void _next() {
    if (_page < 2) {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _controller.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (_name.isNotEmpty) await prefs.setString('user_name', _name);
    if (mounted) context.read<ThemeProvider>().setThemeMode(_themeMode);
    if (_loadSample && mounted) await _loadSampleTasks(context);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
  }

  Future<void> _loadSampleTasks(BuildContext context) async {
    final tasks = context.read<TasksProvider>();
    final settings = context.read<SettingsProvider>();
    if (settings.categoryList.isEmpty) return;
    final generalId = settings.categoryList
        .firstWhere((c) => c.name == 'General', orElse: () => settings.categoryList.first)
        .id;
    final now = DateTime.now();
    final samples = [
      ('Welcome to TaskFlow!', 'This is your first task. Tap to edit or complete it.', 'Medium'),
      ('Explore the Dashboard', 'Check your KPIs, charts, and today agenda.', 'Low'),
      ('Create your first project', 'Group tasks and track progress on a kanban board.', 'Medium'),
      ('Try the Focus Timer', 'Start a Pomodoro session to stay focused for 25 minutes.', 'High'),
      ('Set up a daily routine', 'Build habits with streaks and reminders.', 'Medium'),
    ];
    for (int i = 0; i < samples.length; i++) {
      final (title, desc, priority) = samples[i];
      final task = Task(
        title: title,
        description: desc,
        priority: priority,
        categoryId: generalId,
        scheduledDate: DateTime(now.year, now.month, now.day + i),
        createdAt: now,
      );
      await tasks.createTask(task);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              if (_page > 0)
                IconButton(icon: Icon(Icons.arrow_back, color: colors.textSecondary), onPressed: _back)
              else
                const SizedBox(width: 48),
              const Spacer(),
              TextButton(onPressed: _finish, child: Text('Skip', style: TextStyle(color: colors.textTertiary, fontSize: 14, fontWeight: FontWeight.w500))),
            ]),
          ),
          Expanded(
            child: PageView(controller: _controller, physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _NameStep(name: _name, onChanged: (v) => setState(() => _name = v)),
                _ThemeStep(selected: _themeMode, onChanged: (v) => setState(() => _themeMode = v)),
                _SampleDataStep(loadSample: _loadSample, onChanged: (v) => setState(() => _loadSample = v)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
            child: Row(children: [
              Row(children: [
                for (int i = 0; i < 3; i++)
                  AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.only(right: 6),
                    width: i == _page ? 24 : 8, height: 8,
                    decoration: BoxDecoration(color: i == _page ? AppTheme.primary : colors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
              const Spacer(),
              FilledButton(onPressed: _next,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_page == 2 ? 'Get Started' : 'Next', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.name, required this.onChanged});
  final String name;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100, height: 100, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
          child: const Icon(Icons.person_outline, size: 48, color: AppTheme.primary)),
        const SizedBox(height: 32),
        Text('What should we call you?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        const SizedBox(height: 8),
        Text('Optional - your name will appear on the dashboard.', style: TextStyle(fontSize: 14, color: colors.textSecondary)),
        const SizedBox(height: 28),
        SizedBox(width: 320, child: TextField(onChanged: onChanged, autofocus: true, textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: 'Enter your name', prefixIcon: const Icon(Icons.person_outline, size: 20), filled: true,
            fillColor: colors.surfaceVariant.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
          ))),
      ]));
  }
}

class _ThemeStep extends StatelessWidget {
  const _ThemeStep({required this.selected, required this.onChanged});
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100, height: 100, decoration: BoxDecoration(color: AppTheme.indigo.withValues(alpha: 0.10), shape: BoxShape.circle),
          child: const Icon(Icons.palette_outlined, size: 48, color: AppTheme.indigo)),
        const SizedBox(height: 32),
        Text('Choose your theme', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        const SizedBox(height: 8),
        Text('You can always change this later in Settings.', style: TextStyle(fontSize: 14, color: colors.textSecondary)),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ThemeOption(icon: Icons.dark_mode_outlined, label: 'Dark', selected: selected == ThemeMode.dark, onTap: () => onChanged(ThemeMode.dark)),
          const SizedBox(width: 16),
          _ThemeOption(icon: Icons.light_mode_outlined, label: 'Light', selected: selected == ThemeMode.light, onTap: () => onChanged(ThemeMode.light)),
          const SizedBox(width: 16),
          _ThemeOption(icon: Icons.phone_android, label: 'System', selected: selected == ThemeMode.system, onTap: () => onChanged(ThemeMode.system)),
        ]),
      ]));
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 110, padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.12) : colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppTheme.primary : colors.border, width: selected ? 2 : 1)),
        child: Column(children: [
          Icon(icon, size: 32, color: selected ? AppTheme.primary : colors.textSecondary),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? AppTheme.primary : colors.textPrimary)),
        ])));
  }
}

class _SampleDataStep extends StatelessWidget {
  const _SampleDataStep({required this.loadSample, required this.onChanged});
  final bool loadSample;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100, height: 100, decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.10), shape: BoxShape.circle),
          child: const Icon(Icons.download_outlined, size: 48, color: AppTheme.emerald)),
        const SizedBox(height: 32),
        Text('Start with sample data?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        const SizedBox(height: 8),
        Text('We will add a few example tasks so you can explore how TaskFlow works.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: colors.textSecondary)),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _SampleOption(icon: Icons.download_outlined, label: 'Yes, load samples', selected: loadSample, onTap: () => onChanged(true)),
          const SizedBox(width: 16),
          _SampleOption(icon: Icons.fiber_manual_record_outlined, label: 'Start empty', selected: !loadSample, onTap: () => onChanged(false)),
        ]),
      ]));
  }
}

class _SampleOption extends StatelessWidget {
  const _SampleOption({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 150, padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? AppTheme.emerald.withValues(alpha: 0.12) : colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppTheme.emerald : colors.border, width: selected ? 2 : 1)),
        child: Column(children: [
          Icon(icon, size: 32, color: selected ? AppTheme.emerald : colors.textSecondary),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? AppTheme.emerald : colors.textPrimary)),
        ])));
  }
}
