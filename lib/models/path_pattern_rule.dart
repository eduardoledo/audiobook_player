enum PathSegmentRole {
  author,
  universe,
  saga,
  era,
  bookTitle,
  part,
  ignore;

  String get label {
    switch (this) {
      case PathSegmentRole.author:
        return 'Autor';
      case PathSegmentRole.universe:
        return 'Universo';
      case PathSegmentRole.saga:
        return 'Saga / Serie';
      case PathSegmentRole.era:
        return 'Era';
      case PathSegmentRole.bookTitle:
        return 'Título de Libro';
      case PathSegmentRole.part:
        return 'Parte / Disco';
      case PathSegmentRole.ignore:
        return 'Ignorar';
    }
  }
}

class PathPatternRule {
  final String rootPath;
  final List<PathSegmentRole> roles;

  const PathPatternRule({
    required this.rootPath,
    required this.roles,
  });

  Map<String, dynamic> toJson() {
    return {
      'rootPath': rootPath,
      'roles': roles.map((r) => r.name).toList(),
    };
  }

  factory PathPatternRule.fromJson(Map<String, dynamic> json) {
    final rolesList = (json['roles'] as List<dynamic>?)
            ?.map((e) => PathSegmentRole.values.firstWhere(
                  (r) => r.name == e.toString(),
                  orElse: () => PathSegmentRole.ignore,
                ))
            .toList() ??
        [];
    return PathPatternRule(
      rootPath: json['rootPath'] as String? ?? '',
      roles: rolesList,
    );
  }
}
