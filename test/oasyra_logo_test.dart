import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasyara_1/shared/widgets/oasyra_logo.dart';

void main() {
  testWidgets('OasyraLogo renders full logo variant correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OasyraLogo(
            variant: OasyraLogoVariant.full,
            width: 150,
            height: 150,
          ),
        ),
      ),
    );

    expect(find.byType(OasyraLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final imageWidget = tester.widget<Image>(find.byType(Image));
    expect((imageWidget.image as AssetImage).assetName, 'assets/images/oasyra_brand_purple.png');
    expect(imageWidget.width, 150);
    expect(imageWidget.height, 150);
  });

  testWidgets('OasyraLogo renders symbol variant correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OasyraLogo(
            variant: OasyraLogoVariant.symbol,
            width: 48,
            height: 48,
          ),
        ),
      ),
    );

    expect(find.byType(OasyraLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final imageWidget = tester.widget<Image>(find.byType(Image));
    expect((imageWidget.image as AssetImage).assetName, 'assets/images/oasyra_symbol.png');
    expect(imageWidget.width, 48);
    expect(imageWidget.height, 48);
  });
}
