import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/tag.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../repositories/tag_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/date_range_picker.dart';

/// Compact filter/sort bar for the tasks list.
///
/// Replaces the old five side-by-side dropdowns with:
///  - a single "Filters" button (badge = number of active filter
///    dimensions) that opens a unified dropdown panel with chip-based
///    sections (quick date presets only — custom ranges live in the
///    advanced modal);
///  - an "Advanced filters…" floating modal (presets, custom date
///    range, Apply/Reset);
///  - a removable summary-chips row ([ActiveFilterChipsRow], rendered by
///    the tasks screen);
///  - a "Sort" menu (created time asc/desc, title A–Z / Z–A).
class FilterChipBar extends StatefulWidget {
  const FilterChipBar({
    super.key,
    required this.gridView,
    required this.onViewChanged,
  });

  final bool gridView;
  final ValueChanged<bool> onViewChanged;

  @override
  State<FilterChipBar> createState() => _FilterChipBarState();
}

class _FilterChipBarState extends State<FilterChipBar> {
  List<Tag> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await TagRepository().getAll();
    if (mounted) setState(() => _tags = tags);
  }

  Future<void> _reloadTags() async {
    final tags = await TagRepository().getAll();
    if (!mounted) return;
    setState(() => _tags = tags);
  }

  Future<void> _showAdvancedModal() async {
    await _reloadTags();
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => AdvancedFilterModal(tags: _tags),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 4),
      child: Row(
        children: [
          _FiltersButton(tags: _tags, onOpenAdvanced: _showAdvancedModal),
          const SizedBox(width: 8),
          const _SortButton(),
          const Spacer(),
          IconButton(
            tooltip:
                widget.gridView ? 'Switch to list view' : 'Switch to grid view',
            icon: Icon(
              widget.gridView ? Icons.view_list : Icons.grid_view,
              color: colors.textSecondary,
            ),
            onPressed: () => widget.onViewChanged(!widget.gridView),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Filters button + unified dropdown panel (overlay)
// ═══════════════════════════════════════════════════════════════════

class _FiltersButton extends StatefulWidget {
  const _FiltersButton({required this.tags, required this.onOpenAdvanced});

  final List<Tag> tags;
  final VoidCallback onOpenAdvanced;

  @override
  State<_FiltersButton> createState() => _FiltersButtonState();
}

class _FiltersButtonState extends State<_FiltersButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  bool get _panelOpen => _entry != null;

  void _togglePanel() {
    if (_panelOpen) {
      _removePanel();
    } else {
      _showPanel();
    }
  }

  void _showPanel() {
    _entry = OverlayEntry(
      builder: (context) => _FilterPanel(
        link: _link,
        tags: widget.tags,
        onDismiss: _removePanel,
        onOpenAdvanced: () {
          _removePanel();
          widget.onOpenAdvanced();
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() {});
  }

  void _removePanel() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  /// Overlay teardown that is safe while the framework is deactivating
  /// this widget (no [setState], no ancestor lookups).
  void _teardownPanel() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void deactivate() {
    // The tasks screen can rebuild/remount while the panel is open
    // (e.g. trash toggle) — always tear the overlay down with it.
    _teardownPanel();
    super.deactivate();
  }

  @override
  void dispose() {
    _teardownPanel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tasks = context.watch<TasksProvider>();
    final count = tasks.activeFilterCount;

    return CompositedTransformTarget(
      link: _link,
      child: _BarButton(
        icon: Icons.filter_alt_outlined,
        label: 'Filters',
        active: count > 0 || _panelOpen,
        badge: count > 0 ? count : null,
        colors: colors,
        onTap: _togglePanel,
      ),
    );
  }
}

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    required this.link,
    required this.tags,
    required this.onDismiss,
    required this.onOpenAdvanced,
  });

  final LayerLink link;
  final List<Tag> tags;
  final VoidCallback onDismiss;
  final VoidCallback onOpenAdvanced;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  @override
  void initState() {
    super.initState();
    // Refresh tags in case they changed since the bar mounted.
    TagRepository().getAll().then((tags) {
      if (mounted) setState(() => widget.tags..clear()..addAll(tags));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Invisible full-screen barrier: tap anywhere outside to close.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          offset: const Offset(0, 42),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 380,
                constraints: BoxConstraints(maxHeight: size.height - 120),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _PanelBody(
                  tags: widget.tags,
                  onDismiss: widget.onDismiss,
                  onOpenAdvanced: widget.onOpenAdvanced,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({
    required this.tags,
    required this.onDismiss,
    required this.onOpenAdvanced,
  });

  final List<Tag> tags;
  final VoidCallback onDismiss;
  final VoidCallback onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tasks = context.watch<TasksProvider>();
    final settings = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: title + clear-all + close.
          Row(
            children: [
              Icon(Icons.tune, size: 16, color: colors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Filter tasks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              if (tasks.hasActiveFilters)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                  onPressed: tasks.clearFilters,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  // No tooltip here: tooltips use OverlayPortal, whose
                  // layout cannot compute paint transforms through the
                  // CompositedTransformFollower that positions this
                  // panel (crashes in debug mode on hover).
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _SectionLabel('Category', colors),
          const SizedBox(height: 6),
          _ChipWrap(
            children: [
              _ChoiceChip(
                label: 'All',
                selected: tasks.categoryFilter == null,
                onSelected: () => tasks.setCategoryFilter(null),
              ),
              for (final c in settings.categoryList)
                _ChoiceChip(
                  label: c.name,
                  colorKey: c.color,
                  selected: tasks.categoryFilter == c.id,
                  onSelected: () => tasks.setCategoryFilter(c.id),
                ),
            ],
          ),
          const SizedBox(height: 14),

          _SectionLabel('Status', colors),
          const SizedBox(height: 6),
          _ChipWrap(
            children: [
              _ChoiceChip(
                label: 'All',
                selected: tasks.statusFilter == null,
                onSelected: () => tasks.setStatusFilter(null),
              ),
              for (final s in const ['Pending', 'In Progress', 'Completed'])
                _ChoiceChip(
                  label: s,
                  selected: tasks.statusFilter == s,
                  onSelected: () => tasks.setStatusFilter(s),
                ),
            ],
          ),
          const SizedBox(height: 14),

          _SectionLabel('Priority', colors),
          const SizedBox(height: 6),
          _ChipWrap(
            children: [
              _ChoiceChip(
                label: 'All',
                selected: tasks.priorityFilter == null,
                onSelected: () => tasks.setPriorityFilter(null),
              ),
              for (final p in const ['High', 'Medium', 'Low'])
                _ChoiceChip(
                  label: p,
                  selected: tasks.priorityFilter == p,
                  onSelected: () => tasks.setPriorityFilter(p),
                ),
            ],
          ),
          const SizedBox(height: 14),

          _SectionLabel('Tags', colors),
          const SizedBox(height: 6),
          if (tags.isEmpty)
            Text(
              'No tags yet',
              style: TextStyle(fontSize: 12, color: colors.textTertiary),
            )
          else
            _ChipWrap(
              children: [
                _ChoiceChip(
                  label: 'All',
                  selected: tasks.tagFilter == null,
                  onSelected: () => tasks.setTagFilter(null),
                ),
                for (final tag in tags)
                  _ChoiceChip(
                    label: tag.name,
                    selected: tasks.tagFilter == tag.id,
                    onSelected: () => tasks.setTagFilter(tag.id),
                  ),
              ],
            ),
          const SizedBox(height: 14),

          _SectionLabel('Date', colors),
          const SizedBox(height: 6),
          _ChipWrap(
            children: [
              _ChoiceChip(
                label: 'All dates',
                selected: !tasks.hasDateFilter,
                onSelected: tasks.hasDateFilter
                    ? () => tasks.setDatePreset(
                        start: null, end: null, overdue: false)
                    : null,
              ),
              _ChoiceChip(
                label: 'Today',
                selected: tasks.isDateRange(_today(), _today()),
                onSelected: () => tasks.setDatePreset(
                    start: _today(), end: _today(), overdue: false),
              ),
              _ChoiceChip(
                label: 'This week',
                selected: tasks.isDateRange(
                    _weekStart(), _weekStart().add(const Duration(days: 6))),
                onSelected: () => tasks.setDatePreset(
                    start: _weekStart(),
                    end: _weekStart().add(const Duration(days: 6)),
                    overdue: false),
              ),
              _ChoiceChip(
                label: 'This month',
                selected: tasks.isDateRange(_monthStart(), _monthEnd()),
                onSelected: () => tasks.setDatePreset(
                    start: _monthStart(),
                    end: _monthEnd(),
                    overdue: false),
              ),
              _ChoiceChip(
                label: 'Overdue',
                selected: tasks.overdueOnly,
                onSelected: () =>
                    tasks.setDatePreset(start: null, end: null, overdue: true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.open_in_new,
                  size: 14, color: colors.textSecondary),
              label: Text(
                'Advanced filters…',
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.border),
                backgroundColor: colors.surfaceVariant.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onOpenAdvanced,
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _weekStart() {
    final n = _today();
    return n.subtract(Duration(days: n.weekday - DateTime.monday));
  }

  static DateTime _monthStart() =>
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  static DateTime _monthEnd() =>
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
}

// ═══════════════════════════════════════════════════════════════════
//  Advanced floating modal
// ═══════════════════════════════════════════════════════════════════

/// Centered floating popup for heavier filter work. Edits a local draft;
/// [TasksProvider.applyAdvancedFilters] commits everything on Apply.
class AdvancedFilterModal extends StatefulWidget {
  const AdvancedFilterModal({super.key, required this.tags});

  final List<Tag> tags;

  @override
  State<AdvancedFilterModal> createState() => _AdvancedFilterModalState();
}

class _AdvancedFilterModalState extends State<AdvancedFilterModal> {
  // Draft state — only committed to the provider on Apply.
  int? _category;
  String? _status;
  String? _priority;
  int? _tag;
  DateTime? _start;
  DateTime? _end;
  bool _overdue = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final tasks = context.read<TasksProvider>();
    _category = tasks.categoryFilter;
    _status = tasks.statusFilter;
    _priority = tasks.priorityFilter;
    _tag = tasks.tagFilter;
    _start = tasks.startDateFilter;
    _end = tasks.endDateFilter;
    _overdue = tasks.overdueOnly;
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePickerDialog(
      context,
      initialStart: _start,
      initialEnd: _end,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _start = picked.$1;
      _end = picked.$2;
      _overdue = false;
      _dirty = true;
    });
  }

  Future<void> _apply() async {
    await context.read<TasksProvider>().applyAdvancedFilters(
          categoryId: _category,
          status: _status,
          priority: _priority,
          tagId: _tag,
          startDate: _start,
          endDate: _end,
          overdue: _overdue,
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _resetDraft() {
    setState(() {
      _category = null;
      _status = null;
      _priority = null;
      _tag = null;
      _start = null;
      _end = null;
      _overdue = false;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final settings = context.watch<SettingsProvider>();

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.filter_alt, size: 18, color: colors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Advanced filters',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close,
                        size: 18, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              Divider(color: colors.border, height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick presets', style: _sectionStyle(colors)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _presetChip('Today', _presetIs('today'),
                              onTap: () => _presetTap(
                                  start: _today(),
                                  end: _today(),
                                  overdue: false)),
                          _presetChip('This week', _presetIs('week'),
                              onTap: () => _presetTap(
                                  start: _weekStart(),
                                  end: _weekStart()
                                      .add(const Duration(days: 6)),
                                  overdue: false)),
                          _presetChip('This month', _presetIs('month'),
                              onTap: () => _presetTap(
                                  start: _monthStart(),
                                  end: _monthEnd(),
                                  overdue: false)),
                          _presetChip('Overdue', _overdue && _start == null,
                              onTap: () => _presetTap(
                                  start: null, end: null, overdue: true)),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text('Date range', style: _sectionStyle(colors)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _RangeBox(
                              label: _start == null
                                  ? 'Start date'
                                  : DateFormat('MMM d, yyyy').format(_start!),
                              onTap: _pickCustomRange,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward,
                                size: 14, color: colors.textTertiary),
                          ),
                          Expanded(
                            child: _RangeBox(
                              label: _end == null
                                  ? 'End date'
                                  : DateFormat('MMM d, yyyy').format(_end!),
                              onTap: _pickCustomRange,
                            ),
                          ),
                          if (_start != null || _end != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Clear dates',
                              icon: Icon(Icons.close,
                                  size: 16, color: colors.textSecondary),
                              onPressed: () => setState(() {
                                _start = null;
                                _end = null;
                                _dirty = true;
                              }),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text('Category', style: _sectionStyle(colors)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _modalChip('All',
                              selected: _category == null,
                              onTap: () => _set(() => _category = null)),
                          for (final c in settings.categoryList)
                            _modalChip(c.name,
                                colorKey: c.color,
                                selected: _category == c.id,
                                onTap: () => _set(() => _category = c.id)),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text('Status', style: _sectionStyle(colors)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _modalChip('All',
                              selected: _status == null,
                              onTap: () => _set(() => _status = null)),
                          for (final s in const [
                            'Pending',
                            'In Progress',
                            'Completed'
                          ])
                            _modalChip(s,
                                selected: _status == s,
                                onTap: () => _set(() => _status = s)),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text('Priority', style: _sectionStyle(colors)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _modalChip('All',
                              selected: _priority == null,
                              onTap: () => _set(() => _priority = null)),
                          for (final p in const ['High', 'Medium', 'Low'])
                            _modalChip(p,
                                selected: _priority == p,
                                onTap: () => _set(() => _priority = p)),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text('Tags', style: _sectionStyle(colors)),
                      const SizedBox(height: 8),
                      if (widget.tags.isEmpty)
                        Text('No tags yet',
                            style: TextStyle(
                                fontSize: 12, color: colors.textTertiary))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _modalChip('All',
                                selected: _tag == null,
                                onTap: () => _set(() => _tag = null)),
                            for (final tag in widget.tags)
                              _modalChip(tag.name,
                                  selected: _tag == tag.id,
                                  onTap: () => _set(() => _tag = tag.id)),
                          ],
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              Divider(color: colors.border, height: 24),

              // Footer
              Row(
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.restart_alt,
                        size: 16, color: colors.textSecondary),
                    label: Text('Reset',
                        style: TextStyle(color: colors.textSecondary)),
                    onPressed: _resetDraft,
                  ),
                  const Spacer(),
                  if (_dirty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        'Unapplied changes',
                        style: TextStyle(
                            fontSize: 12, color: colors.textTertiary),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.border),
                      backgroundColor:
                          colors.surfaceVariant.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Apply',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _set(VoidCallback mutation) {
    setState(() {
      mutation();
      _dirty = true;
    });
  }

  void _presetTap(
      {required DateTime? start,
      required DateTime? end,
      required bool overdue}) {
    setState(() {
      if (overdue) {
        _overdue = true;
        _start = null;
        _end = null;
      } else {
        _overdue = false;
        _start = start;
        _end = end;
      }
      _dirty = true;
    });
  }

  bool _presetIs(String kind) {
    if (_overdue) return false;
    final today = _today();
    switch (kind) {
      case 'today':
        return _sameDay(_start, today) && _sameDay(_end, today);
      case 'week':
        return _sameDay(_start, _weekStart()) &&
            _sameDay(_end, _weekStart().add(const Duration(days: 6)));
      case 'month':
        return _sameDay(_start, _monthStart()) &&
            _sameDay(_end, _monthEnd());
      default:
        return false;
    }
  }

  Widget _presetChip(String label, bool selected,
      {required VoidCallback onTap}) {
    return _modalChip(label, selected: selected, onTap: onTap);
  }

  Widget _modalChip(
    String label, {
    String? colorKey,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final color = colorKey != null ? AppTheme.getRoutineColor(colorKey) : null;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? colors.primary : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? colors.primary : colors.textPrimary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Icon(Icons.check, size: 13, color: colors.primary),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _sectionStyle(AppThemeColors colors) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: colors.textSecondary,
      );

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _weekStart() {
    final n = _today();
    return n.subtract(Duration(days: n.weekday - DateTime.monday));
  }

  static DateTime _monthStart() =>
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  static DateTime _monthEnd() =>
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Rounded display box for one end of the date range (opens the picker).
class _RangeBox extends StatelessWidget {
  const _RangeBox({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 15, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Sort button + menu
// ═══════════════════════════════════════════════════════════════════

class _SortButton extends StatelessWidget {
  const _SortButton();

  static const _options = <(String, String, bool)>[
    ('created_at', 'Newest first', false),
    ('created_at', 'Oldest first', true),
    ('title', 'Title A–Z', true),
    ('title', 'Title Z–A', false),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tasks = context.watch<TasksProvider>();

    final current = _options.firstWhere(
      (o) => o.$1 == tasks.sortBy && o.$3 == tasks.ascending,
      orElse: () => _options.first,
    );

    return _BarButton(
      icon: Icons.sort,
      label: 'Sort: ${current.$2}',
      active: false,
      colors: colors,
      onTap: () => _openMenu(context, current),
    );
  }

  void _openMenu(BuildContext context, (String, String, bool) current) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tasks = context.read<TasksProvider>();
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context, rootOverlay: true)
        .context
        .findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<(String, String, bool)>(
      context: context,
      position: position,
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(minWidth: 190),
      items: [
        for (final o in _options)
          PopupMenuItem<(String, String, bool)>(
            value: o,
            height: 40,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: o == current
                      ? Icon(Icons.check, size: 15, color: colors.primary)
                      : null,
                ),
                Text(
                  o.$2,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textPrimary,
                    fontWeight:
                        o == current ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    ).then((choice) {
      if (choice == null) return;
      tasks.setSort(choice.$1, ascending: choice.$3);
    });
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Shared building blocks
// ═══════════════════════════════════════════════════════════════════

/// Pill-shaped bar button shared by the Filters and Sort controls.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.colors,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int? badge;
  final AppThemeColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? colors.primary.withValues(alpha: 0.14)
        : colors.surfaceVariant.withValues(alpha: 0.5);
    final fg = active ? colors.primary : colors.textSecondary;
    final border =
        active ? colors.primary.withValues(alpha: 0.45) : colors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Uppercased micro-label for a chip group.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.colors);

  final String text;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: colors.textTertiary,
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

/// A single selectable filter chip used in the dropdown panel.
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.colorKey,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final String? colorKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final key = colorKey;
    final color = key != null ? AppTheme.getRoutineColor(key) : null;
    final disabled = onSelected == null;
    final fg = selected
        ? colors.primary
        : (disabled ? colors.textTertiary : colors.textPrimary);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Icon(Icons.check, size: 13, color: colors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Summary chips row (rendered by TasksScreen when filters are active)
// ═══════════════════════════════════════════════════════════════════

/// Removable one-line summary of the currently active filters, shown
/// between the header and the task list.
class ActiveFilterChipsRow extends StatelessWidget {
  const ActiveFilterChipsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tasks = context.watch<TasksProvider>();
    final settings = context.watch<SettingsProvider>();

    if (!tasks.hasActiveFilters) return const SizedBox.shrink();

    final chips = <Widget>[];

    if (tasks.searchQuery.isNotEmpty) {
      chips.add(_SummaryChip(
        label: 'Search: "${tasks.searchQuery}"',
        onRemove: () => tasks.setSearchQuery(''),
      ));
    }
    if (tasks.categoryFilter != null) {
      final name = settings.categoryList
          .where((c) => c.id == tasks.categoryFilter)
          .map((c) => c.name)
          .firstOrNull;
      chips.add(_SummaryChip(
        label: 'Category: ${name ?? '?'}',
        onRemove: () => tasks.setCategoryFilter(null),
      ));
    }
    if (tasks.statusFilter != null) {
      chips.add(_SummaryChip(
        label: 'Status: ${tasks.statusFilter}',
        onRemove: () => tasks.setStatusFilter(null),
      ));
    }
    if (tasks.priorityFilter != null) {
      chips.add(_SummaryChip(
        label: 'Priority: ${tasks.priorityFilter}',
        onRemove: () => tasks.setPriorityFilter(null),
      ));
    }
    if (tasks.tagFilter != null) {
      chips.add(_SummaryChip(
        label: 'Tag filter active',
        onRemove: () => tasks.setTagFilter(null),
      ));
    }
    final start = tasks.startDateFilter;
    final end = tasks.endDateFilter;
    if (start != null || end != null) {
      final label = start != null && end != null
          ? '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}'
          : start != null
              ? 'From ${DateFormat('MMM d').format(start)}'
              : 'Until ${DateFormat('MMM d').format(end!)}';
      chips.add(_SummaryChip(
        label: 'Dates: $label',
        onRemove: () => tasks.setDateRangeFilter(null, null),
      ));
    }
    if (tasks.overdueOnly) {
      chips.add(_SummaryChip(
        label: 'Overdue',
        onRemove: () => tasks.setOverdueFilter(false),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 2, 32, 8),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 13, color: colors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 6, children: chips),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
            ),
            onPressed: tasks.clearFilters,
            child: Text(
              'Clear all',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 3, 3),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 20,
            height: 20,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 13,
              tooltip: 'Remove filter',
              icon: Icon(Icons.close, color: colors.primary),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}
