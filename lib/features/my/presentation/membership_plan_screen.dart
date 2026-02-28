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
    final isFreePlan = plan.isCurrentPlan;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 40),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '요금제 선택',
                    style: AppTypography.title.copyWith(
                      fontSize: 48 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _PlanTabs(
                selectedTier: _selectedTier,
                onSelected: (tier) {
                  setState(() {
                    _selectedTier = tier;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 40,
              child: isFreePlan
                  ? const SizedBox.shrink()
                  : _BillingPeriodToggle(
                      isYearly: _isYearly,
                      onChanged: (value) {
                        setState(() {
                          _isYearly = value;
                        });
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      plan.title,
                      style: AppTypography.display.copyWith(
                        fontSize: isFreePlan ? 40 : 20,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!isFreePlan) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            priceText,
                            style: AppTypography.display.copyWith(
                              fontSize: 34,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Opacity(
                                opacity: _isYearly ? 1.0 : 0.0,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE0B2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    plan.yearlySaveLabel ?? '',
                                    style: AppTypography.label.copyWith(
                                      color: const Color(0xFFE65100),
                                      fontSize: 11,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  cycleText,
                                  style: AppTypography.body.copyWith(
                                    fontSize: 16,
                                    color: const Color(0xFF9B9DA7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_isYearly && plan.monthlyEquivalent != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          plan.monthlyEquivalent!,
                          style: AppTypography.body.copyWith(
                            color: const Color(0xFF9B9DA7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Text(
                      plan.subtitle,
                      style: AppTypography.body.copyWith(
                        color: const Color(0xFF73788A),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 30),
                    for (final feature in plan.features) ...[
                      _PlanFeature(text: feature),
                      const SizedBox(height: 18),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
              child: FilledButton(
                onPressed: plan.isCurrentPlan
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${plan.title} 요금제를 선택했습니다.')),
                        );
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: AppTypography.title.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
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
    return SizedBox(
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F2F4),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: _PlanTier.values
              .map(
                (tier) => Expanded(
                  child: GestureDetector(
                    onTap: () => onSelected(tier),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.all(4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedTier == tier
                            ? Colors.white
                            : const Color(0xFFF1F2F4),
                        borderRadius: BorderRadius.circular(21),
                        boxShadow: selectedTier == tier
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : const <BoxShadow>[],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _tierLabel(tier),
                          maxLines: 1,
                          style: AppTypography.body.copyWith(
                            fontSize: 13,
                            color: selectedTier == tier
                                ? AppColors.textPrimary
                                : const Color(0xFF9FA3AF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
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
        GestureDetector(
          onTap: () => onChanged(false),
          child: Text(
            '월간',
            style: AppTypography.body.copyWith(
              fontSize: 16,
              color: !isYearly
                  ? AppColors.textPrimary
                  : const Color(0xFFC1C3CB),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scale: 0.9,
          child: Switch(
            value: isYearly,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
            inactiveThumbColor: const Color(0xFF9EA0A8),
            inactiveTrackColor: const Color(0xFFE4E6EB),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => onChanged(true),
          child: Text(
            '연간',
            style: AppTypography.body.copyWith(
              fontSize: 16,
              color: isYearly ? AppColors.textPrimary : const Color(0xFFC1C3CB),
              fontWeight: FontWeight.w700,
            ),
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
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body.copyWith(
              fontSize: 16,
              height: 1.3,
              color: const Color(0xFF1E2436),
              fontWeight: FontWeight.w500,
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
