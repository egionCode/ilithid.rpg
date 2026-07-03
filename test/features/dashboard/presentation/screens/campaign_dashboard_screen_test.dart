import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/dashboard/presentation/screens/campaign_dashboard_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets(
    'CampaignDashboardScreen renders correctly and shows share bottom sheet',
    (tester) async {
      const campaignHexId = 'abc12345';

      // 1. Build the CampaignDashboardScreen in a MaterialApp
      await tester.pumpWidget(
        const MaterialApp(home: CampaignDashboardScreen(hexId: campaignHexId)),
      );

      // 2. Verify dashboard initial rendering
      expect(find.text('Campaign Dashboard'), findsWidgets);
      expect(find.text(campaignHexId.toUpperCase()), findsOneWidget);
      expect(find.byKey(const Key('dashboard_share_button')), findsOneWidget);

      // 3. Tap the "Compartilhar Campanha" button
      await tester.tap(find.byKey(const Key('dashboard_share_button')));
      await tester
          .pumpAndSettle(); // Wait for bottom sheet animation to complete

      // 4. Verify bottom sheet content
      expect(find.text('Compartilhar Campanha'), findsWidgets);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byKey(const Key('copy_code_button')), findsOneWidget);
      expect(find.byKey(const Key('copy_link_button')), findsOneWidget);
      expect(find.byKey(const Key('native_share_button')), findsOneWidget);
    },
  );
}
