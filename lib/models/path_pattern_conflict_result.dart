import '../models/path_pattern_rule.dart';

class PathPatternConflictResult {
  final bool hasConflict;
  final PathPatternRule? conflictingRule;
  final String? reason;

  const PathPatternConflictResult({
    required this.hasConflict,
    this.conflictingRule,
    this.reason,
  });

  static const clean = PathPatternConflictResult(hasConflict: false);
}
