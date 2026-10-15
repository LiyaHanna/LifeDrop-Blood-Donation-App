import '../services/database_service.dart';

/// Repository responsible for high-level data operations related to blood requests.
/// Serves as an abstraction layer between the UI/Services and the [DatabaseService].
class RequestRepository {
  final DatabaseService _databaseService = DatabaseService();

  /// Initiates the cancellation of a blood request.

  /// [requestId]: The unique ID of the request document in Firestore.
  /// [reason]: The textual explanation provided by the user for the cancellation.
  Future<void> cancelRequest(String requestId, String reason) async {
    // Delegate the low-level database transaction to the DatabaseService.
    return await _databaseService.cancelBloodRequest(requestId, reason);
  }

  // Future expansion: operations like batch deletion or archival could be added here.
}
