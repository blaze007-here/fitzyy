import "package:supabase_flutter/supabase_flutter.dart";

import '../models/food_scan.dart';
import '../models/user_data.dart';

class UserDataBundle {
  const UserDataBundle({
    required this.profile,
    required this.preferences,
    required this.setting,
    required this.scans,
    required this.customFoods,
    required this.habits,
  });

  final UserProfile profile;
  final UserPreferences preferences;
  final UserSetting setting;
  final List<FoodScan> scans;
  final List<CustomFood> customFoods;
  final List<UserHabit> habits;
}

class SupabaseRepository {
  SupabaseRepository(this.client);

  final SupabaseClient client;

  String get userId => client.auth.currentUser!.id;

  Future<UserDataBundle> loadUserData() async {
    final id = userId;
    await _ensureDefaults();

    final profileMap = await client
        .from('profiles')
        .select()
        .eq('id', id)
        .single();
    final preferencesMap = await client
        .from('user_preferences')
        .select()
        .eq('user_id', id)
        .single();
    final settingMap = await client
        .from('user_settings')
        .select()
        .eq('user_id', id)
        .single();
    final scans = await client
        .from('scan_records')
        .select()
        .eq('user_id', id)
        .order('scanned_at', ascending: false);
    final foods = await client
        .from('custom_foods')
        .select()
        .eq('user_id', id)
        .order('name');
    final habits = await client
        .from('habits')
        .select()
        .eq('user_id', id)
        .eq('active', true)
        .order('created_at');

    return UserDataBundle(
      profile: UserProfile.fromMap(Map<String, dynamic>.from(profileMap)),
      preferences: UserPreferences.fromMap(
        Map<String, dynamic>.from(preferencesMap),
      ),
      setting: UserSetting.fromMap(Map<String, dynamic>.from(settingMap)),
      scans: (scans as List<dynamic>)
          .map((row) => FoodScan.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(),
      customFoods: (foods as List<dynamic>)
          .map(
            (row) => CustomFood.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      habits: (habits as List<dynamic>)
          .map(
            (row) => UserHabit.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
    );
  }

  Future<void> _ensureDefaults() async {
    final user = client.auth.currentUser!;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    await client.from('profiles').upsert({
      'id': user.id,
      'display_name':
          (metadata['full_name'] as String?) ??
          (metadata['name'] as String?) ??
          '',
      'avatar_url': metadata['avatar_url'] as String?,
    }, onConflict: 'id');

    final preferences = await client
        .from('user_preferences')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (preferences == null) {
      await client.from('user_preferences').insert({'user_id': user.id});
    }

    final settings = await client
        .from('user_settings')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (settings == null) {
      await client.from('user_settings').insert({'user_id': user.id});
    }
  }

  Future<FoodScan> saveScan(FoodScan scan) async {
    final row = await client
        .from('scan_records')
        .insert(scan.toRecordMap(userId: userId))
        .select()
        .single();
    return FoodScan.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> updateProfile(UserProfile profile) async {
    await client
        .from('profiles')
        .update(profile.toMap()..remove('id'))
        .eq('id', userId);
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    await client
        .from('user_preferences')
        .upsert(preferences.toMap(), onConflict: 'user_id');
  }

  Future<void> updateSetting(UserSetting setting) async {
    await client
        .from('user_settings')
        .upsert(setting.toMap(), onConflict: 'user_id');
  }

  Future<CustomFood> addCustomFood({
    required String name,
    required String serving,
    required NutritionSnapshot nutrition,
    List<String> ingredients = const [],
  }) async {
    final row = await client
        .from('custom_foods')
        .insert({
          'user_id': userId,
          'name': name,
          'serving': serving,
          ...nutrition.toMap(),
          'ingredients': ingredients,
        })
        .select()
        .single();
    return CustomFood.fromMap(Map<String, dynamic>.from(row));
  }

  Future<CustomFood> updateCustomFood(CustomFood food) async {
    final row = await client
        .from('custom_foods')
        .update({
          'name': food.name,
          'serving': food.serving,
          ...food.nutrition.toMap(),
          'ingredients': food.ingredients,
        })
        .eq('id', food.id)
        .eq('user_id', userId)
        .select()
        .single();
    return CustomFood.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteCustomFood(CustomFood food) async {
    await client
        .from('custom_foods')
        .delete()
        .eq('id', food.id)
        .eq('user_id', userId);
  }

  Future<UserHabit> addHabit({
    required String name,
    int target = 1,
    String unit = 'time',
  }) async {
    final row = await client
        .from('habits')
        .insert({
          'user_id': userId,
          'name': name,
          'target': target,
          'unit': unit,
        })
        .select()
        .single();
    return UserHabit.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> signOut() => client.auth.signOut();
}
