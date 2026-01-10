import 'package:drift/drift.dart';

/// Board members table.
///
/// Per PRD Section 3.1 and 3.3:
/// - 5 core roles (always active) + 2 growth roles (if appreciating problems exist)
/// - Each role has a persona profile and is anchored to a specific problem
/// - Users can edit persona names and profiles in Settings
/// - Original generated personas stored for reset capability
///
/// Per PRD Section 3.3.5:
/// - PersonaProfile includes: brief background, communication style, signature phrases
/// - All personas share baseline "warm-direct blunt" tone but differ in focus area
@DataClassName('BoardMember')
class BoardMembers extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Role type: accountability, marketReality, avoidance, etc.
  /// Maps to BoardRoleType enum.
  TextColumn get roleType => text()();

  /// Whether this is a growth role (portfolioDefender, opportunityScout).
  BoolColumn get isGrowthRole => boolean().withDefault(const Constant(false))();

  /// Whether this role is currently active.
  /// Growth roles are inactive when no appreciating problems exist.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// ID of the problem this role is anchored to.
  TextColumn get anchoredProblemId => text().nullable()();

  /// The specific demand/question derived from the anchored problem.
  /// AI-generated during Setup based on portfolio content.
  TextColumn get anchoredDemand => text().nullable()();

  // ==================
  // Persona Profile (Editable)
  // ==================

  /// Persona name (e.g., "Maya Chen").
  /// Per PRD: 1-50 characters, required.
  TextColumn get personaName => text()();

  /// Persona background.
  /// Per PRD: 10-300 characters, required.
  TextColumn get personaBackground => text()();

  /// Persona communication style.
  /// Per PRD: 10-200 characters, required.
  TextColumn get personaCommunicationStyle => text()();

  /// Persona signature phrase.
  /// Per PRD: 0-100 characters, optional.
  TextColumn get personaSignaturePhrase => text().nullable()();

  // ==================
  // Original Persona (For Reset)
  // ==================

  /// Original AI-generated persona name.
  TextColumn get originalPersonaName => text()();

  /// Original AI-generated background.
  TextColumn get originalPersonaBackground => text()();

  /// Original AI-generated communication style.
  TextColumn get originalPersonaCommunicationStyle => text()();

  /// Original AI-generated signature phrase.
  TextColumn get originalPersonaSignaturePhrase => text().nullable()();

  // ==================
  // Metadata
  // ==================

  /// UTC timestamp when board member was created.
  DateTimeColumn get createdAtUtc => dateTime()();

  /// UTC timestamp when last modified.
  DateTimeColumn get updatedAtUtc => dateTime()();

  /// Soft delete timestamp.
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();

  /// Sync status.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Server-side version for conflict detection.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
