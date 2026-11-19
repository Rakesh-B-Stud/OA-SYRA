import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/oasyra_button.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../health/domain/models/health_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class EditNameScreen extends ConsumerStatefulWidget {
  const EditNameScreen({super.key});

  @override
  ConsumerState<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends ConsumerState<EditNameScreen> {
  late TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(healthProfileProvider);
    final authState = ref.read(authProvider);
    final initialName = profile?.name ?? authState.email?.split('@')[0] ?? '';
    _nameController = TextEditingController(text: initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final existingProfile = ref.read(healthProfileProvider);
      final userId = await ref.read(authRepositoryProvider).getCurrentUserId() ??
                     ref.read(authProvider).email ??
                     'user';

      final profileToSave = existingProfile != null
          ? HealthProfile(
              userId: existingProfile.userId,
              name: newName,
              dateOfBirth: existingProfile.dateOfBirth,
              gender: existingProfile.gender,
              heightCm: existingProfile.heightCm,
              currentWeightKg: existingProfile.currentWeightKg,
              targetWeightKg: existingProfile.targetWeightKg,
              activityLevel: existingProfile.activityLevel,
              stressLevel: existingProfile.stressLevel,
              dietaryRestrictions: existingProfile.dietaryRestrictions,
              healthGoals: existingProfile.healthGoals,
              medicalConditions: existingProfile.medicalConditions,
              waistCircumferenceCm: existingProfile.waistCircumferenceCm,
              cuisinePreference: existingProfile.cuisinePreference,
              dietType: existingProfile.dietType,
            )
          : HealthProfile(
              userId: userId,
              name: newName,
              dateOfBirth: DateTime(1995, 1, 1),
              gender: 'Other',
              heightCm: 170,
              currentWeightKg: 70,
              targetWeightKg: 65,
              activityLevel: 'Moderate',
              stressLevel: 'Low',
              dietaryRestrictions: const [],
              healthGoals: const ['Maintain healthy weight'],
              medicalConditions: const [],
            );

      await ref.read(healthProfileProvider.notifier).saveProfile(profileToSave);
      await ref.read(authProvider.notifier).updateDisplayName(newName);

      if (mounted) {
        final rootScaffoldMessenger = ScaffoldMessenger.of(context);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/profile-hub');
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          rootScaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Display name updated successfully!'),
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
            content: Text('Failed to update name: $e'),
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
    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'Edit Name',
            subtitle: 'Update your display identity',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumSectionHeader(
                      title: 'Account Settings',
                      subtitle: 'Change how we address you in OASYRA.',
                    ),
                    const SizedBox(height: 32),
                    OasyraCard(
                      child: PremiumInputField(
                        label: 'Display Name',
                        placeholder: 'Enter your name',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Display name cannot be empty';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 48),
                    OasyraButton(
                      text: 'Update Name',
                      isLoading: _isSaving,
                      onPressed: _handleSave,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _isSaving ? null : () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/profile-hub');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: OasyraColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: OasyraColors.textSecondary, fontWeight: FontWeight.w600)),
                    ),
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
