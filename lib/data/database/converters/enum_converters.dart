import 'package:drift/drift.dart';

import '../../enums/enums.dart';

/// Type converter for SignalType enum.
class SignalTypeConverter extends TypeConverter<SignalType, String> {
  const SignalTypeConverter();

  @override
  SignalType fromSql(String fromDb) {
    return SignalType.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => SignalType.wins,
    );
  }

  @override
  String toSql(SignalType value) => value.name;
}

/// Type converter for BetStatus enum.
class BetStatusConverter extends TypeConverter<BetStatus, String> {
  const BetStatusConverter();

  @override
  BetStatus fromSql(String fromDb) {
    return BetStatus.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => BetStatus.open,
    );
  }

  @override
  String toSql(BetStatus value) => value.name;
}

/// Type converter for EvidenceType enum.
class EvidenceTypeConverter extends TypeConverter<EvidenceType, String> {
  const EvidenceTypeConverter();

  @override
  EvidenceType fromSql(String fromDb) {
    return EvidenceType.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => EvidenceType.none,
    );
  }

  @override
  String toSql(EvidenceType value) => value.name;
}

/// Type converter for EvidenceStrength enum.
class EvidenceStrengthConverter extends TypeConverter<EvidenceStrength, String> {
  const EvidenceStrengthConverter();

  @override
  EvidenceStrength fromSql(String fromDb) {
    return EvidenceStrength.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => EvidenceStrength.none,
    );
  }

  @override
  String toSql(EvidenceStrength value) => value.name;
}

/// Type converter for BoardRoleType enum.
class BoardRoleTypeConverter extends TypeConverter<BoardRoleType, String> {
  const BoardRoleTypeConverter();

  @override
  BoardRoleType fromSql(String fromDb) {
    return BoardRoleType.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => BoardRoleType.accountability,
    );
  }

  @override
  String toSql(BoardRoleType value) => value.name;
}

/// Type converter for GovernanceSessionType enum.
class GovernanceSessionTypeConverter
    extends TypeConverter<GovernanceSessionType, String> {
  const GovernanceSessionTypeConverter();

  @override
  GovernanceSessionType fromSql(String fromDb) {
    return GovernanceSessionType.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => GovernanceSessionType.quick,
    );
  }

  @override
  String toSql(GovernanceSessionType value) => value.name;
}

/// Type converter for EntryType enum.
class EntryTypeConverter extends TypeConverter<EntryType, String> {
  const EntryTypeConverter();

  @override
  EntryType fromSql(String fromDb) {
    return EntryType.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => EntryType.text,
    );
  }

  @override
  String toSql(EntryType value) => value.name;
}

/// Type converter for ProblemDirection enum.
class ProblemDirectionConverter extends TypeConverter<ProblemDirection, String> {
  const ProblemDirectionConverter();

  @override
  ProblemDirection fromSql(String fromDb) {
    return ProblemDirection.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => ProblemDirection.stable,
    );
  }

  @override
  String toSql(ProblemDirection value) => value.name;
}
