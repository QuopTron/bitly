import 'package:flutter/material.dart';

class DetailPageTemplate extends StatelessWidget {
  final String title;
  final String? heroImageUrl;
  final String? subtitle;
  final List<Widget>? actions;
  final List<Widget> content;
  final Widget? bottomWidget;
  final double heroHeight;

  const DetailPageTemplate({
    super.key,
    required this.title,
    this.heroImageUrl,
    this.subtitle,
    this.actions,
    required this.content,
    this.bottomWidget,
    this.heroHeight = 250,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          if (heroImageUrl != null)
            SliverAppBar(
              expandedHeight: heroHeight,
              pinned: false,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Image.network(heroImageUrl!, fit: BoxFit.cover),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null) ...[
                    Text(subtitle!, style: TextStyle(color: Colors.grey.withValues(alpha: 0.7))),
                    const SizedBox(height: 16),
                  ],
                  ...content,
                ],
              ),
            ),
          ),
          if (bottomWidget != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: bottomWidget!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
