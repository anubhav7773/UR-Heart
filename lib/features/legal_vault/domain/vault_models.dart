/// Export request lifecycle under DPDP Act 2023 Sec 11
enum ExportStatus {
  idle,
  pending,
  ready,
}

/// Cryptographically signed user data archive request
class DataExportRecord {
  final String id;
  final ExportStatus status;
  final DateTime requestedAt;
  final String? downloadUrl;
  final String expiresText;

  const DataExportRecord({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.downloadUrl,
    this.expiresText = 'Valid for 7 days',
  });

  DataExportRecord copyWith({
    String? id,
    ExportStatus? status,
    DateTime? requestedAt,
    String? downloadUrl,
    String? expiresText,
  }) {
    return DataExportRecord(
      id: id ?? this.id,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      expiresText: expiresText ?? this.expiresText,
    );
  }
}

/// Data Nominee under DPDP Act 2023 Sec 14
class DataNominee {
  final String name;
  final String contact;
  final String relationship;
  final bool isDesignated;

  const DataNominee({
    this.name = '',
    this.contact = '',
    this.relationship = '',
    this.isDesignated = false,
  });
}

/// Statutory Grievance under IT Rules 2021 Rule 3(2)
class GrievanceRecord {
  final String id;
  final String category;
  final String evidenceText;
  final DateTime submittedAt;
  final String slaNotice;

  const GrievanceRecord({
    required this.id,
    required this.category,
    required this.evidenceText,
    required this.submittedAt,
    this.slaNotice = '24-hr ACK · 15-day Statutory Resolution SLA',
  });
}

/// Blocked perimeter candidate
class BlockedProfile {
  final String id;
  final String name;
  final int age;
  final String dateBlocked;

  const BlockedProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.dateBlocked,
  });
}
