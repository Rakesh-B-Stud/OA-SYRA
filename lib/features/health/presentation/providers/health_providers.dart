import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_migration_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/sqlite_health_repository.dart';
import '../../domain/models/health_models.dart';
import '../../domain/repositories/health_repository.dart';

final healthRepositoryProvider = Provider<SQLiteHealthRepository>((ref) {
  final db = AppDatabase();
  return SQLiteHealthRepository(db);
});

final healthProfileProvider = StateNotifierProvider<HealthProfileNotifier, HealthProfile?>((ref) {
  final repository = ref.watch(healthRepositoryProvider);
  final userEmail = ref.watch(authProvider.select((s) => s.email));
  final migrationService = ref.watch(localMigrationServiceProvider);
  return HealthProfileNotifier(repository, userEmail, migrationService);
});

class HealthProfileNotifier extends StateNotifier<HealthProfile?> {
  final HealthProfileRepository _repository;
  final String? _userEmail;
  final LocalMigrationService _migrationService;

  HealthProfileNotifier(this._repository, this._userEmail, this._migrationService) : super(null) {
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    if (_userEmail != null && _userEmail.isNotEmpty) {
      try {
        await _migrationService.migrateUser(_userEmail);
      } catch (_) {}
      await loadProfile();
    }
  }

  Future<void> loadProfile() async {
    if (_userEmail != null && _userEmail.isNotEmpty) {
      final profile = await _repository.getProfile(_userEmail);
      if (profile != null) {
        state = profile;
      }
    }
  }

  Future<void> saveProfile(HealthProfile profile) async {
    await _repository.saveProfile(profile);
    state = profile;
    if (_userEmail != null && _userEmail != profile.userId) {
      final fallbackProfile = HealthProfile(
        userId: _userEmail,
        name: profile.name,
        dateOfBirth: profile.dateOfBirth,
        gender: profile.gender,
        heightCm: profile.heightCm,
        currentWeightKg: profile.currentWeightKg,
        targetWeightKg: profile.targetWeightKg,
        activityLevel: profile.activityLevel,
        stressLevel: profile.stressLevel,
        dietaryRestrictions: profile.dietaryRestrictions,
        healthGoals: profile.healthGoals,
        medicalConditions: profile.medicalConditions,
        waistCircumferenceCm: profile.waistCircumferenceCm,
        cuisinePreference: profile.cuisinePreference,
        dietType: profile.dietType,
      );
      await _repository.saveProfile(fallbackProfile);
    }
  }
}

final healthMetricsProvider = StateNotifierProvider<HealthMetricsNotifier, List<HealthMeasurement>>((ref) {
  final repository = ref.watch(healthRepositoryProvider);
  final userEmail = ref.watch(authProvider.select((s) => s.email));
  return HealthMetricsNotifier(repository, userEmail);
});

class HealthMetricsNotifier extends StateNotifier<List<HealthMeasurement>> {
  final HealthMetricsRepository _repository;
  final String? _userEmail;

  HealthMetricsNotifier(this._repository, this._userEmail) : super([]) {
    loadMeasurements();
  }

  Future<void> loadMeasurements() async {
    if (_userEmail != null && _userEmail.isNotEmpty) {
      final items = await _repository.getMeasurements(_userEmail);
      state = items;
    }
  }

  Future<void> addMeasurement(double weightKg, double heightCm, double? waist) async {
    if (_userEmail == null) return;
    
    final measurement = HealthMeasurement(
      id: DateTime.now().toIso8601String(),
      userId: _userEmail,
      date: DateTime.now(),
      weightKg: weightKg,
      heightCm: heightCm,
      waistCircumferenceCm: waist,
    );
    
    await _repository.addMeasurement(measurement);
    await loadMeasurements();
  }
}

final healthAssessmentProvider = StateNotifierProvider<HealthAssessmentNotifier, HealthAssessment?>((ref) {
  final repository = ref.watch(healthRepositoryProvider);
  final userEmail = ref.watch(authProvider.select((s) => s.email));
  return HealthAssessmentNotifier(repository, userEmail);
});

class HealthAssessmentNotifier extends StateNotifier<HealthAssessment?> {
  final HealthAssessmentRepository _repository;
  final String? _userEmail;

  HealthAssessmentNotifier(this._repository, this._userEmail) : super(null) {
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    if (_userEmail != null && _userEmail.isNotEmpty) {
      state = await _repository.getLatestAssessment(_userEmail);
    }
  }

  Future<List<AssessmentQuestion>> generateDynamicAssessment() async {
    final bank = await _repository.getQuestionBank();
    
    final Map<AssessmentCategory, List<AssessmentQuestion>> grouped = {};
    for (var q in bank) {
      grouped[q.category] = (grouped[q.category] ?? [])..add(q);
    }

    final List<AssessmentQuestion> selected = [];
    final random = Random();

    final categories = grouped.keys.toList()..shuffle();
    for (var cat in categories) {
      if (selected.length >= 10) break;
      final qList = grouped[cat]!;
      selected.add(qList[random.nextInt(qList.length)]);
    }

    if (selected.length < 10) {
      final remaining = bank.where((q) => !selected.contains(q)).toList()..shuffle();
      selected.addAll(remaining.take(10 - selected.length));
    }

    return selected..shuffle();
  }

  Future<void> saveAssessment(List<AssessmentResponse> responses) async {
    if (_userEmail == null) return;
    
    final assessment = HealthAssessment(
      id: DateTime.now().toIso8601String(),
      userId: _userEmail,
      date: DateTime.now(),
      responses: responses,
    );
    
    await _repository.saveAssessment(assessment);
    state = assessment;
  }
}
