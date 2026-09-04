import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_body/features/account/profile_screen.dart';
import 'package:flutter_body/features/custom_exercise/patient_assigned_exercise_list_page.dart';
import 'package:flutter_body/features/home/home_screen.dart';
import 'package:flutter_body/features/plan/plan_screen.dart';
import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_body/services/history_repository.dart';
import 'package:flutter_body/services/history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MainTab and PageView use the visual UI page order',
      (tester) async {
    final harness = await _pumpHome(tester);

    expect(MainTab.values, [
      MainTab.home,
      MainTab.stats,
      MainTab.plan,
      MainTab.chat,
      MainTab.profile,
    ]);
    expect(
      MainTab.values.map((tab) => tab.legacyRemoteIndex),
      [0, 3, 1, 2, 4],
    );
    for (final tab in MainTab.values) {
      expect(MainTab.fromUiIndex(tab.uiIndex), tab);
      expect(MainTab.fromLegacyRemoteIndex(tab.legacyRemoteIndex), tab);
    }

    final pageView = _mainPageView(tester);
    expect(pageView.controller!.initialPage, MainTab.home.uiIndex);
    expect(pageView.controller!.keepPage, isTrue);
    expect(
        pageView.childrenDelegate.estimatedChildCount, MainTab.values.length);
    _expectSelectedTab(tester, MainTab.home);

    await harness.dispose(tester);
  });

  testWidgets('患者首頁可進入統一的我的復健動作', (tester) async {
    final harness = await _pumpHome(tester);
    final entry = find.byKey(const Key('open-patient-assigned-exercises'));

    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(PatientAssignedExerciseListPage), findsOneWidget);

    await harness.dispose(tester);
  });

  testWidgets('Bottom tap animates adjacent, jumps distant, and haptics once',
      (tester) async {
    final harness = await _pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey('main-tab-stats')));
    await tester.pumpAndSettle();
    _expectSelectedTab(tester, MainTab.stats);
    expect(harness.hapticCount, 1);
    expect(harness.sentCommands, [
      {'type': 'NAVIGATE_TO_TAB', 'index': 3},
    ]);

    await tester.tap(find.byKey(const ValueKey('main-tab-profile')));
    await tester.pump();
    _expectSelectedTab(tester, MainTab.profile);
    expect(harness.hapticCount, 2);
    expect(harness.sentCommands.last, {
      'type': 'NAVIGATE_TO_TAB',
      'index': 4,
    });

    final pageViewBeforeRetap = _mainPageView(tester);
    await tester.tap(find.byKey(const ValueKey('main-tab-profile')));
    await tester.pump();
    expect(identical(_mainPageView(tester), pageViewBeforeRetap), isTrue);
    expect(harness.hapticCount, 2);
    expect(harness.sentCommands.length, 2);

    await harness.dispose(tester);
  });

  testWidgets('Swipe syncs tabs at settle, handles reverse and both edges',
      (tester) async {
    final harness = await _pumpHome(tester);
    final pages = find.byKey(const ValueKey('main-tab-pages'));

    await tester.drag(pages, const Offset(-600, 0));
    await tester.pumpAndSettle();
    _expectSelectedTab(tester, MainTab.stats);
    expect(harness.hapticCount, 1);
    expect(harness.sentCommands.last['index'], 3);

    await tester.drag(pages, const Offset(-600, 0));
    await tester.pumpAndSettle();
    _expectSelectedTab(tester, MainTab.plan);
    expect(harness.hapticCount, 2);
    expect(harness.sentCommands.last['index'], 1);

    await tester.drag(pages, const Offset(600, 0));
    await tester.pumpAndSettle();
    _expectSelectedTab(tester, MainTab.stats);
    expect(harness.hapticCount, 3);

    harness.remoteCommands.add({
      'type': 'NAVIGATE_TO_TAB',
      'index': MainTab.home.legacyRemoteIndex,
    });
    await tester.pump();
    harness.clearFeedback();

    await tester.drag(pages, const Offset(600, 0));
    await tester.pumpAndSettle();
    _expectSelectedTab(tester, MainTab.home);
    expect(harness.hapticCount, 0);
    expect(harness.sentCommands, isEmpty);

    harness.remoteCommands.add({
      'type': 'NAVIGATE_TO_TAB',
      'index': MainTab.profile.legacyRemoteIndex,
    });
    await tester.pump();
    harness.clearFeedback();

    await tester.drag(pages, const Offset(-600, 0));
    await tester.pumpAndSettle();
    _expectSelectedTab(tester, MainTab.profile);
    expect(harness.hapticCount, 0);
    expect(harness.sentCommands, isEmpty);

    await harness.dispose(tester);
  });

  testWidgets('Incomplete swipe snaps back without haptic or broadcast',
      (tester) async {
    final harness = await _pumpHome(tester);

    await tester.timedDrag(
      find.byKey(const ValueKey('main-tab-pages')),
      const Offset(-80, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    _expectSelectedTab(tester, MainTab.home);
    expect(harness.hapticCount, 0);
    expect(harness.sentCommands, isEmpty);

    await harness.dispose(tester);
  });

  testWidgets('Remote mapping has no echo or haptic and POP_SCREEN is safe',
      (tester) async {
    final harness = await _pumpHome(tester);

    const legacyToUiIndex = <int, int>{
      0: 0,
      1: 2,
      2: 3,
      3: 1,
      4: 4,
    };

    for (final entry in legacyToUiIndex.entries) {
      harness.remoteCommands.add({
        'type': 'NAVIGATE_TO_TAB',
        'index': entry.key,
      });
      await tester.pump();
      expect(_pagePosition(tester), closeTo(entry.value, 0.01));
    }
    expect(harness.sentCommands, isEmpty);
    expect(harness.hapticCount, 0);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('子頁面'))),
    );
    await tester.pumpAndSettle();

    harness.remoteCommands.add({'type': 'POP_SCREEN'});
    await tester.pumpAndSettle();
    expect(find.text('子頁面'), findsNothing);
    _expectSelectedTab(tester, MainTab.profile);

    harness.remoteCommands.add({'type': 'POP_SCREEN'});
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(harness.sentCommands, isEmpty);
    expect(harness.hapticCount, 0);

    await harness.dispose(tester);
  });

  testWidgets('PageView preserves page elements and Home scroll position',
      (tester) async {
    final harness = await _pumpHome(tester);
    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );

    await tester.drag(verticalScrollable.first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final homeScrollState =
        tester.state<ScrollableState>(verticalScrollable.first);
    final homeOffset = homeScrollState.position.pixels;
    expect(homeOffset, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('main-tab-plan')));
    await tester.pumpAndSettle();
    final planElement =
        find.byType(PlanScreen, skipOffstage: false).evaluate().single;

    await tester.tap(find.byKey(const ValueKey('main-tab-profile')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('main-tab-plan')));
    await tester.pumpAndSettle();
    expect(
      identical(
        find.byType(PlanScreen, skipOffstage: false).evaluate().single,
        planElement,
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('main-tab-home')));
    await tester.pumpAndSettle();
    final restoredHomeScroll =
        tester.state<ScrollableState>(verticalScrollable.first);
    expect(restoredHomeScroll.position.pixels, closeTo(homeOffset, 0.01));

    await harness.dispose(tester);
  });

  testWidgets('Page switches do not restart Home or Stats history loads',
      (tester) async {
    final harness = await _pumpHome(tester);

    final initialReads = harness.historyRepository.getHistoryCalls;
    expect(initialReads, greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    expect(harness.historyRepository.getHistoryCalls, initialReads);

    await tester.tap(find.byKey(const ValueKey('main-tab-stats')));
    await tester.pumpAndSettle();
    final readsAfterStatsLoad = harness.historyRepository.getHistoryCalls;
    expect(readsAfterStatsLoad, greaterThanOrEqualTo(initialReads));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const ValueKey('main-tab-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('main-tab-stats')));
    await tester.pumpAndSettle();
    expect(harness.historyRepository.getHistoryCalls, readsAfterStatsLoad);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await harness.dispose(tester);
  });
}

PageView _mainPageView(WidgetTester tester) {
  return tester.widget<PageView>(
    find.byKey(const ValueKey('main-tab-pages')),
  );
}

double _pagePosition(WidgetTester tester) {
  return _mainPageView(tester).controller!.page!;
}

void _expectSelectedTab(WidgetTester tester, MainTab tab) {
  expect(_pagePosition(tester), closeTo(tab.uiIndex, 0.01));
  for (final candidate in MainTab.values) {
    final label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('main-tab-${candidate.name}')),
        matching: find.text(candidate.label),
      ),
    );
    expect(
      label.style!.color,
      candidate == tab ? const Color(0xFF4A65FF) : const Color(0xFF9CA3AF),
    );
  }
}

Future<_HomeHarness> _pumpHome(WidgetTester tester) async {
  final remoteCommands = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  final sentCommands = <Map<String, dynamic>>[];
  final hapticSpy = _HapticSpy();
  final historyRepository = _CountingHistoryRepository();
  final historyService = HistoryService.withRepository(historyRepository);

  await tester.pumpWidget(
    ChangeNotifierProvider<HistoryService>.value(
      value: historyService,
      child: MaterialApp(
        home: HomeScreen(
          remoteCommandStream: remoteCommands.stream,
          onSendNavigationCommand: sentCommands.add,
          onNavigationHaptic: hapticSpy.call,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _HomeHarness(
    remoteCommands: remoteCommands,
    sentCommands: sentCommands,
    hapticSpy: hapticSpy,
    historyService: historyService,
    historyRepository: historyRepository,
  );
}

class _HomeHarness {
  const _HomeHarness({
    required this.remoteCommands,
    required this.sentCommands,
    required this.hapticSpy,
    required this.historyService,
    required this.historyRepository,
  });

  final StreamController<Map<String, dynamic>> remoteCommands;
  final List<Map<String, dynamic>> sentCommands;
  final _HapticSpy hapticSpy;
  final HistoryService historyService;
  final _CountingHistoryRepository historyRepository;

  int get hapticCount => hapticSpy.count;

  void clearFeedback() {
    sentCommands.clear();
    hapticSpy.count = 0;
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await remoteCommands.close();
    historyService.dispose();
  }
}

class _HapticSpy {
  int count = 0;

  void call() {
    count++;
  }
}

class _CountingHistoryRepository implements HistoryRepository {
  int getHistoryCalls = 0;

  @override
  Future<List<TrainingRecord>> getHistory() async {
    getHistoryCalls++;
    return const [];
  }

  @override
  Future<void> saveRecord(TrainingRecord record) async {}

  @override
  Future<void> updateLastRecordsVideoPath(
    int count,
    String? videoPath,
  ) async {}

  @override
  Future<void> removeByTimestamp(String timestamp) async {}

  @override
  Future<void> clearHistory() async {}

  @override
  Future<List<TrainingRecord>> getUnsyncedRecords() async => const [];

  @override
  Future<void> markAsSynced(String timestamp) async {}
}
