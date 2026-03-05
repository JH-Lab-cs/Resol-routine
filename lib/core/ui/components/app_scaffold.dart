import 'package:flutter/material.dart';

import '../app_tokens.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showDecorativeBackground = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.mdLg,
      AppSpacing.md,
      AppSpacing.mdLg,
      0,
    ),
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showDecorativeBackground;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: AppPageBody(
        showDecorativeBackground: showDecorativeBackground,
        padding: padding,
        child: body,
      ),
    );
  }
}

class AppPageBody extends StatelessWidget {
  const AppPageBody({
    super.key,
    required this.child,
    this.showDecorativeBackground = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.mdLg,
      AppSpacing.md,
      AppSpacing.mdLg,
      0,
    ),
  });

  final Widget child;
  final bool showDecorativeBackground;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Stack(
        children: [
          if (showDecorativeBackground) ...[
            Positioned(
              top: -120,
              left: -90,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              top: -80,
              right: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
          Positioned.fill(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}
