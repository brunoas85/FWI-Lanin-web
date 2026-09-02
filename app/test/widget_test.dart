import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fwi_lanin/data/api_config.dart';
import 'package:fwi_lanin/main.dart';
import 'package:fwi_lanin/theme/app_colors.dart';

void main() {
  testWidgets('la app arranca y aplica el tema', (WidgetTester tester) async {
    await tester.pumpWidget(FwiLaninApp(apiConfig: ApiConfig()));
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.primary, AppColors.primary);
  });
}
