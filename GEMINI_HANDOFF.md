# OASYRA — Project Architecture & Handoff Specification

## 1. Project Overview
* **Purpose**: OASYRA is an AI-powered healthcare, nutrition, and symptom analysis platform providing personalized health monitoring, metabolic insights, virtual dietitian AI assistance, and meal logging.
* **Technology Stack**:
  * **Framework**: Flutter (Dart SDK `^3.11.5`, Material 3)
  * **State Management**: Riverpod (`flutter_riverpod: ^2.5.1`)
  * **Navigation**: GoRouter (`go_router: ^14.2.1`)
  * **Architecture**: Clean Architecture (MVVM & Repository Pattern)
  * **Backend & Cloud**: Firebase (Core, Auth, App Check, AI Logic / Gemini Developer API `gemini-3.7-flash`)
  * **Local Persistence**: `SharedPreferences`
  * **Health Data**: Health Connect (`health: ^13.3.2`)
  * **Reporting**: PDF generation & printing (`pdf: ^3.12.0`, `printing: ^5.14.3`)

---

## 2. Completed Features & Source Map

| Feature Area | File Paths | Description |
| :--- | :--- | :--- |
| **Authentication & Onboarding** | `lib/features/auth/`<br>`lib/features/onboarding/` | Email/password auth, onboarding splash, login/register flows. |
| **Main Dashboard & Routing** | `lib/features/dashboard/presentation/screens/dashboard_screen.dart`<br>`lib/core/routing/app_router.dart`<br>`lib/shared/screens/main_scaffold.dart` | ShellRoute bottom nav (Home, AI Guide, Health, Profile) and dashboard quick actions. |
| **Profile & Account Hub** | `lib/features/profile/presentation/screens/profile_hub_screen.dart`<br>`lib/features/profile/presentation/screens/edit_name_screen.dart`<br>`lib/features/health/presentation/screens/health_profile_setup_screen.dart` | Account Hub, display-name-only editor, and full health profile/vitals setup. |
| **Health Connect Sync** | `lib/features/health/data/repositories/health_connect_repository.dart` | Syncs steps, active calories, and activity minutes from Fitbit / Health Connect. |
| **Assessment & Metabolic Analysis** | `lib/features/health/presentation/screens/health_assessment_screen.dart`<br>`lib/features/analysis/domain/services/analysis_engine.dart` | Lifestyle screening, BMR, BMI, and daily energy expenditure targets. |
| **Health Analysis PDF Report** | `lib/core/services/oasyra_pdf_service.dart`<br>`lib/features/profile/presentation/providers/report_providers.dart`<br>`lib/features/profile/presentation/screens/report_preview_screen.dart` | Professional PDF report generation, rendering, and download/share actions. |
| **Virtual Dietitian AI Chatbot** | `lib/features/chatbot/presentation/providers/chatbot_providers.dart`<br>`lib/features/chatbot/domain/services/curated_grounding_service.dart` | Gemini `generateContentStream()` streaming assistant with WHO/ICMR medical grounding. |
| **Nutrition Module (Phase 5)** | `lib/features/nutrition/` | Complete food catalog, manual meal logging, daily macro rollups, and local persistence. |

---

## 3. Nutrition Module Details

* **Domain Models** (`lib/features/nutrition/domain/models/nutrition_models.dart`):
  * `NutritionData`: Macro values (calories, protein, carbohydrates, fat, fiber) per 100g with operator `+`.
  * `FoodItem`: Food record with ID, name, cuisine, dietTypes, category, `nutritionPer100g`, source, and reference.
  * `PortionEstimate`: Portion mass in grams, confidence, and calculation method (`Manual` vs `AI`).
  * `LoggedFoodItem`: Combines `FoodItem` and `PortionEstimate`; provides `totalNutrition` getter (`per100g * mass / 100`).
  * `MealRecord`: Meal entry with ID, `userId`, timestamp, `OasyraMealType` (breakfast, lunch, dinner, snack), items, and `totalNutrition`.
  * `DailyNutritionRollup`: Daily aggregation providing `totalNutrition` across all meals for a given date.
* **Repository & Persistence** (`lib/features/nutrition/data/repositories/local_nutrition_repository.dart`):
  * `LocalNutritionRepository` implements `NutritionRepository`.
  * Stores meal records as JSON string lists in `SharedPreferences` under key `nutrition_meals_$userId`.
  * Loads and caches the food catalog from `assets/data/food_catalog.json`.
* **State Management** (`lib/features/nutrition/presentation/providers/nutrition_providers.dart`):
  * `nutritionRepositoryProvider`: Supplies `NutritionRepository`.
  * `dailyNutritionProvider`: `StateNotifierProvider` managing `DailyNutritionRollup?` state via `DailyNutritionNotifier` (`loadToday()`, `logMeal()`, `deleteMeal()`). Parameterized by user email.
* **Presentation Layer**:
  * `NutritionDashboardScreen` (`lib/features/nutrition/presentation/screens/nutrition_dashboard_screen.dart`): Displays consumed daily macros, today's meals grouped by meal type, empty state, and delete action with modal confirmation.
  * `MealLoggingScreen` (`lib/features/nutrition/presentation/screens/meal_logging_screen.dart`): Searchable food list, auto-dismissing search results, selected food card, numeric portion entry in grams with live macro recalculation, meal type choice chips, and save meal action.
* **Food Catalog** (`assets/data/food_catalog.json`):
  * **103 total unique records**: 26 foundational base foods (`ind_001`–`ind_026`) + 77 regional Indian dishes (`ind_027`–`ind_103`).
  * Explicitly maps 100% of all 81 ML food classes.

---

## 4. ML Assets & Metadata

* **Model Checkpoints**:
  * **YOLO11n (Stage 1 Detection)**: Trained model `best.pt` (Target path: `oasyra_ml/weights/best.pt`).
  * **MobileNetV3-Small (Stage 2 Classification)**: Trained model `mobilenetv3_small_sih_best.pth` (Target path: `oasyra_ml/weights/mobilenetv3_small_sih_best.pth`).
* **Dataset Configuration**: `oasyra_ml/datasets/processed/sih_food_detection_v1/data.yaml` (81 classes).
* **Input Preprocessing Specifications**:
  * **YOLO11n**: $640 \times 640 \times 3$ RGB image, normalized $[0, 1]$.
  * **MobileNetV3-Small**: $224 \times 224 \times 3$ RGB image, ImageNet mean `[0.485, 0.456, 0.406]` & std `[0.229, 0.224, 0.225]`.
* **81-Class Reconciliation Mapping**:
  * **Swapped Index Warning**: PyTorch `ImageFolder` sorts directories alphabetically, while YOLO `data.yaml` uses dataset export order. 4 classes swap indices between YOLO and MobileNet:
    * `chicken tikka` (YOLO: 23, MobileNet: 22)
    * `chicken tikka masala` (YOLO: 22, MobileNet: 23)
    * `daal` (YOLO: 27, MobileNet: 26)
    * `daal puri` (YOLO: 26, MobileNet: 27)
  * **Reconciliation Rule**: Bounding box cropper output from Stage 1 MUST be matched to Stage 2 classification by **string label name**, NEVER numeric indices.

---

## 5. ML Integration Status

* **Completed**:
  * Dataset preprocessing scripts in `oasyra_ml/scripts/`.
  * Expanded 103-record food catalog (`assets/data/food_catalog.json`) covering all 81 ML class names.
  * String-based class reconciliation schema.
* **Planned (Not Yet Implemented)**:
  * Neither model is currently embedded in Flutter assets or running on-device.
  * No camera or image picker dependencies (`camera`, `image_picker`) are added to `pubspec.yaml` yet.
  * **No ML inference is currently running inside the Flutter app.** Food logging is currently manual via catalog search.

---

## 6. Testing & Static Analysis Status

* **Unit Tests Executed**:
  * `flutter test test/nutrition_test.dart` $\rightarrow$ **PASSED** (`00:04 +9: All tests passed!`)
    * 9 tests covering model logic, portion scaling (100g, 150g, 50g), meal aggregation, SharedPreferences persistence, user isolation, catalog loading, case-insensitive search, and whitespace queries.
  * `flutter test test/nutrition_provider_test.dart` $\rightarrow$ **PASSED** (`00:03 +7: All tests passed!`)
    * 7 tests covering unauthenticated null state, empty day rollup, reactive meal logging, reactive meal deletion, user isolation across containers, non-matching dates exclusion, and unauthenticated guard safety.
* **Static Analysis**:
  * `flutter analyze` $\rightarrow$ **PASSED (0 errors)**.

---

## 7. Known Issues & Limitations

1. **Unplaced Local Model Checkpoints**:
   * Model weight files (`best.pt` and `mobilenetv3_small_sih_best.pth`) exist in Google Drive storage and must be placed into `oasyra_ml/weights/` when launching the inference backend.
2. **Curated Culinary Estimates**:
   * The 77 expanded dish records use `"source": "OASYRA-Curated"` and `"sourceReference": "Standard culinary composition estimate"`. Real-world dish macros can vary based on oil, butter, cream, and sugar syrup usage.
3. **Deferred UI Layout Tweaks**:
   * Minor text wrapping or RenderFlex warnings on ultra-narrow screens are deferred per project guidelines.

---

## 8. Architecture Decisions

* **Selected Approach**: **Option B — Python / FastAPI REST Inference Backend (`oasyra_ml/server.py`)**
* **Rationale**:
  * **Zero Operator Loss**: PyTorch `.pth` and Ultralytics `.pt` models run natively without TFLite quantization or custom C++ operator conversion errors.
  * **Preserved Metrics**: Retains exact 62.47% Top-1 / 90.79% Top-5 classification accuracy.
  * **Lightweight Client**: Flutter client only requires `image_picker` and standard HTTP calls, avoiding memory jank or 50MB+ APK overhead.

---

## 9. Next Steps (In Priority Order)

1. **FastAPI ML Inference Service**: Create `oasyra_ml/server.py` with a `/predict_meal` REST endpoint loading `best.pt` and `mobilenetv3_small_sih_best.pth`.
2. **Flutter Image Selection**: Add `image_picker` to `pubspec.yaml` and add an "AI Food Camera" action button to `MealLoggingScreen`.
3. **Connect ML API to Meal Logger**: Send image file to `/predict_meal`, parse predicted label JSON, match string name against `food_catalog.json`, and pre-fill selected food and estimated mass in `MealLoggingScreen`.

---

## 10. Development Rules

* Preserve existing functionality, Riverpod provider structures, and user isolation.
* Inspect files and run tests before and after making edits.
* Do not modify unrelated code, routing, or bottom navigation.
* Never fabricate official literature sources for estimated nutrition values.
