import "package:cake_wallet/di.dart";
import "package:cake_wallet/store/app_store.dart";
import "package:cake_wallet/new-ui/pages/receive_page.dart";
import "package:cake_wallet/new-ui/widgets/receive_page/receive_label_modal.dart";
import "package:cake_wallet/new-ui/widgets/receive_page/receive_label_widget.dart";
import "package:cake_wallet/generated/i18n.dart";
import "package:cw_core/wallet_type.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter/material.dart";
import "package:integration_test/integration_test.dart";

import "../../core/app_launcher.dart";
import "../../flows/onboarding_flows.dart";
import "../../flows/auth_flows.dart";
import "../../robots/home_page_robot.dart";
import "../../robots/new_dashboard_robot.dart";
import "../../robots/new_receive_page_robot.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  integrationTest("Monero Receive and Label close correctly on three visits", (tester) async {
    final home = HomePageRobot(tester);
    final receive = NewReceivePageRobot(tester);
    await AppLauncher(tester).launchApp(testKey: "receive_memory_smoke");
    await AuthFlows(tester).authenticateWithPin(required: false);
    if (getIt.get<AppStore>().wallet == null) {
      await OnboardingFlows(tester).createFirstWallet(WalletType.monero);
    }
    await NewDashboardRobot(tester).isDisplayed();
    await home.isDisplayed();
    final address = getIt.get<AppStore>().wallet!.walletAddresses.address;
    expect(address, isNotEmpty);
    for (var visit = 1; visit <= 3; visit++) {
      await home.openReceiveSheet();
      await receive.isDisplayed();
      await receive.confirmAddressMatches(address);
      final labelButton = find.text(S.current.label).hitTestable();
      if (tester.any(labelButton)) {
        await tester.tap(labelButton.last);
      } else {
        await tester.tap(find.byType(ReceiveLabelWidget).hitTestable().first);
      }
      await receive.pumpUntilFound(find.byType(ReceiveLabelModal));
      await tester.tap(find
          .descendant(
            of: find.byType(ReceiveLabelModal),
            matching: find.byIcon(Icons.close),
          )
          .hitTestable()
          .first);
      expect(await receive.pumpUntil(() => !tester.any(find.byType(ReceiveLabelModal))), true);
      await tester.tap(find
          .descendant(
            of: find.byType(NewReceivePage),
            matching: find.byIcon(Icons.close),
          )
          .hitTestable()
          .first);
      expect(await receive.pumpUntil(() => !tester.any(find.byType(NewReceivePage))), true);
      await home.isDisplayed();
      expect(find.byType(NewReceivePage), findsNothing);
      tester.printToConsole("RECEIVE_SMOKE: visit $visit returned to dashboard");
    }
  });
}
