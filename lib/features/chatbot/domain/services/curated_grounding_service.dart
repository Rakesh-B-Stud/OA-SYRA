import '../../../../core/services/grounding_service.dart';

class CuratedGroundingService implements GroundingService {
  @override
  Future<String> getCuratedContext(String domain) async {
    // For Review 1, we provide high-level curated snippets from ICMR-NIN and WHO.
    // In a production scenario, this would perform a vector search or lookup in a verified DB.
    
    if (domain.toLowerCase().contains('nutrition') || domain.toLowerCase().contains('food')) {
      return '''
      Authoritative Context:
      1. ICMR-NIN (2017): Balanced diets should include a variety of food groups including cereals, pulses, vegetables, fruits, and dairy. 
      2. WHO: For a healthy diet, adults should consume at least 400g of fruits and vegetables daily, and limit free sugars to less than 10% of total energy intake.
      3. ICMR-NIN: Limit consumption of highly processed foods high in fats, sugar, and salt.
      ''';
    }
    
    if (domain.toLowerCase().contains('obesity') || domain.toLowerCase().contains('weight')) {
      return '''
      Authoritative Context:
      1. WHO: Overweight and obesity are defined as abnormal or excessive fat accumulation that may impair health. Body mass index (BMI) is a simple index of weight-for-height.
      2. ICMR-NIN: Physical activity is essential for weight management and metabolic health. At least 30 minutes of moderate-intensity activity most days is recommended.
      ''';
    }

    return 'No specific curated evidence available for this domain. Recommend standard wellness guidance.';
  }
}
