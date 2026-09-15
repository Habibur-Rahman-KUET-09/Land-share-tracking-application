import 'package:cloud_firestore/cloud_firestore.dart';

/// FR 2.2: Flexible contribution — সবাই সমান (equal) নাকি প্রতিটি সদস্যের
/// জন্য আলাদা amount (custom), Admin এটা group creation/edit-এ টগল করে।
enum ContributionType { equal, custom }

ContributionType contributionTypeFromString(String? v) =>
    v == 'custom' ? ContributionType.custom : ContributionType.equal;

/// A "Land Group" (groups/{id}) — one jointly-purchased land, its
/// installment plan, and the friends sharing it.
class LandGroup {
  final String id;
  final String name;
  final String landLocation;
  final double totalLandValue;
  final int totalInstallments;
  final double monthlyTotalToBuilder;
  final int dueDayOfMonth; // 1-28, day of month the builder payment is due
  final ContributionType contributionType;
  final String createdBy;
  final DateTime createdAt;
  final List<String> memberIds;
  final List<String> adminIds;

  const LandGroup({
    required this.id,
    required this.name,
    required this.landLocation,
    required this.totalLandValue,
    required this.totalInstallments,
    required this.monthlyTotalToBuilder,
    required this.dueDayOfMonth,
    required this.contributionType,
    required this.createdBy,
    required this.createdAt,
    required this.memberIds,
    required this.adminIds,
  });

  LandGroup copyWith({
    String? name,
    String? landLocation,
    double? totalLandValue,
    int? totalInstallments,
    double? monthlyTotalToBuilder,
    int? dueDayOfMonth,
    ContributionType? contributionType,
    List<String>? memberIds,
    List<String>? adminIds,
  }) {
    return LandGroup(
      id: id,
      name: name ?? this.name,
      landLocation: landLocation ?? this.landLocation,
      totalLandValue: totalLandValue ?? this.totalLandValue,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      monthlyTotalToBuilder: monthlyTotalToBuilder ?? this.monthlyTotalToBuilder,
      dueDayOfMonth: dueDayOfMonth ?? this.dueDayOfMonth,
      contributionType: contributionType ?? this.contributionType,
      createdBy: createdBy,
      createdAt: createdAt,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'landLocation': landLocation,
      'totalLandValue': totalLandValue,
      'totalInstallments': totalInstallments,
      'monthlyTotalToBuilder': monthlyTotalToBuilder,
      'dueDayOfMonth': dueDayOfMonth,
      'contributionType': contributionType == ContributionType.custom ? 'custom' : 'equal',
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberIds': memberIds,
      'adminIds': adminIds,
    };
  }

  factory LandGroup.fromMap(String id, Map<String, dynamic> map) {
    return LandGroup(
      id: id,
      name: (map['name'] as String?) ?? '',
      landLocation: (map['landLocation'] as String?) ?? '',
      totalLandValue: (map['totalLandValue'] as num?)?.toDouble() ?? 0,
      totalInstallments: (map['totalInstallments'] as num?)?.toInt() ?? 0,
      monthlyTotalToBuilder: (map['monthlyTotalToBuilder'] as num?)?.toDouble() ?? 0,
      dueDayOfMonth: (map['dueDayOfMonth'] as num?)?.toInt() ?? 5,
      contributionType: contributionTypeFromString(map['contributionType'] as String?),
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberIds: List<String>.from((map['memberIds'] as List?) ?? const []),
      adminIds: List<String>.from((map['adminIds'] as List?) ?? const []),
    );
  }
}
