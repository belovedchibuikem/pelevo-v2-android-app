import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/share/pelevo_native_share.dart';

void main() {
  testWidgets('share origin uses the widget bounds when laid out', (
    tester,
  ) async {
    late Rect origin;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              height: 40,
              child: Builder(
                builder: (context) {
                  return GestureDetector(
                    onTap: () => origin = pelevoShareOrigin(context),
                    child: const Text('Share'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    expect(origin.width, 80);
    expect(origin.height, 40);
  });

  test('AirDrop is only advertised on iOS', () {
    expect(pelevoAirDropAvailable, isFalse);
  });
}
