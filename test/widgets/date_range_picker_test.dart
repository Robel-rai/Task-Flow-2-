import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:taskflow/theme/app_theme.dart';
import 'package:taskflow/widgets/date_range_picker.dart';

void main() {
  /// Pumps the app, opens the dialog, and stores the dialog's result in
  /// [result] once it closes (Cancel/Apply).
  Future<void> openPicker(
    WidgetTester tester, {
    DateTime? start,
    DateTime? end,
    required void Function((DateTime, DateTime)?) onResult,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              onResult(await showDateRangePickerDialog(context,
                  initialStart: start, initialEnd: end));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders month header, Monday-first weekdays, and actions',
      (tester) async {
    await openPicker(tester, onResult: (_) {});

    final now = DateTime.now();
    expect(find.text(DateFormat('MMMM yyyy').format(now)), findsOneWidget);
    for (final w in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']) {
      expect(find.text(w), findsOneWidget);
    }
    expect(find.text('Select a start date'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    // Apply is disabled until a day is picked.
    final apply = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Apply'));
    expect(apply.onPressed, isNull);
  });

  testWidgets('tapping two days selects a range; Apply returns it',
      (tester) async {
    (DateTime, DateTime)? result;
    await openPicker(tester, onResult: (r) => result = r);

    final now = DateTime.now();
    await tester.tap(find.text('1'));
    await tester.pump();
    // Only the start is picked so far → single-day label.
    expect(
      find.text(
          DateFormat('MMM d, yyyy').format(DateTime(now.year, now.month, 1))),
      findsOneWidget,
    );

    await tester.tap(find.text('2'));
    await tester.pump();
    expect(
      find.text(
          '${DateFormat('MMM d, yyyy').format(DateTime(now.year, now.month, 1))} — '
          '${DateFormat('MMM d, yyyy').format(DateTime(now.year, now.month, 2))}'),
      findsOneWidget,
    );

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final picked = result!;
    expect(picked.$1, DateTime(now.year, now.month, 1));
    expect(picked.$2, DateTime(now.year, now.month, 2));
  });

  testWidgets('tapping a day before the start restarts the range',
      (tester) async {
    (DateTime, DateTime)? result;
    await openPicker(tester, onResult: (r) => result = r);

    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('10'));
    await tester.pump();
    await tester.tap(find.text('12'));
    await tester.pump();

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final picked = result!;
    expect(picked.$1, DateTime(now.year, now.month, 10));
    expect(picked.$2, DateTime(now.year, now.month, 12));
  });

  testWidgets('cancel returns null', (tester) async {
    (DateTime, DateTime)? result;
    await openPicker(tester, onResult: (r) => result = r);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('pre-selected range is shown and navigable by month',
      (tester) async {
    await openPicker(
      tester,
      start: DateTime(2026, 8, 17),
      end: DateTime(2026, 8, 23),
      onResult: (_) {},
    );

    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('Aug 17, 2026 — Aug 23, 2026'), findsOneWidget);

    // Next-month navigation updates the header.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('September 2026'), findsOneWidget);
  });
}
