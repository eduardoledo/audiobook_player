enum PathSegmentRole {
  author,
  category,
  bookTitle,
  part,
  ignore,
  universe,
  saga,
  era;

  String get label {
    switch (this) {
      case PathSegmentRole.author:
        return 'Autor';
      case PathSegmentRole.category:
      case PathSegmentRole.universe:
      case PathSegmentRole.saga:
      case PathSegmentRole.era:
        return 'Categoría / Subcategoría';
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
            ?.map((e) {
              final str = e.toString();
              if (str == 'universe' || str == 'saga' || str == 'era') {
                return PathSegmentRole.category;
              }
              return PathSegmentRole.values.firstWhere(
                (r) => r.name == str,
                orElse: () => PathSegmentRole.ignore,
              );
            })
            .toList() ??
        [];
    return PathPatternRule(
      rootPath: json['rootPath'] as String? ?? '',
      roles: rolesList,
    );
  }
}
