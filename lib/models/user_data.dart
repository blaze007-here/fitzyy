import 'food_scan.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    this.displayName = '',
    this.avatarUrl,
    this.goalLabel = 'Balanced eating',
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String goalLabel;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: (map['display_name'] as String?) ?? '',
      avatarUrl: map['avatar_url'] as String?,
      goalLabel: (map['goal_label'] as String?) ?? 'Balanced eating',
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? goalLabel,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      goalLabel: goalLabel ?? this.goalLabel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'goal_label': goalLabel,
    };
  }
}

class UserPreferences {
  const UserPreferences({
    required this.userId,
    this.dailyCalorieGoal = 2000,
    this.proteinGoal = 120,
    this.carbsGoal = 220,
    this.fatGoal = 70,
    this.dietaryPreferences = const [],
    this.units = 'metric',
    this.timezone = 'UTC',
  });

  final String userId;
  final int dailyCalorieGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final List<String> dietaryPreferences;
  final String units;
  final String timezone;

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      userId: map['user_id'] as String,
      dailyCalorieGoal: (map['daily_calorie_goal'] as num?)?.toInt() ?? 2000,
      proteinGoal: (map['protein_goal'] as num?)?.toDouble() ?? 120,
      carbsGoal: (map['carbs_goal'] as num?)?.toDouble() ?? 220,
      fatGoal: (map['fat_goal'] as num?)?.toDouble() ?? 70,
      dietaryPreferences: List<String>.from(
        (map['dietary_preferences'] as List<dynamic>?) ?? const [],
      ),
      units: (map['units'] as String?) ?? 'metric',
      timezone: (map['timezone'] as String?) ?? 'UTC',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'daily_calorie_goal': dailyCalorieGoal,
      'protein_goal': proteinGoal,
      'carbs_goal': carbsGoal,
      'fat_goal': fatGoal,
      'dietary_preferences': dietaryPreferences,
      'units': units,
      'timezone': timezone,
    };
  }

  UserPreferences copyWith({
    int? dailyCalorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    List<String>? dietaryPreferences,
    String? units,
    String? timezone,
  }) {
    return UserPreferences(
      userId: userId,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      units: units ?? this.units,
      timezone: timezone ?? this.timezone,
    );
  }
}

class UserSetting {
  const UserSetting({
    required this.userId,
    this.privacyMode = true,
    this.notificationsEnabled = true,
  });

  final String userId;
  final bool privacyMode;
  final bool notificationsEnabled;

  factory UserSetting.fromMap(Map<String, dynamic> map) {
    return UserSetting(
      userId: map['user_id'] as String,
      privacyMode: (map['privacy_mode'] as bool?) ?? true,
      notificationsEnabled: (map['notifications_enabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'privacy_mode': privacyMode,
      'notifications_enabled': notificationsEnabled,
    };
  }
}

class CustomFood {
  const CustomFood({
    required this.id,
    required this.userId,
    required this.name,
    required this.serving,
    required this.nutrition,
    this.ingredients = const [],
  });

  final String id;
  final String userId;
  final String name;
  final String serving;
  final NutritionSnapshot nutrition;
  final List<String> ingredients;

  factory CustomFood.fromMap(Map<String, dynamic> map) {
    return CustomFood(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      serving: (map['serving'] as String?) ?? '1 serving',
      nutrition: NutritionSnapshot.fromMap(map),
      ingredients: List<String>.from(
        (map['ingredients'] as List<dynamic>?) ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'serving': serving,
      ...nutrition.toMap(),
      'ingredients': ingredients,
    };
  }

  CustomFood copyWith({
    String? name,
    String? serving,
    NutritionSnapshot? nutrition,
    List<String>? ingredients,
  }) {
    return CustomFood(
      id: id,
      userId: userId,
      name: name ?? this.name,
      serving: serving ?? this.serving,
      nutrition: nutrition ?? this.nutrition,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  FoodScan toFoodScan() {
    return FoodScan(
      id: id,
      name: name,
      subtitle: 'Saved food · $serving',
      emoji: '🍽️',
      rating: 0,
      ratingLabel: 'custom food',
      confidence: 1,
      serving: serving,
      nutrition: NutritionInfo(
        calories: nutrition.calories,
        protein: nutrition.protein,
        carbs: nutrition.carbs,
        fat: nutrition.fat,
        fiber: nutrition.fiber,
        sodium: nutrition.sodium,
      ),
      ingredients: ingredients,
      insight: 'Saved from your personal food library.',
    );
  }
}

class UserHabit {
  const UserHabit({
    required this.id,
    required this.userId,
    required this.name,
    this.target = 1,
    this.unit = 'time',
    this.active = true,
  });

  final String id;
  final String userId;
  final String name;
  final int target;
  final String unit;
  final bool active;

  factory UserHabit.fromMap(Map<String, dynamic> map) {
    return UserHabit(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      target: (map['target'] as num?)?.toInt() ?? 1,
      unit: (map['unit'] as String?) ?? 'time',
      active: (map['active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'target': target,
      'unit': unit,
      'active': active,
    };
  }
}

class NutritionSnapshot {
  const NutritionSnapshot({
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

  factory NutritionSnapshot.fromMap(Map<String, dynamic> map) {
    return NutritionSnapshot(
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0,
      sodium: (map['sodium'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sodium': sodium,
    };
  }
}
