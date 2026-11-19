import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/nutrition_repository.dart';

class LocalNutritionRepository implements NutritionRepository {
  final SharedPreferences _prefs;
  FirebaseFirestore? _firestore;
  List<FoodItem>? _cachedCatalog;

  LocalNutritionRepository(this._prefs) {
    try {
      _firestore = FirebaseFirestore.instance;
    } catch (_) {}
  }

  String _mealKey(String userId) => 'nutrition_meals_$userId';

  @override
  Future<void> saveMealRecord(MealRecord record) async {
    final List<MealRecord> current = await _getAllMealRecords(record.userId);
    
    // Replace if exists, otherwise add
    final index = current.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      current[index] = record;
    } else {
      current.add(record);
    }

    final data = current.map((r) => json.encode(r.toMap())).toList();
    await _prefs.setStringList(_mealKey(record.userId), data);

    // Sync to Cloud Firestore for cloud backup & uninstallation-safe persistence
    if (_firestore != null) {
      try {
        final cleanUserId = record.userId.replaceAll('.', '_');
        await _firestore!
            .collection('users')
            .doc(cleanUserId)
            .collection('meals')
            .doc(record.id)
            .set(record.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<List<MealRecord>> _getAllMealRecords(String userId) async {
    final data = _prefs.getStringList(_mealKey(userId));
    List<MealRecord> localRecords = [];
    if (data != null) {
      localRecords = data.map((e) => MealRecord.fromMap(json.decode(e))).toList();
    }

    // Try restoring missing records from Cloud Firestore if online
    if (_firestore != null && localRecords.isEmpty) {
      try {
        final cleanUserId = userId.replaceAll('.', '_');
        final querySnapshot = await _firestore!
            .collection('users')
            .doc(cleanUserId)
            .collection('meals')
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final cloudRecords = querySnapshot.docs
              .map((doc) => MealRecord.fromMap(doc.data()))
              .toList();

          final updatedData = cloudRecords.map((r) => json.encode(r.toMap())).toList();
          await _prefs.setStringList(_mealKey(userId), updatedData);
          return cloudRecords;
        }
      } catch (_) {}
    }

    return localRecords;
  }

  @override
  Future<List<MealRecord>> getMealRecordsForDay(String userId, DateTime date) async {
    final all = await _getAllMealRecords(userId);
    return all.where((r) {
      return r.timestamp.year == date.year &&
             r.timestamp.month == date.month &&
             r.timestamp.day == date.day;
    }).toList();
  }

  @override
  Future<List<MealRecord>> getMealRecordsForRange(String userId, DateTime start, DateTime end) async {
    final all = await _getAllMealRecords(userId);
    return all.where((r) {
      return r.timestamp.isAfter(start.subtract(const Duration(seconds: 1))) &&
             r.timestamp.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();
  }

  @override
  Future<MealRecord?> getMealRecord(String userId, String recordId) async {
    final all = await _getAllMealRecords(userId);
    try {
      return all.firstWhere((r) => r.id == recordId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteMealRecord(String userId, String recordId) async {
    final List<MealRecord> current = await _getAllMealRecords(userId);
    current.removeWhere((r) => r.id == recordId);
    final data = current.map((r) => json.encode(r.toMap())).toList();
    await _prefs.setStringList(_mealKey(userId), data);

    if (_firestore != null) {
      try {
        final cleanUserId = userId.replaceAll('.', '_');
        await _firestore!
            .collection('users')
            .doc(cleanUserId)
            .collection('meals')
            .doc(recordId)
            .delete();
      } catch (_) {}
    }
  }

  @override
  Future<List<FoodItem>> getFoodCatalog() async {
    if (_cachedCatalog != null) {
      return _cachedCatalog!;
    }
    try {
      final jsonString = await rootBundle.loadString('assets/data/food_catalog.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedCatalog = jsonList.map((e) => FoodItem.fromMap(e)).toList();
      return _cachedCatalog!;
    } catch (e, stack) {
      throw Exception('Failed to load or parse food catalog asset: $e\n$stack');
    }
  }

  @override
  Future<List<FoodItem>> searchFoodCatalog(String query) async {
    final catalog = await getFoodCatalog();
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return catalog;
    final lowercaseQuery = trimmedQuery.toLowerCase();
    return catalog.where((f) => f.name.toLowerCase().contains(lowercaseQuery)).toList();
  }
}
