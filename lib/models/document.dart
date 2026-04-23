class Document {
  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  int pageCount;
  String? pdfPath;
  String? thumbnailPath;
  String folder;

  Document({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.pageCount = 0,
    this.pdfPath,
    this.thumbnailPath,
    this.folder = 'Default',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'page_count': pageCount,
        'pdf_path': pdfPath,
        'thumbnail_path': thumbnailPath,
        'folder': folder,
      };

  factory Document.fromMap(Map<String, dynamic> map) => Document(
        id: map['id'],
        name: map['name'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
        pageCount: map['page_count'] ?? 0,
        pdfPath: map['pdf_path'],
        thumbnailPath: map['thumbnail_path'],
        folder: map['folder'] ?? 'Default',
      );

  Document copyWith({
    String? name,
    DateTime? updatedAt,
    int? pageCount,
    String? pdfPath,
    String? thumbnailPath,
    String? folder,
  }) =>
      Document(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        pageCount: pageCount ?? this.pageCount,
        pdfPath: pdfPath ?? this.pdfPath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        folder: folder ?? this.folder,
      );
}
