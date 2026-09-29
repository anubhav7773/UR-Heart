/// Export request lifecycle under DPDP Act 2023 Sec 11
enum ExportStatus {
  idle,
  pending,
  ready,
  processing,
  completed,
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

class DataExportTicket {
  final String requestId;
  final String status;
  final String message;
  final int validDays;

  const DataExportTicket({
    required this.requestId,
    required this.status,
    required this.message,
    this.validDays = 7,
  });

  factory DataExportTicket.fromJson(Map<String, dynamic> json) {
    return DataExportTicket(
      requestId: json['request_id'] as String? ?? json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'processing',
      message: json['message'] as String? ?? 'Data export requested.',
      validDays: json['valid_days'] as int? ?? 7,
    );
  }
}

class DataExportStatus {
  final String requestId;
  final String status;
  final String? checksumSha256;
  final Map<String, dynamic>? payload;
  final String? expiresAt;

  const DataExportStatus({
    required this.requestId,
    required this.status,
    this.checksumSha256,
    this.payload,
    this.expiresAt,
  });

  factory DataExportStatus.fromJson(Map<String, dynamic> json) {
    return DataExportStatus(
      requestId: json['request_id'] as String? ?? json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      checksumSha256: json['checksum_sha256'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      expiresAt: json['expires_at'] as String?,
    );
  }

  bool get isReady => status.toLowerCase() == 'completed' || status.toLowerCase() == 'ready';
  String? get downloadUrl =>
      (payload?['download_url'] as String?) ??
      (isReady ? 'https://urheart.asiverticals.me/api/v1/vault/export-download/$requestId' : null);
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

  factory DataNominee.fromJson(Map<String, dynamic> json) {
    return DataNominee(
      name: json['name'] as String? ?? json['nominee_name'] as String? ?? '',
      contact: json['contact'] as String? ?? json['contact_masked'] as String? ?? json['phone'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      isDesignated: json['is_designated'] as bool? ?? true,
    );
  }
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

class GrievanceReceipt {
  final String status;
  final String dossierReferenceId;
  final String slaAcknowledgment;
  final String? statutoryResolutionDeadline;
  final String? supportDeskContact;

  const GrievanceReceipt({
    required this.status,
    required this.dossierReferenceId,
    required this.slaAcknowledgment,
    this.statutoryResolutionDeadline,
    this.supportDeskContact,
  });

  factory GrievanceReceipt.fromJson(Map<String, dynamic> json) {
    return GrievanceReceipt(
      status: json['status'] as String? ?? 'acknowledged',
      dossierReferenceId: json['dossier_reference_id'] as String? ?? json['ticket_id'] as String? ?? '',
      slaAcknowledgment: json['sla_acknowledgment'] as String? ?? '24-hr ACK · 15-day Statutory Resolution SLA',
      statutoryResolutionDeadline: json['statutory_resolution_deadline'] as String?,
      supportDeskContact: json['support_desk_contact'] as String?,
    );
  }

  String get ticketId => dossierReferenceId;
}

/// Blocked perimeter candidate
class BlockedUserProfile {
  final String id;
  final String name;
  final int age;
  final String dateBlocked;

  const BlockedUserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.dateBlocked,
  });

  factory BlockedUserProfile.fromJson(Map<String, dynamic> json) {
    return BlockedUserProfile(
      id: json['id'] as String? ?? json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? json['full_name'] as String? ?? 'Blocked Seeker',
      age: json['age'] as int? ?? 25,
      dateBlocked: json['date_blocked'] as String? ?? json['blocked_at'] as String? ?? 'Recently',
    );
  }
}

typedef BlockedProfile = BlockedUserProfile;
