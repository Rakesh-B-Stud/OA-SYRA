abstract class GroundingService {
  /// Retrieves curated context for a specific domain (e.g., nutrition, obesity).
  Future<String> getCuratedContext(String domain);
}
