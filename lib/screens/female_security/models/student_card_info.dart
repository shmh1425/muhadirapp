/// Model for student card preview (معاينة البطاقة) used by female security screens.
class StudentCardInfo {
  const StudentCardInfo({
    required this.fullName,
    required this.universityId,
    required this.entryTime,
    required this.dayLabel,
    required this.dateLabel,
    required this.attendanceStatus,
    required this.college,
    required this.major,
    required this.degree,
    required this.nationality,
    required this.extraId,
    required this.gateLabel,
    this.photoAsset,
    this.photoUrl,
  });

  final String fullName;
  final String universityId;
  final String entryTime;
  final String dayLabel;
  final String dateLabel;
  final String attendanceStatus;
  final String college;
  final String major;
  final String degree;
  final String nationality;
  final String extraId;
  final String gateLabel;
  final String? photoAsset;
  final String? photoUrl;
}
