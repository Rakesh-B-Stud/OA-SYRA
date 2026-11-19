import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../domain/models/health_data_models.dart';
import '../../domain/repositories/health_data_repository.dart';
import '../../data/repositories/health_connect_repository.dart';

enum HealthSyncStatus { initial, connecting, connected, disconnected, error, syncing }

class HealthDataState {
  final HealthSyncStatus status;
  final HealthDataSummary? summary;
  final String? errorMessage;

  HealthDataState({
    this.status = HealthSyncStatus.initial,
    this.summary,
    this.errorMessage,
  });

  HealthDataState copyWith({
    HealthSyncStatus? status,
    HealthDataSummary? summary,
    String? errorMessage,
  }) {
    return HealthDataState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      errorMessage: errorMessage,
    );
  }
}

final healthDataRepositoryProvider = Provider<HealthDataRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  
  // Use HealthConnectRepository in production, MockHealthDataRepository for tests/emulator if needed
  // For now, let's use HealthConnectRepository and handle availability gracefully
  return HealthConnectRepository(prefs);
});

final healthDataProvider = StateNotifierProvider<HealthDataNotifier, HealthDataState>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  final userEmail = ref.watch(authProvider.select((s) => s.email));
  return HealthDataNotifier(repository, userEmail);
});

class HealthDataNotifier extends StateNotifier<HealthDataState> {
  final HealthDataRepository _repository;
  final String? _userEmail;

  HealthDataNotifier(this._repository, this._userEmail) : super(HealthDataState()) {
    _init();
  }

  Future<void> _init() async {
    if (_userEmail == null) return;
    
    try {
      final isAvailable = await _repository.isHealthConnectAvailable();
      if (!isAvailable) {
        state = state.copyWith(status: HealthSyncStatus.disconnected, errorMessage: 'Health Connect not available');
        return;
      }

      final hasPerms = await _repository.hasPermissions();
      if (hasPerms) {
        final summary = await _repository.getLatestSummary(_userEmail);
        state = state.copyWith(
          status: HealthSyncStatus.connected,
          summary: summary,
        );
      } else {
        state = state.copyWith(status: HealthSyncStatus.disconnected);
      }
    } catch (e) {
      state = state.copyWith(status: HealthSyncStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> connect() async {
    if (_userEmail == null) return;
    
    state = state.copyWith(status: HealthSyncStatus.connecting);
    try {
      final success = await _repository.requestPermissions();
      if (success) {
        state = state.copyWith(status: HealthSyncStatus.connected);
        await sync();
      } else {
        state = state.copyWith(status: HealthSyncStatus.disconnected, errorMessage: 'Permission denied');
      }
    } catch (e) {
      state = state.copyWith(status: HealthSyncStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> sync() async {
    if (_userEmail == null || state.status != HealthSyncStatus.connected) return;
    
    state = state.copyWith(status: HealthSyncStatus.syncing);
    try {
      await _repository.synchronizeData(_userEmail);
      final summary = await _repository.getLatestSummary(_userEmail);
      state = state.copyWith(
        status: HealthSyncStatus.connected,
        summary: summary,
      );
    } catch (e) {
      state = state.copyWith(status: HealthSyncStatus.error, errorMessage: e.toString());
    }
  }
}
