import 'package:flutter/material.dart';

import '../models/land_group.dart';

/// The same underlying fields mean different things in each kind of group,
/// so the UI labels them per type rather than hard-coding the original
/// land/builder wording. These return l10n keys (see `lib/l10n/app_strings.dart`)
/// so the Bangla/English toggle keeps working.
extension GroupTypeLabels on GroupType {
  /// Short name of the type, for pickers and group cards.
  String get nameKey => switch (this) {
        GroupType.installment => 'group_type_installment',
        GroupType.savings => 'group_type_savings',
        GroupType.lottery => 'group_type_lottery',
      };

  /// One line explaining what the type is for, shown while choosing one.
  String get descriptionKey => switch (this) {
        GroupType.installment => 'group_type_installment_desc',
        GroupType.savings => 'group_type_savings_desc',
        GroupType.lottery => 'group_type_lottery_desc',
      };

  /// `LandGroup.monthlyTotalToBuilder` — money out to the builder, into the
  /// savings pot, or this month's lottery pot.
  String get monthlyTotalKey => switch (this) {
        GroupType.installment => 'monthly_total_to_builder',
        GroupType.savings => 'monthly_total_savings',
        GroupType.lottery => 'monthly_total_pot',
      };

  /// `LandGroup.totalLandValue` — the land's price, or a savings target.
  /// Lottery groups have no such figure (the pot rotates, nothing accrues).
  String? get totalValueKey => switch (this) {
        GroupType.installment => 'total_land_value',
        GroupType.savings => 'savings_target',
        GroupType.lottery => null,
      };

  /// Whether the group tracks a physical location (only land does).
  bool get hasLocation => this == GroupType.installment;

  /// Whether the plan has a fixed number of installments. A lottery runs
  /// exactly one round per member, so its length is the member count, not
  /// a number anyone types in.
  bool get hasInstallmentCount => this != GroupType.lottery;

  /// The outgoing-money tab: builder payments, or bank/fund deposits.
  /// Lottery groups have no outgoing ledger — the pot goes straight to
  /// that month's winner, which the draw record already captures.
  String? get outgoingTabKey => switch (this) {
        GroupType.installment => 'builder_payments',
        GroupType.savings => 'bank_deposits',
        GroupType.lottery => null,
      };

  String get outgoingActionKey => switch (this) {
        GroupType.savings => 'record_bank_deposit',
        _ => 'record_builder_payment',
      };

  String get outgoingTotalKey => switch (this) {
        GroupType.savings => 'total_deposited',
        _ => 'total_remitted',
      };

  bool get hasLottery => this == GroupType.lottery;

  /// The type's icon, shared by the create-group picker and every screen
  /// that has to say which kind of group this is.
  IconData get icon => switch (this) {
        GroupType.installment => Icons.home_work_outlined,
        GroupType.savings => Icons.savings_outlined,
        GroupType.lottery => Icons.casino_outlined,
      };
}
