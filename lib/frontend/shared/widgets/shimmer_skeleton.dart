import 'package:flutter/material.dart';

/// Animated shimmer skeleton — a pulsing gradient overlay on a placeholder
/// shape. Use instead of CircularProgressIndicator for a premium loading feel.
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final highlight = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A full-page shimmer layout for feed / detail loading.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final highlight = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final isTrack = index % 3 != 2;
        return _ShimmerRow(
          isTrack: isTrack,
          base: base,
          highlight: highlight,
        );
      },
    );
  }
}

class _ShimmerRow extends StatefulWidget {
  final bool isTrack;
  final Color base;
  final Color highlight;

  const _ShimmerRow({required this.isTrack, required this.base, required this.highlight});

  @override
  State<_ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<_ShimmerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.isTrack ? 72.0 : 220.0;
    final br = widget.isTrack ? 18.0 : 16.0;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          height: h,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(br),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [widget.base, widget.highlight, widget.base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A centered full-page shimmer for detail pages (album, playlist, artist).
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final highlight = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShimmerCircle(size: 180, base: base, highlight: highlight),
          const SizedBox(height: 24),
          _ShimmerRow(isTrack: false, base: base, highlight: highlight),
        ],
      ),
    );
  }
}

class _ShimmerCircle extends StatefulWidget {
  final double size;
  final Color base;
  final Color highlight;

  const _ShimmerCircle({required this.size, required this.base, required this.highlight});

  @override
  State<_ShimmerCircle> createState() => _ShimmerCircleState();
}

class _ShimmerCircleState extends State<_ShimmerCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [widget.base, widget.highlight, widget.base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Search-specific skeleton that matches the layout of actual search results.
/// Shows track skeletons for tracks, grid skeletons for other categories.
class SearchSkeleton extends StatelessWidget {
  final String? selectedType;

  const SearchSkeleton({super.key, this.selectedType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final highlight = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

    // Default view: show track skeletons + grid skeletons
    if (selectedType == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Section header skeleton
          _ShimmerSectionHeader(base: base, highlight: highlight),
          const SizedBox(height: 8),
          // Track skeletons
          ...List.generate(4, (_) => _ShimmerTrackCard(base: base, highlight: highlight)),
          const SizedBox(height: 16),
          // Grid section header skeleton
          _ShimmerSectionHeader(base: base, highlight: highlight),
          const SizedBox(height: 8),
          // Grid skeleton
          _ShimmerGrid(base: base, highlight: highlight),
        ],
      );
    }

    // Tracks only: show track card skeletons
    if (selectedType == 'tracks') {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(6, (_) => _ShimmerTrackCard(base: base, highlight: highlight)),
      );
    }

    // Other categories: show grid skeletons
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ShimmerGrid(base: base, highlight: highlight),
      ],
    );
  }
}

/// Track card skeleton that matches TrackCard layout.
class _ShimmerTrackCard extends StatefulWidget {
  final Color base;
  final Color highlight;

  const _ShimmerTrackCard({required this.base, required this.highlight});

  @override
  State<_ShimmerTrackCard> createState() => _ShimmerTrackCardState();
}

class _ShimmerTrackCardState extends State<_ShimmerTrackCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          height: 80,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [widget.base, widget.highlight, widget.base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Section header skeleton.
class _ShimmerSectionHeader extends StatefulWidget {
  final Color base;
  final Color highlight;

  const _ShimmerSectionHeader({required this.base, required this.highlight});

  @override
  State<_ShimmerSectionHeader> createState() => _ShimmerSectionHeaderState();
}

class _ShimmerSectionHeaderState extends State<_ShimmerSectionHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
                    end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
                    colors: [widget.base, widget.highlight, widget.base],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
                    end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
                    colors: [widget.base, widget.highlight, widget.base],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Grid skeleton that matches GridCard layout.
class _ShimmerGrid extends StatelessWidget {
  final Color base;
  final Color highlight;

  const _ShimmerGrid({required this.base, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth - 32;
        final crossAxisCount = avail > 700 ? 4 : avail > 340 ? 3 : 2;
        final gap = 8.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: 0.72,
          ),
          itemCount: crossAxisCount * 2,
          itemBuilder: (_, index) {
            return _ShimmerGridCard(base: base, highlight: highlight);
          },
        );
      },
    );
  }
}

/// Grid card skeleton that matches GridCard layout.
class _ShimmerGridCard extends StatefulWidget {
  final Color base;
  final Color highlight;

  const _ShimmerGridCard({required this.base, required this.highlight});

  @override
  State<_ShimmerGridCard> createState() => _ShimmerGridCardState();
}

class _ShimmerGridCardState extends State<_ShimmerGridCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [widget.base, widget.highlight, widget.base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
