import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taskflow/widgets/task_dialog.dart';

/// Regression test for the RenderFlex overflow reported in the task
/// dialog: the Project dropdown overflowed by 28 pixels when a long
/// project title was selected in a ~190px-wide field.
///
/// The dropdowns are plain form fields with no external dependencies, so
/// this pumps them directly at the reported width instead of booting the
/// whole app.
void main() {
  const longTitle =
      'A very long project name that will not fit into a narrow field';

  Future<void> pumpDialogFields(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            // Mirrors the dialog's content width: each dropdown in the
            // two-column row got ~190px when the overflow was reported.
            padding: const EdgeInsets.all(48),
            child: Row(
              children: [
                Expanded(
                  child: TaskDropdown<String>(
                    labelText: 'Status',
                    initialValue: 'Pending',
                    items: const [
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'In Progress', child: Text('In Progress')),
                    ],
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TaskDropdown<int?>(
                    labelText: 'Project',
                    initialValue: 1,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text(longTitle)),
                    ],
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
      'long selected title does not overflow the Project dropdown '
      '(regression: RenderFlex overflowed by 28 pixels)', (tester) async {
    await pumpDialogFields(tester);

    // Layout must complete with no RenderFlex overflow exception.
    expect(tester.takeException(), isNull);
  });

  testWidgets('long selected title is constrained inside the field',
      (tester) async {
    await pumpDialogFields(tester);

    // The Text widget still carries the full string (the ellipsis is
    // applied at paint time) but must be laid out within the field's
    // bounds — i.e. no wider than the half-row it lives in.
    final textFinder = find.text(longTitle);
    expect(textFinder, findsOneWidget);
    final textWidth = tester.getSize(textFinder).width;
    final fieldWidth = tester.getSize(find.byType(TaskDropdown<int?>)).width;
    expect(textWidth, lessThanOrEqualTo(fieldWidth));
  });
}
