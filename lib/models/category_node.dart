class CategoryNode {
  final int? id;
  final String name;
  final int lft;
  final int rgt;
  final int depth;
  final int? parentId;
  final String pathPrefix;
  final double? parentOrder;

  const CategoryNode({
    this.id,
    required this.name,
    required this.lft,
    required this.rgt,
    required this.depth,
    this.parentId,
    required this.pathPrefix,
    this.parentOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'lft': lft,
      'rgt': rgt,
      'depth': depth,
      'parent_id': parentId,
      'path_prefix': pathPrefix,
      if (parentOrder != null) 'parent_order': parentOrder,
    };
  }

  factory CategoryNode.fromMap(Map<String, dynamic> map) {
    return CategoryNode(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      lft: map['lft'] as int? ?? 0,
      rgt: map['rgt'] as int? ?? 0,
      depth: map['depth'] as int? ?? 0,
      parentId: map['parent_id'] as int?,
      pathPrefix: map['path_prefix'] as String? ?? '',
      parentOrder: (map['parent_order'] as num?)?.toDouble(),
    );
  }

  CategoryNode copyWith({
    int? id,
    String? name,
    int? lft,
    int? rgt,
    int? depth,
    int? parentId,
    String? pathPrefix,
    double? parentOrder,
  }) {
    return CategoryNode(
      id: id ?? this.id,
      name: name ?? this.name,
      lft: lft ?? this.lft,
      rgt: rgt ?? this.rgt,
      depth: depth ?? this.depth,
      parentId: parentId ?? this.parentId,
      pathPrefix: pathPrefix ?? this.pathPrefix,
      parentOrder: parentOrder ?? this.parentOrder,
    );
  }
}
