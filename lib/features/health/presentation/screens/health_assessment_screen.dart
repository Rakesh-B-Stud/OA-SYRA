import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/oasyra_button.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../providers/health_providers.dart';
import '../../domain/models/health_models.dart';

class HealthAssessmentScreen extends ConsumerStatefulWidget {
  const HealthAssessmentScreen({super.key});

  @override
  ConsumerState<HealthAssessmentScreen> createState() => _HealthAssessmentScreenState();
}

class _HealthAssessmentScreenState extends ConsumerState<HealthAssessmentScreen> {
  List<AssessmentQuestion>? _questions;
  final Map<String, String> _responses = {};
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await ref.read(healthAssessmentProvider.notifier).generateDynamicAssessment();
    if (mounted) {
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    }
  }

  void _onOptionSelected(String option) {
    setState(() {
      _responses[_questions![_currentIndex].id] = option;
    });
  }

  void _next() {
    if (_currentIndex < _questions!.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _submit() {
    final List<AssessmentResponse> finalResponses = _responses.entries
        .map((e) => AssessmentResponse(questionId: e.key, response: e.value))
        .toList();

    if (finalResponses.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions before submitting.')),
      );
      return;
    }

    ref.read(healthAssessmentProvider.notifier).saveAssessment(finalResponses);
    context.go('/health-results');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: OasyraColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = _questions![_currentIndex];
    final progress = (_currentIndex + 1) / _questions!.length;

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'Health Assessment',
            subtitle: 'Help us understand your lifestyle',
            showBackButton: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: OasyraColors.primarySoft,
                color: OasyraColors.primary,
                minHeight: 6,
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: 400.ms,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(Tween(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutCubic))),
                    child: child,
                  ),
                );
              },
              child: SingleChildScrollView(
                key: ValueKey<int>(_currentIndex),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PremiumHealthBadge(
                      label: _getCategoryLabel(question.category).toUpperCase(),
                      color: OasyraColors.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      question.text,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: OasyraColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32), // Reduced from 48
                    ...question.options.map((option) {
                      final isSelected = _responses[question.id] == option;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _onOptionSelected(option),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: 200.ms,
                            padding: const EdgeInsets.all(20), // Reduced from 24
                            decoration: BoxDecoration(
                              color: isSelected ? OasyraColors.primarySoft : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? OasyraColors.primary : OasyraColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                  color: isSelected ? OasyraColors.primary : OasyraColors.textTertiary,
                                  size: 20, // Reduced from 24
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      color: isSelected ? OasyraColors.textPrimary : OasyraColors.textSecondary,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      fontSize: 15, // Reduced from 16
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: OasyraColors.border)),
            ),
            child: Row(
              children: [
                if (_currentIndex > 0) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _back,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  flex: 2,
                  child: OasyraButton(
                    text: _currentIndex == _questions!.length - 1 ? 'Finish Assessment' : 'Next Question',
                    onPressed: _responses.containsKey(question.id) ? _next : () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(AssessmentCategory category) {
    switch (category) {
      case AssessmentCategory.weightHistory: return 'Weight History';
      case AssessmentCategory.physicalActivity: return 'Activity';
      case AssessmentCategory.sedentaryBehavior: return 'Lifestyle';
      case AssessmentCategory.dietaryPatterns: return 'Diet';
      case AssessmentCategory.eatingBehavior: return 'Eating Habits';
      case AssessmentCategory.sleep: return 'Sleep';
      case AssessmentCategory.familyHistory: return 'History';
      case AssessmentCategory.comorbidities: return 'Health';
      case AssessmentCategory.medications: return 'Medications';
      case AssessmentCategory.lifestyle: return 'Habits';
    }
  }
}
