import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/oasyra_button.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../providers/nutrition_providers.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/ml_detection_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class _StagedMealItem {
  FoodItem food;
  final TextEditingController controller;
  MlDetectionItem? detectionInfo;

  _StagedMealItem({
    required this.food,
    required double initialGrams,
    this.detectionInfo,
  }) : controller = TextEditingController(text: initialGrams.toStringAsFixed(0));

  double get portionGrams => double.tryParse(controller.text) ?? 100.0;

  NutritionData get totalNutrition {
    final grams = portionGrams;
    if (grams <= 0) return NutritionData.zero;
    final factor = grams / 100.0;
    return NutritionData(
      calories: food.nutritionPer100g.calories * factor,
      protein: food.nutritionPer100g.protein * factor,
      carbohydrates: food.nutritionPer100g.carbohydrates * factor,
      fat: food.nutritionPer100g.fat * factor,
      fiber: food.nutritionPer100g.fiber * factor,
    );
  }

  void dispose() {
    controller.dispose();
  }
}

class MealLoggingScreen extends ConsumerStatefulWidget {
  const MealLoggingScreen({super.key});

  @override
  ConsumerState<MealLoggingScreen> createState() => _MealLoggingScreenState();
}

class _MealLoggingScreenState extends ConsumerState<MealLoggingScreen> {
  final _searchController = TextEditingController();
  final List<_StagedMealItem> _stagedItems = [];
  
  List<FoodItem> _filteredCatalog = [];
  OasyraMealType _selectedMealType = OasyraMealType.lunch;
  
  bool _isSearchingFood = true;
  bool _isLoading = true;
  bool _isAiScanning = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var item in _stagedItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final repository = ref.read(nutritionRepositoryProvider);
      final catalog = await repository.getFoodCatalog();
      if (mounted) {
        setState(() {
          _filteredCatalog = catalog;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() async {
    final query = _searchController.text;
    try {
      final repository = ref.read(nutritionRepositoryProvider);
      final results = await repository.searchFoodCatalog(query);
      if (mounted) {
        setState(() {
          _filteredCatalog = results;
        });
      }
    } catch (_) {}
  }

  void _addFoodToStaged(FoodItem food, {double initialGrams = 100, MlDetectionItem? detectionInfo}) {
    FocusScope.of(context).unfocus();
    final newItem = _StagedMealItem(
      food: food,
      initialGrams: initialGrams,
      detectionInfo: detectionInfo,
    );
    newItem.controller.addListener(() => setState(() {}));

    setState(() {
      _stagedItems.add(newItem);
      _isSearchingFood = false;
      _searchController.clear();
    });
  }

  void _removeStagedItem(int index) {
    if (index >= 0 && index < _stagedItems.length) {
      final item = _stagedItems.removeAt(index);
      item.dispose();
      setState(() {
        if (_stagedItems.isEmpty) {
          _isSearchingFood = true;
        }
      });
    }
  }

  Future<void> _startAiScan() async {
    final ImagePicker picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: OasyraColors.primary),
              title: const Text('Take Photo with Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: OasyraColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isAiScanning = true);

      final service = ref.read(mlInferenceServiceProvider);
      final response = await service.predictMealImage(File(pickedFile.path));

      if (mounted) {
        setState(() => _isAiScanning = false);

        if (response.detections.isEmpty) {
          _showAiErrorDialog(
            'No Food Detected',
            'Smart Meal Scan could not identify any food regions in this image. Please select your food manually from the catalog.',
          );
        } else {
          _showAiDetectionsModal(response.detections);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAiScanning = false);
        _showAiErrorDialog(
          'Smart Meal Scan Error',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _showAiErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAiDetectionsModal(List<MlDetectionItem> detections) {
    final Set<int> selectedIndices = List.generate(detections.length, (i) => i).toSet();
    final Map<int, String> chosenLabels = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Smart Meal Scan Results',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: OasyraColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select items to add to your meal (${selectedIndices.length} selected):',
                    style: const TextStyle(fontSize: 12, color: OasyraColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: detections.length,
                      separatorBuilder: (context, index) => const Divider(height: 16, color: OasyraColors.border),
                      itemBuilder: (context, index) {
                        final item = detections[index];
                        final isChecked = selectedIndices.contains(index);
                        final chosenLabel = chosenLabels[index] ?? item.canonicalLabel;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isChecked ? OasyraColors.primarySoft.withValues(alpha: 0.3) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isChecked ? OasyraColors.primary : OasyraColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: OasyraColors.primary,
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          selectedIndices.add(index);
                                        } else {
                                          selectedIndices.remove(index);
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      chosenLabel.toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: OasyraColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.hasLabelDiscrepancy) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: OasyraColors.warningLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: OasyraColors.warning.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Model Disagreement: Select preferred candidate label:',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OasyraColors.warning),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: chosenLabel.toLowerCase() == item.yoloClassName.toLowerCase()
                                                      ? OasyraColors.primary
                                                      : OasyraColors.border,
                                                ),
                                                backgroundColor: chosenLabel.toLowerCase() == item.yoloClassName.toLowerCase()
                                                    ? OasyraColors.primarySoft
                                                    : Colors.white,
                                              ),
                                              onPressed: () {
                                                setModalState(() {
                                                  chosenLabels[index] = item.yoloClassName;
                                                });
                                              },
                                              child: Text(
                                                'YOLO: ${item.yoloClassName} (${(item.yoloConfidence * 100).toStringAsFixed(0)}%)',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: chosenLabel.toLowerCase() == item.mobilenetClassName.toLowerCase()
                                                      ? OasyraColors.primary
                                                      : OasyraColors.border,
                                                ),
                                                backgroundColor: chosenLabel.toLowerCase() == item.mobilenetClassName.toLowerCase()
                                                    ? OasyraColors.primarySoft
                                                    : Colors.white,
                                              ),
                                              onPressed: () {
                                                setModalState(() {
                                                  chosenLabels[index] = item.mobilenetClassName;
                                                });
                                              },
                                              child: Text(
                                                'MobileNet: ${item.mobilenetClassName} (${(item.mobilenetConfidence * 100).toStringAsFixed(0)}%)',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 48.0),
                                  child: Text(
                                    'Models Confirmed: YOLO ${(item.yoloConfidence * 100).toStringAsFixed(0)}% | MobileNet ${(item.mobilenetConfidence * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 11, color: OasyraColors.textSecondary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  OasyraButton(
                    text: 'Confirm Selected Items (${selectedIndices.length})',
                    onPressed: selectedIndices.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _batchApplyDetections(detections, selectedIndices, chosenLabels);
                          },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() => _isSearchingFood = true);
                      },
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Search Catalog Manually Instead'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _batchApplyDetections(
    List<MlDetectionItem> detections,
    Set<int> selectedIndices,
    Map<int, String> chosenLabels,
  ) async {
    final repository = ref.read(nutritionRepositoryProvider);
    int addedCount = 0;

    for (int idx in selectedIndices) {
      final item = detections[idx];
      final labelToUse = chosenLabels[idx] ?? item.canonicalLabel;
      final results = await repository.searchFoodCatalog(labelToUse);

      if (results.isNotEmpty) {
        _addFoodToStaged(results.first, initialGrams: 100, detectionInfo: item);
        addedCount++;
      }
    }

    if (mounted) {
      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $addedCount item(s) from Smart Meal Scan')),
        );
      } else {
        _showAiErrorDialog(
          'Food Not in Catalog',
          'Selected food item(s) are not available in the nutrition catalog. Please search manually.',
        );
      }
    }
  }

  Future<void> _saveMeal() async {
    if (_isSaving) return;

    if (_stagedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one food item')),
      );
      return;
    }

    for (int i = 0; i < _stagedItems.length; i++) {
      final grams = _stagedItems[i].portionGrams;
      if (grams <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid portion (> 0g) for ${_stagedItems[i].food.name}')),
        );
        return;
      }
    }

    final userEmail = ref.read(authProvider).email;
    if (userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final loggedItems = _stagedItems.map((staged) {
        final portion = PortionEstimate(
          estimatedMassG: staged.portionGrams,
          confidence: staged.detectionInfo != null ? staged.detectionInfo!.mobilenetConfidence : 1.0,
          method: 'Manual portion',
        );

        return LoggedFoodItem(
          food: staged.food,
          portion: portion,
        );
      }).toList();

      final mealRecord = MealRecord(
        id: const Uuid().v4(),
        userId: userEmail,
        timestamp: DateTime.now(),
        type: _selectedMealType,
        items: loggedItems,
      );

      await ref.read(dailyNutritionProvider.notifier).logMeal(mealRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meal logged successfully with ${loggedItems.length} item(s)!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save meal: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    NutritionData totalNutrition = NutritionData.zero;
    for (var staged in _stagedItems) {
      totalNutrition = totalNutrition + staged.totalNutrition;
    }

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'Log a Meal',
            subtitle: 'Select food and portion size',
            showBackButton: true,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: OasyraColors.error)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PremiumSectionHeader(
                              title: 'Meal Type',
                              subtitle: 'When are you eating this?',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: OasyraMealType.values.map((type) {
                                final isSelected = _selectedMealType == type;
                                return PremiumChoiceChip(
                                  label: _mealTypeToString(type),
                                  isSelected: isSelected,
                                  onSelected: () => setState(() => _selectedMealType = type),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: PremiumSectionHeader(
                                    title: 'Selected Foods (${_stagedItems.length})',
                                    subtitle: 'Add or scan multiple items for your meal',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _isAiScanning ? null : _startAiScan,
                                  icon: _isAiScanning
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.camera_alt_rounded, size: 16),
                                  label: Text(_isAiScanning ? 'Scanning...' : 'Smart Meal Scan'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: OasyraColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // List of Staged Meal Items
                            if (_stagedItems.isNotEmpty) ...[
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _stagedItems.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final staged = _stagedItems[index];
                                  final itemNutrition = staged.totalNutrition;

                                  return OasyraCard(
                                    color: Colors.white,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    staged.food.name,
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: OasyraColors.textPrimary),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${staged.food.category} • ${staged.food.cuisine}',
                                                    style: const TextStyle(fontSize: 11, color: OasyraColors.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, color: OasyraColors.error, size: 20),
                                              onPressed: () => _removeStagedItem(index),
                                            ),
                                          ],
                                        ),
                                        if (staged.detectionInfo != null) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: OasyraColors.primarySoft,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Smart Scan: ${staged.detectionInfo!.canonicalLabel} (${(staged.detectionInfo!.mobilenetConfidence * 100).toStringAsFixed(0)}% model conf)',
                                              style: const TextStyle(fontSize: 10, color: OasyraColors.primary, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: PremiumInputField(
                                                label: 'Mass (grams)',
                                                placeholder: '100',
                                                controller: staged.controller,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Item Macros: ${itemNutrition.calories.toStringAsFixed(0)} kcal | P: ${itemNutrition.protein.toStringAsFixed(1)}g | C: ${itemNutrition.carbohydrates.toStringAsFixed(1)}g | F: ${itemNutrition.fat.toStringAsFixed(1)}g',
                                          style: const TextStyle(fontSize: 11, color: OasyraColors.textSecondary, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _isSearchingFood = true),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Add Another Item from Catalog'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              OasyraCard(
                                color: OasyraColors.primarySoft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'COMBINED MEAL NUTRITION (${_stagedItems.length} item${_stagedItems.length == 1 ? '' : 's'})',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OasyraColors.primary),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _calcItem('Calories', '${totalNutrition.calories.toStringAsFixed(0)} kcal'),
                                        _calcItem('Protein', '${totalNutrition.protein.toStringAsFixed(1)} g'),
                                        _calcItem('Carbs', '${totalNutrition.carbohydrates.toStringAsFixed(1)} g'),
                                        _calcItem('Fat', '${totalNutrition.fat.toStringAsFixed(1)} g'),
                                        _calcItem('Fiber', '${totalNutrition.fiber.toStringAsFixed(1)} g'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Catalog Search
                            if (_isSearchingFood || _stagedItems.isEmpty) ...[
                              const SizedBox(height: 12),
                              PremiumInputField(
                                label: 'Search Catalog',
                                placeholder: 'Search e.g. Roti, Dosa, Paneer...',
                                controller: _searchController,
                                prefixIcon: Icons.search_rounded,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 200,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: OasyraColors.border),
                                  ),
                                  child: _filteredCatalog.isEmpty
                                      ? const Center(child: Text('No foods found', style: TextStyle(color: OasyraColors.textTertiary)))
                                      : ListView.separated(
                                          itemCount: _filteredCatalog.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1, color: OasyraColors.border),
                                          itemBuilder: (context, index) {
                                            final food = _filteredCatalog[index];
                                            return ListTile(
                                              title: Text(food.name, style: const TextStyle(fontSize: 14)),
                                              subtitle: Text('${food.category} • ${food.cuisine}', style: const TextStyle(fontSize: 11, color: OasyraColors.textTertiary)),
                                              trailing: Text('${food.nutritionPer100g.calories.toStringAsFixed(0)} kcal/100g', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: OasyraColors.primary)),
                                              onTap: () => _addFoodToStaged(food),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 40),
                            OasyraButton(
                              text: 'Save Meal (${_stagedItems.length} item${_stagedItems.length == 1 ? '' : 's'})',
                              isLoading: _isSaving,
                              onPressed: _stagedItems.isEmpty ? null : _saveMeal,
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _calcItem(String label, String value) {
    return Flexible(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: OasyraColors.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: OasyraColors.textPrimary),
            ),
          ),
        ],
      ),
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
