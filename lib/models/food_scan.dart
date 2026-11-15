class NutritionInfo {
  const NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodium,
  });

  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sodium;

  NutritionInfo scaled(double factor) {
    return NutritionInfo(
      calories: (calories * factor).round(),
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
      fiber: fiber * factor,
      sodium: sodium * factor,
    );
  }
}

class FoodScan {
  const FoodScan({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.rating,
    required this.ratingLabel,
    required this.confidence,
    required this.serving,
    required this.nutrition,
    required this.ingredients,
    required this.insight,
    this.scannedAt,
  });

  final String id;
  final String name;
  final String subtitle;
  final String emoji;
  final int rating;
  final String ratingLabel;
  final double confidence;
  final String serving;
  final NutritionInfo nutrition;
  final List<String> ingredients;
  final String insight;
  final DateTime? scannedAt;

  factory FoodScan.fromMap(Map<String, dynamic> map) {
    return FoodScan(
      id:
          (map['id'] as String?) ??
          'scan-${DateTime.now().microsecondsSinceEpoch}',
      name: (map['food_name'] as String?) ?? 'Food scan',
      subtitle: (map['subtitle'] as String?) ?? '',
      emoji: (map['emoji'] as String?) ?? '🍽️',
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      ratingLabel: (map['rating_label'] as String?) ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      serving: (map['serving'] as String?) ?? '1 serving',
      nutrition: NutritionInfo(
        calories: (map['calories'] as num?)?.toInt() ?? 0,
        protein: (map['protein'] as num?)?.toDouble() ?? 0,
        carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
        fat: (map['fat'] as num?)?.toDouble() ?? 0,
        fiber: (map['fiber'] as num?)?.toDouble() ?? 0,
        sodium: (map['sodium'] as num?)?.toDouble() ?? 0,
      ),
      ingredients: List<String>.from(
        (map['ingredients'] as List<dynamic>?) ?? const [],
      ),
      insight: (map['insight'] as String?) ?? '',
      scannedAt: DateTime.tryParse(map['scanned_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toRecordMap({required String userId}) {
    return {
      'user_id': userId,
      'food_name': name,
      'subtitle': subtitle,
      'emoji': emoji,
      'rating': rating,
      'rating_label': ratingLabel,
      'confidence': confidence,
      'serving': serving,
      'calories': nutrition.calories,
      'protein': nutrition.protein,
      'carbs': nutrition.carbs,
      'fat': nutrition.fat,
      'fiber': nutrition.fiber,
      'sodium': nutrition.sodium,
      'ingredients': ingredients,
      'insight': insight,
      'scanned_at': (scannedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  FoodScan copyWith({
    NutritionInfo? nutrition,
    String? serving,
    DateTime? scannedAt,
  }) {
    return FoodScan(
      id: id,
      name: name,
      subtitle: subtitle,
      emoji: emoji,
      rating: rating,
      ratingLabel: ratingLabel,
      confidence: confidence,
      serving: serving ?? this.serving,
      nutrition: nutrition ?? this.nutrition,
      ingredients: ingredients,
      insight: insight,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}

const sampleScans = <FoodScan>[
  FoodScan(
    id: 'salmon-grain-bowl',
    name: 'Salmon grain bowl',
    subtitle: 'Roasted salmon · greens · quinoa',
    emoji: '🥗',
    rating: 92,
    ratingLabel: 'excellent balance',
    confidence: 0.94,
    serving: '1 bowl · 420 g',
    nutrition: NutritionInfo(
      calories: 584,
      protein: 38,
      carbs: 48,
      fat: 24,
      fiber: 9,
      sodium: 612,
    ),
    ingredients: [
      'Roasted salmon',
      'Quinoa',
      'Edamame',
      'Avocado',
      'Sesame greens',
    ],
    insight:
        'High in omega-3s and fiber. A squeeze of lemon adds flavor without extra sodium.',
  ),
  FoodScan(
    id: 'avocado-toast',
    name: 'Avocado toast',
    subtitle: 'Sourdough · avocado · poached egg',
    emoji: '🥑',
    rating: 86,
    ratingLabel: 'nutrient dense',
    confidence: 0.91,
    serving: '2 slices · 238 g',
    nutrition: NutritionInfo(
      calories: 412,
      protein: 17,
      carbs: 43,
      fat: 20,
      fiber: 11,
      sodium: 488,
    ),
    ingredients: ['Sourdough bread', 'Avocado', 'Poached egg', 'Chili flakes'],
    insight:
        'A satisfying mix of slow carbs and healthy fats. Add berries for a little more vitamin C.',
  ),
  FoodScan(
    id: 'berry-yogurt',
    name: 'Berry yogurt cup',
    subtitle: 'Greek yogurt · berries · almond crunch',
    emoji: '🫐',
    rating: 89,
    ratingLabel: 'light & bright',
    confidence: 0.96,
    serving: '1 cup · 285 g',
    nutrition: NutritionInfo(
      calories: 298,
      protein: 22,
      carbs: 35,
      fat: 8,
      fiber: 7,
      sodium: 132,
    ),
    ingredients: [
      'Greek yogurt',
      'Blueberries',
      'Strawberries',
      'Almond granola',
    ],
    insight:
        'Protein-forward and naturally sweet. Watch granola portions if you are tracking added sugar.',
  ),
];
