import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/oasyra_button.dart';
import '../../../../shared/widgets/premium_components.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      ref.read(authProvider.notifier).register(
            _emailController.text.trim(),
            _passwordController.text,
            _nameController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: OasyraColors.error,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }

      if (next.status == AuthStatus.unverifiedEmail || next.registrationSuccess) {
        ref.read(authProvider.notifier).clearRegistrationSuccess();
        context.go('/verify-email');
      }
    });

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        // Brand Icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: OasyraColors.primarySoft,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.spa_rounded,
                            color: OasyraColors.primary,
                            size: 36,
                          ),
                        ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: OasyraColors.textPrimary,
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join OASYRA and start your\npersonalized health journey',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: OasyraColors.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                        
                        const SizedBox(height: 28),
                        
                        PremiumInputField(
                          label: 'Full Name',
                          placeholder: 'Enter your name',
                          controller: _nameController,
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        PremiumInputField(
                          label: 'Email',
                          placeholder: 'Enter your email address',
                          controller: _emailController,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (!value.contains('@') || !value.contains('.')) return 'Invalid email';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        PremiumInputField(
                          label: 'Password',
                          placeholder: 'Enter your password',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: OasyraColors.textTertiary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (value.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        
                        PremiumInputField(
                          label: 'Confirm Password',
                          placeholder: 'Confirm your password',
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: OasyraColors.textTertiary,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (value != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 28),
                        
                        OasyraButton(
                          text: 'Create Account',
                          isLoading: authState.status == AuthStatus.authenticating,
                          onPressed: _handleRegister,
                        ),

                        const SizedBox(height: 20),

                        _buildOrDivider(),

                        const SizedBox(height: 20),

                        _buildGoogleButton(context, authState),
                        
                        const SizedBox(height: 24),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: TextStyle(color: OasyraColors.textTertiary),
                            ),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Sign In'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: OasyraColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'OR',
            style: TextStyle(
              color: OasyraColors.textTertiary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Divider(color: OasyraColors.border, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton(BuildContext context, AuthState authState) {
    return ElevatedButton(
      onPressed: authState.status == AuthStatus.authenticating
          ? null
          : () => ref.read(authProvider.notifier).signInWithGoogle(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: OasyraColors.textPrimary,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        side: const BorderSide(color: OasyraColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Center(
              child: Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Continue with Google',
            style: TextStyle(
              color: OasyraColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
