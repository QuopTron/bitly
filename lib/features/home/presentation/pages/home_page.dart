import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../domain/entities/home_section.dart';
import '../tabs/recent_tab.dart';
import '../tabs/quick_actions_tab.dart';
import '../tabs/discover_tab.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/section_header.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: const HomeAppBar(),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.isLoading && state.sections.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)),
            );
          }
          if (state.error != null && state.sections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error!, style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<HomeBloc>().add(const LoadHome()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<HomeBloc>().add(const RefreshHome());
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                for (final section in state.sections)
                  _buildSection(context, section),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(BuildContext context, HomeSection section) {
    if (section.type == SectionType.recent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: section.title, onSeeAll: () {}),
          RecentTab(items: section.items),
        ],
      );
    } else if (section.type == SectionType.quickActions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: section.title),
          QuickActionsTab(items: section.items),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: section.title),
          DiscoverTab(items: section.items),
        ],
      );
    }
  }
}
