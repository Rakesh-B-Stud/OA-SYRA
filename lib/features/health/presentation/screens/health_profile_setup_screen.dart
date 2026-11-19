import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/oasyra_button.dart';
import '../../../../shared/widgets/premium_components.dart';
import 'package:oasyara_1/features/profile/presentation/providers/report_providers.dart';
import 'package:oasyara_1/features/health/presentation/providers/health_providers.dart';
import 'package:oasyara_1/features/health/domain/models/health_models.dart';

class HealthProfileSetupScreen extends ConsumerStatefulWidget {
  const HealthProfileSetupScreen({super.key});

  @override
  ConsumerState<HealthProfileSetupScreen> createState() => _HealthProfileSetupScreenState();
}

class _HealthProfileSetupScreenState extends ConsumerState<HealthProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _waistController = TextEditingController();
  
  DateTime? _selectedDate;
  String _selectedGender = 'Other';
  String _selectedActivityLevel = 'Sedentary';
  String _selectedStressLevel = 'Low';
  String _selectedCuisine = 'General Indian';
  String _selectedDietType = 'Vegetarian';
  
  final List<String> _selectedDietaryRestrictions = [];
  final List<String> _selectedHealthGoals = [];
  final List<String> _selectedMedicalConditions = [];

  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final List<String> _activityLevels = ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active', 'Extra Active'];
  final List<String> _stressLevels = ['Low', 'Moderate', 'High', 'Very High'];
  final List<String> _cuisineOptions = ['General Indian', 'North Indian', 'South Indian', 'West Indian', 'East Indian'];
  final List<String> _dietTypeOptions = ['Vegetarian', 'Non-Vegetarian', 'Eggetarian', 'Vegan'];
  
  final List<String> _dietaryOptions = ['None', 'Vegetarian', 'Vegan', 'Keto', 'Paleo', 'Gluten-Free', 'Dairy-Free'];
  final List<String> _goalOptions = ['Weight Loss', 'Muscle Gain', 'Improve Energy', 'Better Sleep', 'Stress Reduction'];
  final List<String> _conditionOptions = ['None', 'Diabetes', 'Hypertension', 'High Cholesterol', 'Fatty Liver', 'Sleep Apnea'];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(healthProfileProvider);
    final authState = ref.read(authProvider);
    _nameController.text = profile?.name ?? authState.email?.split('@')[0] ?? '';
    if (profile != null) {
      _heightController.text = profile.heightCm.toString();
      _weightController.text = profile.currentWeightKg.toString();
      _targetWeightController.text = profile.targetWeightKg.toString();
      _waistController.text = profile.waistCircumferenceCm?.toString() ?? '';
      _selectedDate = profile.dateOfBirth;
      _selectedGender = profile.gender;
      _selectedActivityLevel = profile.activityLevel;
      _selectedStressLevel = profile.stressLevel;
      _selectedCuisine = profile.cuisinePreference ?? 'General Indian';
      _selectedDietType = profile.dietType ?? 'Vegetarian';
      _selectedDietaryRestrictions.addAll(profile.dietaryRestrictions);
      _selectedHealthGoals.addAll(profile.healthGoals);
      _selectedMedicalConditions.addAll(profile.medicalConditions);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _waistController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      _pageController.nextPage(duration: 400.ms, curve: Curves.easeInOut);
    } else {
      _saveProfile();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: 400.ms, curve: Curves.easeInOut);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _pageController.animateToPage(0, duration: 300.ms, curve: Curves.easeInOut);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name in Step 1'), backgroundColor: OasyraColors.warning),
      );
      return;
    }

    if (_selectedDate == null) {
      _pageController.animateToPage(0, duration: 300.ms, curve: Curves.easeInOut);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth in Step 1'), backgroundColor: OasyraColors.warning),
      );
      return;
    }

    final height = double.tryParse(_heightController.text) ?? 170.0;
    final weight = double.tryParse(_weightController.text) ?? 70.0;
    final targetWeight = double.tryParse(_targetWeightController.text) ?? 65.0;
    final waist = double.tryParse(_waistController.text);

    setState(() => _isSaving = true);

    try {
      final userId = await ref.read(authRepositoryProvider).getCurrentUserId() ??
                     ref.read(authProvider).email ??
                     'user';

      final profile = HealthProfile(
        userId: userId,
        name: _nameController.text.trim(),
        dateOfBirth: _selectedDate!,
        gender: _selectedGender,
        heightCm: height,
        currentWeightKg: weight,
        targetWeightKg: targetWeight,
        activityLevel: _selectedActivityLevel,
        stressLevel: _selectedStressLevel,
        dietaryRestrictions: _selectedDietaryRestrictions,
        healthGoals: _selectedHealthGoals.isEmpty ? ['Maintain healthy weight'] : _selectedHealthGoals,
        medicalConditions: _selectedMedicalConditions,
        waistCircumferenceCm: waist,
        cuisinePreference: _selectedCuisine,
        dietType: _selectedDietType,
      );

      await ref.read(healthProfileProvider.notifier).saveProfile(profile);
      await ref.read(healthMetricsProvider.notifier).loadMeasurements();

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Profile completed successfully!'),
              backgroundColor: OasyraColors.success,
              duration: Duration(seconds: 3),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: OasyraColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(reportGenerationProvider, (previous, next) {
      next.pdfBytes.when(
        data: (bytes) {
          if (bytes != null) {
            context.push('/report-preview', extra: {
              'bytes': bytes,
              'name': next.fileName ?? 'oasyra_report.pdf',
            });
            ref.read(reportGenerationProvider.notifier).reset();
          }
        },
        loading: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Generating report...'), duration: Duration(seconds: 1)),
          );
        },
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating report: $e')),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          PremiumPageHeader(
            title: 'Health Profile',
            subtitle: 'Manage your health information',
            showBackButton: true,
            actions: [
              if (ref.watch(healthProfileProvider) != null)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                  onPressed: () => ref.read(reportGenerationProvider.notifier).generateReport(),
                  tooltip: 'Download Health Report',
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 5,
                      backgroundColor: OasyraColors.primarySoft,
                      color: OasyraColors.primary,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${_currentStep + 1}/5',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _buildStepPersonal(),
                  _buildStepBodyMetrics(),
                  _buildStepLifestyle(),
                  _buildStepGoals(),
                  _buildStepNutrition(),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: OasyraColors.border)),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: Row(
              children: [
                if (_currentStep > 0) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _prevStep,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  flex: 2,
                  child: OasyraButton(
                    text: _currentStep == 4 ? 'Complete Profile' : 'Next Step',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _nextStep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPersonal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Personal Info',
            subtitle: 'Let\'s start with the basics.',
          ),
          const SizedBox(height: 32),
          OasyraCard(
            child: Column(
              children: [
                PremiumInputField(
                  label: 'Full Name',
                  placeholder: 'Enter your name',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                _buildLabel('Date of Birth'),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: OasyraColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OasyraColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: OasyraColors.textTertiary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate == null ? 'Select date' : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                          style: TextStyle(
                            color: _selectedDate == null ? OasyraColors.textTertiary : OasyraColors.textPrimary,
                            fontWeight: _selectedDate == null ? FontWeight.w400 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildLabel('Gender'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _genders.map((g) => PremiumChoiceChip(
              label: g,
              isSelected: _selectedGender == g,
              onSelected: () => setState(() => _selectedGender = g),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBodyMetrics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Body Metrics',
            subtitle: 'Your physical measurements.',
          ),
          const SizedBox(height: 32),
          OasyraCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PremiumInputField(
                        label: 'Height (cm)',
                        placeholder: '175',
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PremiumInputField(
                        label: 'Weight (kg)',
                        placeholder: '70',
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PremiumInputField(
                  label: 'Target Weight (kg)',
                  placeholder: '65',
                  controller: _targetWeightController,
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                PremiumInputField(
                  label: 'Waist (cm)',
                  placeholder: '80',
                  controller: _waistController,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLifestyle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Lifestyle',
            subtitle: 'Your daily habits.',
          ),
          const SizedBox(height: 32),
          _buildLabel('Activity Level'),
          const SizedBox(height: 12),
          Column(
            children: _activityLevels.map((level) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: PremiumChoiceChip(
                  label: level,
                  isSelected: _selectedActivityLevel == level,
                  onSelected: () => setState(() => _selectedActivityLevel = level),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 32),
          _buildLabel('Daily Stress Level'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _stressLevels.map((s) => PremiumChoiceChip(
              label: s,
              isSelected: _selectedStressLevel == s,
              onSelected: () => setState(() => _selectedStressLevel = s),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNutrition() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Nutrition Preferences',
            subtitle: 'Personalize your meal planning experience.',
          ),
          const SizedBox(height: 32),
          _buildLabel('Diet Type'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _dietTypeOptions.map((type) => PremiumChoiceChip(
              label: type,
              isSelected: _selectedDietType == type,
              onSelected: () => setState(() => _selectedDietType = type),
            )).toList(),
          ),
          const SizedBox(height: 32),
          _buildLabel('Cuisine Preference'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _cuisineOptions.map((cuisine) => PremiumChoiceChip(
              label: cuisine,
              isSelected: _selectedCuisine == cuisine,
              onSelected: () => setState(() => _selectedCuisine = cuisine),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: OasyraColors.textPrimary));
  }

  Widget _buildStepGoals() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Goals & Health',
            subtitle: 'Defining your path to better well-being.',
          ),
          const SizedBox(height: 32),
          _buildStepMultiSelect('Dietary Restrictions', _dietaryOptions, _selectedDietaryRestrictions),
          const SizedBox(height: 24),
          _buildStepMultiSelect('Health Goals', _goalOptions, _selectedHealthGoals),
          const SizedBox(height: 24),
          _buildStepMultiSelect('Medical Conditions', _conditionOptions, _selectedMedicalConditions),
        ],
      ),
    );
  }

  Widget _buildStepMultiSelect(String label, List<String> options, List<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: OasyraColors.textPrimary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((o) {
            final isSel = selected.contains(o);
            return PremiumChoiceChip(
              label: o,
              isSelected: isSel,
              onSelected: () {
                setState(() {
                  if (o == 'None') {
                    selected.clear();
                    selected.add('None');
                  } else {
                    selected.remove('None');
                    if (isSel) {
                      selected.remove(o);
                    } else {
                      selected.add(o);
                    }
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
