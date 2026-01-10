import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'database_provider.dart';

// ==================
// Repository Providers
// ==================

/// Provider for DailyEntryRepository.
final dailyEntryRepositoryProvider = Provider<DailyEntryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DailyEntryRepository(db);
});

/// Provider for WeeklyBriefRepository.
final weeklyBriefRepositoryProvider = Provider<WeeklyBriefRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return WeeklyBriefRepository(db);
});

/// Provider for ProblemRepository.
final problemRepositoryProvider = Provider<ProblemRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProblemRepository(db);
});

/// Provider for BoardMemberRepository.
final boardMemberRepositoryProvider = Provider<BoardMemberRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BoardMemberRepository(db);
});

/// Provider for GovernanceSessionRepository.
final governanceSessionRepositoryProvider = Provider<GovernanceSessionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return GovernanceSessionRepository(db);
});

/// Provider for BetRepository.
final betRepositoryProvider = Provider<BetRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BetRepository(db);
});

/// Provider for EvidenceItemRepository.
final evidenceItemRepositoryProvider = Provider<EvidenceItemRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return EvidenceItemRepository(db);
});

/// Provider for PortfolioVersionRepository.
final portfolioVersionRepositoryProvider = Provider<PortfolioVersionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PortfolioVersionRepository(db);
});

/// Provider for PortfolioHealthRepository.
final portfolioHealthRepositoryProvider = Provider<PortfolioHealthRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PortfolioHealthRepository(db);
});

/// Provider for ReSetupTriggerRepository.
final reSetupTriggerRepositoryProvider = Provider<ReSetupTriggerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ReSetupTriggerRepository(db);
});

/// Provider for UserPreferencesRepository.
final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserPreferencesRepository(db);
});

// ==================
// Stream Providers for Reactive UI
// ==================

/// Stream provider for all daily entries.
final dailyEntriesStreamProvider = StreamProvider<List<DailyEntry>>((ref) {
  final repo = ref.watch(dailyEntryRepositoryProvider);
  return repo.watchAll();
});

/// Stream provider for all weekly briefs.
final weeklyBriefsStreamProvider = StreamProvider<List<WeeklyBrief>>((ref) {
  final repo = ref.watch(weeklyBriefRepositoryProvider);
  return repo.watchAll();
});

/// Stream provider for all problems.
final problemsStreamProvider = StreamProvider<List<Problem>>((ref) {
  final repo = ref.watch(problemRepositoryProvider);
  return repo.watchAll();
});

/// Stream provider for all board members.
final boardMembersStreamProvider = StreamProvider<List<BoardMember>>((ref) {
  final repo = ref.watch(boardMemberRepositoryProvider);
  return repo.watchAll();
});

/// Stream provider for active board members.
final activeBoardMembersStreamProvider = StreamProvider<List<BoardMember>>((ref) {
  final repo = ref.watch(boardMemberRepositoryProvider);
  return repo.watchActive();
});

/// Stream provider for all governance sessions.
final governanceSessionsStreamProvider = StreamProvider<List<GovernanceSession>>((ref) {
  final repo = ref.watch(governanceSessionRepositoryProvider);
  return repo.watchAll();
});

/// Stream provider for completed governance sessions.
final completedSessionsStreamProvider = StreamProvider<List<GovernanceSession>>((ref) {
  final repo = ref.watch(governanceSessionRepositoryProvider);
  return repo.watchCompleted();
});

/// Stream provider for all bets.
final betsStreamProvider = StreamProvider<List<Bet>>((ref) {
  final repo = ref.watch(betRepositoryProvider);
  return repo.watchAll();
});

/// Stream provider for open bets.
final openBetsStreamProvider = StreamProvider<List<Bet>>((ref) {
  final repo = ref.watch(betRepositoryProvider);
  return repo.watchOpen();
});

/// Stream provider for portfolio versions.
final portfolioVersionsStreamProvider = StreamProvider<List<PortfolioVersion>>((ref) {
  final repo = ref.watch(portfolioVersionRepositoryProvider);
  return repo.watchAll();
});

/// Stream provider for current portfolio version.
final currentPortfolioVersionStreamProvider = StreamProvider<PortfolioVersion?>((ref) {
  final repo = ref.watch(portfolioVersionRepositoryProvider);
  return repo.watchCurrent();
});

/// Stream provider for current portfolio health.
final portfolioHealthStreamProvider = StreamProvider<PortfolioHealth?>((ref) {
  final repo = ref.watch(portfolioHealthRepositoryProvider);
  return repo.watchCurrent();
});

/// Stream provider for re-setup triggers.
final reSetupTriggersStreamProvider = StreamProvider<List<ReSetupTrigger>>((ref) {
  final repo = ref.watch(reSetupTriggerRepositoryProvider);
  return repo.watchAll();
});

/// Stream provider for met re-setup triggers.
final metTriggersStreamProvider = StreamProvider<List<ReSetupTrigger>>((ref) {
  final repo = ref.watch(reSetupTriggerRepositoryProvider);
  return repo.watchMet();
});

/// Stream provider for user preferences.
final userPreferencesStreamProvider = StreamProvider<UserPreference?>((ref) {
  final repo = ref.watch(userPreferencesRepositoryProvider);
  return repo.watch();
});

// ==================
// Future Providers for One-time Data Fetches
// ==================

/// Future provider for checking if portfolio exists.
final hasPortfolioProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(portfolioVersionRepositoryProvider);
  return repo.hasPortfolio();
});

/// Future provider for checking if onboarding is completed.
final isOnboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(userPreferencesRepositoryProvider);
  return repo.isOnboardingCompleted();
});

/// Future provider for checking if setup prompt should show.
final shouldShowSetupPromptProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(userPreferencesRepositoryProvider);
  return repo.shouldShowSetupPrompt();
});

/// Future provider for getting total entry count.
final totalEntryCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(dailyEntryRepositoryProvider);
  return repo.getTotalEntryCount();
});

/// Future provider for checking if growth roles should be active.
final hasAppreciatingProblemsProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(problemRepositoryProvider);
  return repo.hasAppreciatingProblems();
});

/// Future provider for getting bet evaluation stats.
final betStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(betRepositoryProvider);
  return repo.getEvaluationStats();
});

/// Future provider for getting portfolio health trend.
final portfolioHealthTrendProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(portfolioHealthRepositoryProvider);
  return repo.getTrend();
});
