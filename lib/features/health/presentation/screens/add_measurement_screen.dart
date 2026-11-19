import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/oasyra_button.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../providers/health_providers.dart';

class AddMeasurementScreen extends ConsumerStatefulWidget {
  const AddMeasurementScreen({super.key});

  @override
  ConsumerState<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends ConsumerState<AddMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _waistController = TextEditingController();
  
  double _currentBmi = 0;
  String _currentCategory = '';

  @override
  void initState() {
    super.initState();
    _weightController.addListener(_calculateLiveBmi);
  }

  @override
  void dispose() {
    _weightController.removeListener(_calculateLiveBmi);
    _weightController.dispose();
    _waistController.dispose();
    super.dispose();
  }

  void _calculateLiveBmi() {
    final profile = ref.read(healthProfileProvider);
    if (profile == null) return;

    final weight = double.tryParse(_weightController.text);
    if (weight != null && weight > 0) {
      final heightM = profile.heightCm / 100;
      final bmi = weight / (heightM * heightM);
      
      String category;
      if (bmi < 18.5) {
        category = 'Underweight';
      } else if (bmi < 25.0) {
        category = 'Healthy weight';
      } else if (bmi < 30.0) {
        category = 'Overweight';
      } else {
        category = 'Obesity';
      }

      setState(() {
        _currentBmi = bmi;
        _currentCategory = category;
      });
    } else {
      setState(() {
        _currentBmi = 0;
        _currentCategory = '';
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final profile = ref.read(healthProfileProvider);
      if (profile == null) return;

      await ref.read(healthMetricsProvider.notifier).addMeasurement(
        double.parse(_weightController.text),
        profile.heightCm,
        _waistController.text.isNotEmpty ? double.parse(_waistController.text) : null,
      );
      
      // Refresh profile since weight was updated in the repository
      await ref.read(healthProfileProvider.notifier).loadProfile();
      
      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'Add Measurement',
            subtitle: 'Track your health progress',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumSectionHeader(
                      title: 'Daily Update',
                      subtitle: 'Record your physical data.',
                    ),
                    const SizedBox(height: 32),
                    
                    if (_currentBmi > 0)
                      OasyraCard(
                        color: OasyraColors.primarySoft,
                        border: Border.all(color: OasyraColors.primary.withValues(alpha: 0.1), width: 1.5),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PREVIEW BMI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: OasyraColors.textTertiary, letterSpacing: 1)),
                                const SizedBox(height: 8),
                                Text(
                                  _currentBmi.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w500, color: OasyraColors.primary),
                                ),
                              ],
                            ),
                            const Spacer(),
                            PremiumHealthBadge(label: _currentCategory.toUpperCase(), color: OasyraColors.primary),
                          ],
                        ),
                      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),

                    const SizedBox(height: 16),
                    OasyraCard(
                      child: Column(
                        children: [
                          PremiumInputField(
                            label: 'Current Weight (kg)',
                            placeholder: 'e.g. 70',
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 24),
                          PremiumInputField(
                            label: 'Waist Circumference (cm) - Optional',
                            placeholder: 'e.g. 85',
                            controller: _waistController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    OasyraButton(
                      text: 'Save Measurement',
                      onPressed: _save,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
