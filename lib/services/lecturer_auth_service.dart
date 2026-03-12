import '../models/external_lecturer_model.dart';
import '../repositories/external_lecturer_repository.dart';

/// خدمة تحقق المحاضر من مجموعة external_lecturers بالإيميل فقط.
class LecturerAuthService {
  LecturerAuthService._();
  static final LecturerAuthService instance = LecturerAuthService._();
  final ExternalLecturerRepository _repository = ExternalLecturerRepository();

  ExternalLecturerModel? _currentLecturer;

  ExternalLecturerModel? get currentLecturer => _currentLecturer;

  Future<ExternalLecturerModel?> verifyEmailAndGetLecturer(String email) async {
    _currentLecturer = await _repository.getLecturerByEmail(email);
    return _currentLecturer;
  }

  void logout() {
    _currentLecturer = null;
  }
}
