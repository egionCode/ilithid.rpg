import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/combat/presentation/widgets/custom_log_dialog.dart';
import 'package:mocktail/mocktail.dart';

class MockTablesDB extends Mock implements TablesDB {}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  FakeAuthNotifier(this._initialState);
  @override
  AuthState build() => _initialState;
}

models.Row _buildRow(Map<String, dynamic> data) {
  return models.Row.fromMap({
    r'$id': 'row-id',
    r'$sequence': 1,
    r'$tableId': 'logs',
    r'$databaseId': 'main',
    r'$createdAt': '',
    r'$updatedAt': '',
    r'$permissions': <String>[],
    ...data,
  });
}

void main() {
  late MockTablesDB mockTablesDb;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockTablesDb = MockTablesDB();
    when(
      () => mockTablesDb.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _buildRow({}));
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
        authProvider.overrideWith(
          () => FakeAuthNotifier(
            const AuthState(
              status: AuthStatus.authenticated,
              displayName: 'Mestre Victor',
            ),
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: CustomLogDialog(sessionId: 'session-1')),
      ),
    );
  }

  testWidgets('submits the message and shows a success snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());

    await tester.enterText(
      find.byKey(const Key('custom_log_message_field')),
      'O grupo encontrou uma armadilha.',
    );
    await tester.tap(find.byKey(const Key('custom_log_submit_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final captured = verify(
      () => mockTablesDb.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: captureAny(named: 'data'),
      ),
    ).captured;

    final data = Map<String, dynamic>.from(captured.single as Map);
    expect(data['message'], 'O grupo encontrou uma armadilha.');
    expect(data['actorName'], 'Mestre Victor');
    expect(data['type'], 'custom');
    expect(find.text('Nota adicionada ao log!'), findsOneWidget);
  });

  testWidgets('does nothing when the message is empty', (tester) async {
    await tester.pumpWidget(buildTestWidget());

    await tester.tap(find.byKey(const Key('custom_log_submit_button')));
    await tester.pump();

    verifyNever(
      () => mockTablesDb.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    );
  });
}
