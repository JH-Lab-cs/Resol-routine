import 'package:flutter/material.dart';

import '../../../core/ui/app_tokens.dart';

enum _PlanTier { free, standard, premium }

class MembershipPlanScreen extends StatefulWidget {
  const MembershipPlanScreen({super.key});

  @override
  State<MembershipPlanScreen> createState() => _MembershipPlanScreenState();
}

class _MembershipPlanScreenState extends State<MembershipPlanScreen> {
  _PlanTier _selectedTier = _PlanTier.standard;
  bool _isYearly = false;

  static const Map<_PlanTier, _PlanContent> _plans = <_PlanTier, _PlanContent>{
    _PlanTier.free: _PlanContent(
      title: 'Free',
      subtitle: '가볍게 시작하는 기본 플랜',
      monthlyPrice: '₩ 0',
      yearlyPrice: '₩ 0',
      features: <String>[
        '매일 AI 문제 풀이 3회',
        '기본 해설 제공',
        '학습 타이머 사용 가능',
        '커뮤니티 접근 가능',
      ],
      ctaLabel: '현재 이용 중',
      isCurrentPlan: true,
    ),
    _PlanTier.standard: _PlanContent(
      title: 'Standard',
      subtitle: '가장 인기 있는 무제한 학습',
      monthlyPrice: '₩ 15,900',
      yearlyPrice: '₩ 174,900',
      monthlyEquivalent: '(월 ₩ 14,575)',
      yearlySaveLabel: '₩ 15,900 SAVE',
      features: <String>[
        '무제한 AI 문제 풀이',
        '상세 개념 분석 리포트',
        '취약점 분석 및 맞춤 문제',
        '무제한 오답 노트 & 복습',
        'Comet 브라우저 조기 이용 가능',
      ],
      ctaLabel: 'Standard 시작하기',
    ),
    _PlanTier.premium: _PlanContent(
      title: 'Premium',
      subtitle: '학습 코칭과 보호자 리포트까지',
      monthlyPrice: '₩ 29,900',
      yearlyPrice: '₩ 319,000',
      monthlyEquivalent: '(월 ₩ 26,583)',
      yearlySaveLabel: '₩ 39,800 SAVE',
      features: <String>[
        'Standard 모든 기능 포함',
        '주간 맞춤 학습 코칭 리포트',
        '학습 우선순위 플래너',
        '우선 고객 지원',
        '보호자용 진행 리포트 공유',
      ],
      ctaLabel: 'Premium 시작하기',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final plan = _plans[_selectedTier]!;
    final priceText = _isYearly ? plan.yearlyPrice : plan.monthlyPrice;
    final cycleText = _isYearly ? '/ 년' : '/ 월';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 34),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE7E9F1),
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(56, 56),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '구독권 선택',
                    style: AppTypography.title.copyWith(fontSize: 52 / 2),
                  ),
                  const Spacer(),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _PlanTabs(
                selectedTier: _selectedTier,
                onSelected: (tier) {
                  setState(() {
                    _selectedTier = tier;
                  });
                },
              ),
            ),
            const SizedBox(height: AppSpacing.mdLg),
            _BillingPeriodToggle(
              isYearly: _isYearly,
              onChanged: (value) {
                setState(() {
                  _isYearly = value;
                });
              },
            ),
            const SizedBox(height: AppSpacing.mdLg),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: AppTypography.display.copyWith(
                        fontSize: 62 / 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          priceText,
                          style: AppTypography.display.copyWith(
                            fontSize: 100 / 2,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            cycleText,
                            style: AppTypography.section.copyWith(
                              color: const Color(0xFF9B9DA7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isYearly && plan.yearlySaveLabel != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8C7),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          plan.yearlySaveLabel!,
                          style: AppTypography.label.copyWith(
                            color: const Color(0xFFB85D08),
                          ),
                        ),
                      ),
                    ],
                    if (_isYearly && plan.monthlyEquivalent != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        plan.monthlyEquivalent!,
                        style: AppTypography.section.copyWith(
                          color: const Color(0xFF9B9DA7),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      plan.subtitle,
                      style: AppTypography.section.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.mdLg),
                    const Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: AppSpacing.mdLg),
                    for (final feature in plan.features) ...[
                      _PlanFeature(text: feature),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            Container(
              color: const Color(0xFFF4F5F9),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: FilledButton(
                onPressed: plan.isCurrentPlan
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${plan.title} 요금제를 선택했습니다.')),
                        );
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 64),
                  textStyle: AppTypography.title.copyWith(
                    color: Colors.white,
                    fontSize: 45 / 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(plan.ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTabs extends StatelessWidget {
  const _PlanTabs({required this.selectedTier, required this.onSelected});

  final _PlanTier selectedTier;
  final ValueChanged<_PlanTier> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF0),
        borderRadius: BorderRadius.circular(AppRadius.buttonPill + 2),
      ),
      child: Row(
        children: _PlanTier.values
            .map(
              (tier) => Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.buttonPill),
                  onTap: () => onSelected(tier),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedTier == tier
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.buttonPill),
                      boxShadow: selectedTier == tier
                          ? AppShadows.card
                          : const <BoxShadow>[],
                    ),
                    child: Text(
                      _tierLabel(tier),
                      style: AppTypography.section.copyWith(
                        color: selectedTier == tier
                            ? AppColors.textPrimary
                            : const Color(0xFFA3A5AE),
                        fontWeight: selectedTier == tier
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String _tierLabel(_PlanTier tier) {
    switch (tier) {
      case _PlanTier.free:
        return 'Free';
      case _PlanTier.standard:
        return 'Standard';
      case _PlanTier.premium:
        return 'Premium';
    }
  }
}

class _BillingPeriodToggle extends StatelessWidget {
  const _BillingPeriodToggle({required this.isYearly, required this.onChanged});

  final bool isYearly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '월간',
          style: AppTypography.display.copyWith(
            fontSize: 58 / 2,
            color: isYearly ? const Color(0xFFC1C3CB) : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: () => onChanged(!isYearly),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 92,
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: isYearly
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : const Color(0xFFD6D8E0),
            ),
            child: Align(
              alignment: isYearly
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isYearly ? AppColors.primary : const Color(0xFF81838F),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '연간',
          style: AppTypography.display.copyWith(
            fontSize: 58 / 2,
            color: isYearly ? AppColors.textPrimary : const Color(0xFFC1C3CB),
          ),
        ),
      ],
    );
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: AppTypography.display.copyWith(
                fontSize: 49 / 2,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanContent {
  const _PlanContent({
    required this.title,
    required this.subtitle,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
    required this.ctaLabel,
    this.monthlyEquivalent,
    this.yearlySaveLabel,
    this.isCurrentPlan = false,
  });

  final String title;
  final String subtitle;
  final String monthlyPrice;
  final String yearlyPrice;
  final List<String> features;
  final String ctaLabel;
  final String? monthlyEquivalent;
  final String? yearlySaveLabel;
  final bool isCurrentPlan;
}
