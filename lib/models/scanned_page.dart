enum PageQuality { good, blurry, partial, unknown }
enum EnhancementMode { original, blackAndWhite, enhanced, highContrast, colorPreserve }

class ScannedPage {
  final String id;
  String documentId;
  int pageNumber;
  String imagePath;
  String? enhancedPath;
  String? ocrText;
  double blurScore;
  PageQuality quality;
  EnhancementMode enhancementMode;
  bool isRotated;
  int rotationDegrees;
  final DateTime createdAt;

  ScannedPage({
    required this.id,
    required this.documentId,
    required this.pageNumber,
    required this.imagePath,
    this.enhancedPath,
    this.ocrText,
    this.blurScore = 0.0,
    this.quality = PageQuality.unknown,
    this.enhancementMode = EnhancementMode.original,
    this.isRotated = false,
    this.rotationDegrees = 0,
    required this.createdAt,
  });

  String get displayPath => enhancedPath ?? imagePath;

  bool get isBlurry => quality == PageQuality.blurry;
  bool get isGood => quality == PageQuality.good;

  Map<String, dynamic> toMap() => {
        'id': id,
        'document_id': documentId,
        'page_number': pageNumber,
        'image_path': imagePath,
        'enhanced_path': enhancedPath,
        'ocr_text': ocrText,
        'blur_score': blurScore,
        'quality': quality.index,
        'enhancement_mode': enhancementMode.index,
        'rotation_degrees': rotationDegrees,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ScannedPage.fromMap(Map<String, dynamic> map) => ScannedPage(
        id: map['id'],
        documentId: map['document_id'],
        pageNumber: map['page_number'],
        imagePath: map['image_path'],
        enhancedPath: map['enhanced_path'],
        ocrText: map['ocr_text'],
        blurScore: (map['blur_score'] as num?)?.toDouble() ?? 0.0,
        quality: PageQuality.values[map['quality'] ?? 3],
        enhancementMode: EnhancementMode.values[map['enhancement_mode'] ?? 0],
        rotationDegrees: map['rotation_degrees'] ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      );

  ScannedPage copyWith({
    String? documentId,
    int? pageNumber,
    String? imagePath,
    String? enhancedPath,
    String? ocrText,
    double? blurScore,
    PageQuality? quality,
    EnhancementMode? enhancementMode,
    bool? isRotated,
    int? rotationDegrees,
  }) =>
      ScannedPage(
        id: id,
        documentId: documentId ?? this.documentId,
        pageNumber: pageNumber ?? this.pageNumber,
        imagePath: imagePath ?? this.imagePath,
        enhancedPath: enhancedPath ?? this.enhancedPath,
        ocrText: ocrText ?? this.ocrText,
        blurScore: blurScore ?? this.blurScore,
        quality: quality ?? this.quality,
        enhancementMode: enhancementMode ?? this.enhancementMode,
        isRotated: isRotated ?? this.isRotated,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        createdAt: createdAt,
      );
}
