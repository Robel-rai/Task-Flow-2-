import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/dashboard/category_donut.dart';
import '../components/dashboard/dashboard_header.dart';
import '../components/dashboard/kpi_cards_row.dart';
import '../components/dashboard/recent_tasks.dart';
import '../components/dashboard/today_agenda.dart';
import '../components/dashboard/weekly_bar_chart.dart';
import '../providers/analytics_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// Home screen: KPIs, weekly completions, category breakdown, today's
/// agenda, and recent tasks.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    if (mounted) setState(() => _userName = name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Column(
      children: [
        const DashboardHeader(),
        // Greeting
        if (_userName.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              'Hello $_userName',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Consumer<AnalyticsProvider>(
              builder: (context, analytics, _) {
                // Resolve category ids to names once for the whole screen.
                final categories = context.read<SettingsProvider>().categoryList;
                final categoryNames = {
                  for (final c in categories) if (c.id != null) c.id!: c.name,
                };

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KpiCardsRow(),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1100;
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: WeeklyBarChart(
                                    data: analytics.weeklyCompletionCounts),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: CategoryDonut(
                                  data: analytics.categoryDistribution,
                                  total: analytics.totalTasks,
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            WeeklyBarChart(
                                data: analytics.weeklyCompletionCounts),
                            const SizedBox(height: 16),
                            CategoryDonut(
                              data: analytics.categoryDistribution,
                              total: analytics.totalTasks,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1100;
                        final agenda = TodayAgenda(
                          tasks: analytics.todayTasks,
                          categoryNames: categoryNames,
                        );
                        final recent = RecentTasks(
                          tasks: analytics.recentTasks,
                          categoryNames: categoryNames,
                        );
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: agenda),
                              const SizedBox(width: 16),
                              Expanded(child: recent),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            agenda,
                            const SizedBox(height: 16),
                            recent,
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
