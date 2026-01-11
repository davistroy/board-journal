import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/providers/repository_providers.dart';

void main() {
  group('Repository Providers', () {
    group('Base Repository Providers', () {
      test('dailyEntryRepositoryProvider is a Provider', () {
        expect(dailyEntryRepositoryProvider, isA<Provider<DailyEntryRepository>>());
      });

      test('weeklyBriefRepositoryProvider is a Provider', () {
        expect(weeklyBriefRepositoryProvider, isA<Provider<WeeklyBriefRepository>>());
      });

      test('problemRepositoryProvider is a Provider', () {
        expect(problemRepositoryProvider, isA<Provider<ProblemRepository>>());
      });

      test('boardMemberRepositoryProvider is a Provider', () {
        expect(boardMemberRepositoryProvider, isA<Provider<BoardMemberRepository>>());
      });

      test('governanceSessionRepositoryProvider is a Provider', () {
        expect(governanceSessionRepositoryProvider, isA<Provider<GovernanceSessionRepository>>());
      });

      test('betRepositoryProvider is a Provider', () {
        expect(betRepositoryProvider, isA<Provider<BetRepository>>());
      });

      test('evidenceItemRepositoryProvider is a Provider', () {
        expect(evidenceItemRepositoryProvider, isA<Provider<EvidenceItemRepository>>());
      });

      test('portfolioVersionRepositoryProvider is a Provider', () {
        expect(portfolioVersionRepositoryProvider, isA<Provider<PortfolioVersionRepository>>());
      });

      test('portfolioHealthRepositoryProvider is a Provider', () {
        expect(portfolioHealthRepositoryProvider, isA<Provider<PortfolioHealthRepository>>());
      });

      test('reSetupTriggerRepositoryProvider is a Provider', () {
        expect(reSetupTriggerRepositoryProvider, isA<Provider<ReSetupTriggerRepository>>());
      });

      test('userPreferencesRepositoryProvider is a Provider', () {
        expect(userPreferencesRepositoryProvider, isA<Provider<UserPreferencesRepository>>());
      });
    });

    group('Stream Providers', () {
      test('dailyEntriesStreamProvider is a StreamProvider', () {
        expect(dailyEntriesStreamProvider, isA<StreamProvider<List<DailyEntry>>>());
      });

      test('weeklyBriefsStreamProvider is a StreamProvider', () {
        expect(weeklyBriefsStreamProvider, isA<StreamProvider<List<WeeklyBrief>>>());
      });

      test('problemsStreamProvider is a StreamProvider', () {
        expect(problemsStreamProvider, isA<StreamProvider<List<Problem>>>());
      });

      test('boardMembersStreamProvider is a StreamProvider', () {
        expect(boardMembersStreamProvider, isA<StreamProvider<List<BoardMember>>>());
      });

      test('activeBoardMembersStreamProvider is a StreamProvider', () {
        expect(activeBoardMembersStreamProvider, isA<StreamProvider<List<BoardMember>>>());
      });

      test('governanceSessionsStreamProvider is a StreamProvider', () {
        expect(governanceSessionsStreamProvider, isA<StreamProvider<List<GovernanceSession>>>());
      });

      test('completedSessionsStreamProvider is a StreamProvider', () {
        expect(completedSessionsStreamProvider, isA<StreamProvider<List<GovernanceSession>>>());
      });

      test('betsStreamProvider is a StreamProvider', () {
        expect(betsStreamProvider, isA<StreamProvider<List<Bet>>>());
      });

      test('openBetsStreamProvider is a StreamProvider', () {
        expect(openBetsStreamProvider, isA<StreamProvider<List<Bet>>>());
      });

      test('portfolioVersionsStreamProvider is a StreamProvider', () {
        expect(portfolioVersionsStreamProvider, isA<StreamProvider<List<PortfolioVersion>>>());
      });

      test('currentPortfolioVersionStreamProvider is a StreamProvider', () {
        expect(currentPortfolioVersionStreamProvider, isA<StreamProvider<PortfolioVersion?>>());
      });

      test('portfolioHealthStreamProvider is a StreamProvider', () {
        expect(portfolioHealthStreamProvider, isA<StreamProvider<PortfolioHealth?>>());
      });

      test('reSetupTriggersStreamProvider is a StreamProvider', () {
        expect(reSetupTriggersStreamProvider, isA<StreamProvider<List<ReSetupTrigger>>>());
      });

      test('metTriggersStreamProvider is a StreamProvider', () {
        expect(metTriggersStreamProvider, isA<StreamProvider<List<ReSetupTrigger>>>());
      });

      test('userPreferencesStreamProvider is a StreamProvider', () {
        expect(userPreferencesStreamProvider, isA<StreamProvider<UserPreference?>>());
      });
    });

    group('Future Providers', () {
      test('hasPortfolioProvider is a FutureProvider', () {
        expect(hasPortfolioProvider, isA<FutureProvider<bool>>());
      });

      test('isOnboardingCompletedProvider is a FutureProvider', () {
        expect(isOnboardingCompletedProvider, isA<FutureProvider<bool>>());
      });

      test('shouldShowSetupPromptProvider is a FutureProvider', () {
        expect(shouldShowSetupPromptProvider, isA<FutureProvider<bool>>());
      });

      test('totalEntryCountProvider is a FutureProvider', () {
        expect(totalEntryCountProvider, isA<FutureProvider<int>>());
      });

      test('hasAppreciatingProblemsProvider is a FutureProvider', () {
        expect(hasAppreciatingProblemsProvider, isA<FutureProvider<bool>>());
      });

      test('betStatsProvider is a FutureProvider', () {
        expect(betStatsProvider, isA<FutureProvider<Map<String, int>>>());
      });

      test('portfolioHealthTrendProvider is a FutureProvider', () {
        expect(portfolioHealthTrendProvider, isA<FutureProvider<String?>>());
      });

      test('latestBriefProvider is a FutureProvider', () {
        expect(latestBriefProvider, isA<FutureProvider<WeeklyBrief?>>());
      });
    });

    group('Family Providers', () {
      test('entryByIdProvider is a FutureProvider.family', () {
        expect(entryByIdProvider, isA<FutureProviderFamily<DailyEntry?, String>>());
      });

      test('briefByIdProvider is a FutureProvider.family', () {
        expect(briefByIdProvider, isA<FutureProviderFamily<WeeklyBrief?, String>>());
      });

      test('entriesForWeekProvider is a FutureProvider.family', () {
        expect(entriesForWeekProvider, isA<FutureProviderFamily<List<DailyEntry>, DateTime>>());
      });

      test('remainingRegenerationsProvider is a FutureProvider.family', () {
        expect(remainingRegenerationsProvider, isA<FutureProviderFamily<int, String>>());
      });

      test('watchBriefByIdProvider is a StreamProvider.family', () {
        expect(watchBriefByIdProvider, isA<StreamProviderFamily<WeeklyBrief?, String>>());
      });
    });
  });
}
