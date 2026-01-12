import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/providers.dart';
import '../../../router/router.dart';
import 'widgets/widgets.dart';

/// Hub screen for career governance features.
///
/// Per PRD Section 5.5, provides tabs for:
/// - Quick Version (15-min audit)
/// - Setup (Portfolio creation)
/// - Quarterly (Full report)
/// - Board (Roles + personas)
class GovernanceHubScreen extends ConsumerWidget {
  const GovernanceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPortfolio = ref.watch(hasPortfolioProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Governance'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.home),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Quick'),
              Tab(text: 'Setup'),
              Tab(text: 'Quarterly'),
              Tab(text: 'Board'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Quick Version tab
            const QuickVersionTab(),
            // Setup tab
            SetupTab(hasPortfolio: hasPortfolio),
            // Quarterly tab
            QuarterlyTab(hasPortfolio: hasPortfolio),
            // Board tab
            BoardTab(hasPortfolio: hasPortfolio),
          ],
        ),
      ),
    );
  }
}
