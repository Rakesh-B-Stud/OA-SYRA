import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../providers/nutrition_providers.dart';
import '../../domain/models/nutrition_models.dart';

class NutritionDashboardScreen extends ConsumerWidget {
  const NutritionDashboardScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String recordId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal'),
        content: const Text('Are you sure you want to delete this meal record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: OasyraColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(dailyNutritionProvider.notifier).deleteMeal(recordId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete meal: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyRollup = ref.watch(dailyNutritionProvider);

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'Nutrition',
            subtitle: 'Track daily macros & meals',
            showBackButton: true,
          ),
          Expanded(
            child: dailyRollup == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(dailyNutritionProvider.notifier).loadToday();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMacrosSummary(context, dailyRollup.totalNutrition),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: PremiumSectionHeader(
                                  title: 'Today\'s Meals',
                                  subtitle: 'Logged nutrition breakdown',
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/meal-logging'),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Meal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: OasyraColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (dailyRollup.meals.isEmpty)
                            _buildEmptyState(context)
                          else
                            _buildMealList(context, ref, dailyRollup.meals),
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

  Widget _buildMacrosSummary(BuildContext context, NutritionData totals) {
    return OasyraCard(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OasyraColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_fire_department_rounded, color: OasyraColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Consumed Today',
                  style: TextStyle(fontWeight: FontWeight.w600, color: OasyraColors.textPrimary, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroItem('Calories', '${totals.calories.toStringAsFixed(0)}', 'kcal', OasyraColors.primary),
              _buildMacroItem('Protein', '${totals.protein.toStringAsFixed(1)}', 'g', Colors.blue),
              _buildMacroItem('Carbs', '${totals.carbohydrates.toStringAsFixed(1)}', 'g', Colors.orange),
              _buildMacroItem('Fat', '${totals.fat.toStringAsFixed(1)}', 'g', Colors.purple),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: OasyraColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Fiber: ${totals.fiber.toStringAsFixed(1)}g',
                style: const TextStyle(fontSize: 12, color: OasyraColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: OasyraColors.textTertiary, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
          Text(unit, style: const TextStyle(fontSize: 10, color: OasyraColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: OasyraColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu_rounded, size: 40, color: OasyraColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No meals logged today', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: OasyraColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Tap "Add Meal" to record your nutrition.', style: TextStyle(fontSize: 12, color: OasyraColors.textTertiary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/meal-logging'),
              style: ElevatedButton.styleFrom(
                backgroundColor: OasyraColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Log First Meal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealList(BuildContext context, WidgetRef ref, List<MealRecord> meals) {
    // Group by meal type
    final grouped = <OasyraMealType, List<MealRecord>>{};
    for (var type in OasyraMealType.values) {
      grouped[type] = meals.where((m) => m.type == type).toList();
    }

    return Column(
      children: OasyraMealType.values.map((type) {
        final typeMeals = grouped[type] ?? [];
        if (typeMeals.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _mealTypeToString(type),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: OasyraColors.textSecondary),
              ),
            ),
            ...typeMeals.map((meal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OasyraCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(meal.timestamp),
                          style: const TextStyle(fontSize: 11, color: OasyraColors.textTertiary, fontWeight: FontWeight.w500),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: OasyraColors.error, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmDelete(context, ref, meal.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...meal.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.food.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text('${item.portion.estimatedMassG.toStringAsFixed(0)} g • ${item.food.category}', style: const TextStyle(fontSize: 11, color: OasyraColors.textTertiary)),
                              ],
                            ),
                          ),
                          Text(
                            '${item.totalNutrition.calories.toStringAsFixed(0)} kcal',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OasyraColors.primary),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  String _mealTypeToString(OasyraMealType type) {
    switch (type) {
      case OasyraMealType.breakfast: return 'Breakfast';
      case OasyraMealType.lunch: return 'Lunch';
      case OasyraMealType.dinner: return 'Dinner';
      case OasyraMealType.snack: return 'Snack';
    }
  }
}
