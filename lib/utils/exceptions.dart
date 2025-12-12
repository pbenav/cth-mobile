// Excepciones base
abstract class CTHException implements Exception {
  final String message;
  const CTHException(this.message);

  @override
  String toString() => message;
}

// Excepciones NFC
class NFCException extends CTHException {
  const NFCException(super.message);
}

class NFCNotAvailableException extends NFCException {
  const NFCNotAvailableException(super.message);
}

class NFCReadException extends NFCException {
  const NFCReadException(super.message);
}

class NFCWriteException extends NFCException {
  const NFCWriteException(super.message);
}

// Excepciones de API
class ApiException extends CTHException {
  final int? statusCode;
  final String? apiStatusCode;

  const ApiException(super.message, {this.statusCode, this.apiStatusCode});
}

class ClockException extends ApiException {
  const ClockException(super.message, {super.statusCode, super.apiStatusCode});
}

class TeamMismatchException extends ApiException {
  final int? selectedTeamId;
  final String? selectedTeamName;
  final String? selectedWorkCenterCode;
  final int? currentTeamId;
  final String? currentTeamName;
  final String? currentWorkCenterCode;
  
  const TeamMismatchException(
    super.message, {
    super.statusCode,
    super.apiStatusCode,
    this.selectedTeamId,
    this.selectedTeamName,
    this.selectedWorkCenterCode,
    this.currentTeamId,
    this.currentTeamName,
    this.currentWorkCenterCode,
  });
}

class AuthException extends ApiException {
  const AuthException(super.message, {super.statusCode, super.apiStatusCode});
}

class NetworkException extends ApiException {
  const NetworkException(super.message, {super.statusCode});
}

class SyncException extends ApiException {
  const SyncException(super.message, {super.statusCode});
}

// Excepciones de validación
class ValidationException extends CTHException {
  final Map<String, List<String>>? errors;

  const ValidationException(super.message, {this.errors});
}

// Excepciones de almacenamiento
class StorageException extends CTHException {
  const StorageException(super.message);
}

// Excepciones de configuración
class ConfigException extends CTHException {
  const ConfigException(super.message);
}

class SetupException extends CTHException {
  const SetupException(super.message);
}

class NFCVerificationException extends NFCException {
  const NFCVerificationException(super.message);
}

class APIException extends ApiException {
  const APIException(super.message, {super.statusCode});
}
