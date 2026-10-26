import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pmanager/app.dart';
import 'package:pmanager/application/vault_controller.dart';
import 'package:pmanager/domain/vault_entry.dart';

import 'support/memory_storage.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Sesame')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('First launch explains recovery and requires acknowledgement', (
    tester,
  ) async {
    final vault = VaultController(MemoryStorage());
    await vault.initialize();
    await tester.pumpWidget(SesameApp(controller: vault));
    expect(find.text('Vos secrets.\nBien gardés.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Créer mon coffre'),
    );
    expect(button.onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Créer mon coffre'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    vault.dispose();
  });

  testWidgets('Storage read failure cannot create or overwrite a vault', (
    tester,
  ) async {
    final vault = VaultController(MemoryStorage()..failRead = true);
    await vault.initialize();
    await tester.pumpWidget(SesameApp(controller: vault));
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
    vault.dispose();
  });

  testWidgets('Welcome layout at mobile width', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vault = VaultController(MemoryStorage());
    await vault.initialize();
    await tester.pumpWidget(SesameApp(controller: vault));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/welcome.png'),
    );
    await tester.pumpWidget(const SizedBox());
    vault.dispose();
  });

  testWidgets('Vault search, favorites, editor and lifecycle lock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vault = VaultController(MemoryStorage());
    await tester.runAsync(() async {
      await vault.initialize();
      await vault.open(
        'vergers nuages cuivre lanternes 47',
        confirmation: 'vergers nuages cuivre lanternes 47',
      );
      await vault.saveEntries([
        VaultEntry(
          id: '1',
          title: 'Google',
          username: 'bonjour@exemple.fr',
          password: 'UniquePourGoogle!573',
          favorite: true,
          updatedAt: DateTime.utc(2026, 10, 26),
        ),
        VaultEntry(
          id: '2',
          title: 'Notion',
          username: 'Mon espace de travail',
          password: 'UniquePourNotion!428',
          category: 'Travail',
          updatedAt: DateTime.utc(2026, 10, 26),
        ),
        VaultEntry(
          id: '3',
          title: 'Revolut',
          username: 'Compte personnel',
          password: 'UniquePourRevolut!63',
          category: 'Finance',
          updatedAt: DateTime.utc(2026, 10, 26),
        ),
      ]);
    });
    await tester.pumpWidget(SesameApp(controller: vault));
    await tester.pumpAndSettle();
    expect(find.text('Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vault.png'),
    );
    await tester.enterText(find.byType(TextField), 'notion');
    await tester.pumpAndSettle();
    expect(find.text('Google'), findsNothing);
    expect(find.text('Notion'), findsOneWidget);
    await tester.tap(find.text('Ajouter un identifiant'));
    await tester.pumpAndSettle();
    expect(find.text('Un nouveau secret.'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(vault.unlocked, isFalse);
    expect(find.text('Un nouveau secret.'), findsNothing);
    expect(vault.entries, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    vault.dispose();
  });
}
