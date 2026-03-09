import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/meal_model.dart';

class LocalDbService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'smart_chef_planner.db');

    return await openDatabase(
      path,
      version: 2, // Incremented version to trigger onUpgrade for the new table
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE meals(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            type TEXT,
            kcal INTEGER,
            imageUrl TEXT,
            ingredients TEXT,
            steps TEXT,
            date TEXT,
            isSocialPost INTEGER DEFAULT 0 
          )
        ''');

        await db.execute('''
          CREATE TABLE grocery_items(
            name TEXT PRIMARY KEY,
            price REAL,
            category TEXT DEFAULT 'General'
          )
        ''');

        // NEW: Profile table for Hybrid Data Management
        await db.execute('''
          CREATE TABLE user_profile(
            id TEXT PRIMARY KEY,
            username TEXT,
            avatar_url TEXT,
            last_synced TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_posts(
            id TEXT PRIMARY KEY,
            user_id TEXT,
            title TEXT,
            content TEXT,
            image_url TEXT,
            author_name TEXT,
            author_avatar TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_liked_posts(
            id TEXT PRIMARY KEY,
            user_id TEXT,
            title TEXT,
            content TEXT,
            image_url TEXT,
            author_name TEXT,
            author_avatar TEXT,
            created_at TEXT
          )
        ''');

      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE user_profile(
              id TEXT PRIMARY KEY,
              username TEXT,
              avatar_url TEXT,
              last_synced TEXT
            )
          ''');
        }
      },
    );
  }

  // --- EXISTING MEAL METHODS ---

  Future<int> insertMeal(Meal meal) async {
    final db = await database;
    return await db.insert('meals', meal.toMap());
  }

  Future<int> updateMeal(Meal meal) async {
    final db = await database;
    return await db.update(
      'meals',
      meal.toMap(),
      where: 'id = ?',
      whereArgs: [meal.id],
    );
  }

  Future<void> updateAllMealsWithTitle({
    required String title,
    required String ingredients,
    required String steps,
    required int kcal,
  }) async {
    final db = await database;
    await db.update(
      'meals',
      {
        'ingredients': ingredients,
        'steps': steps,
        'kcal': kcal,
        'isSocialPost': 0,
      },
      where: 'title = ?',
      whereArgs: [title],
    );
  }

  Future<List<Meal>> getMealsByDate(String dateString) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meals',
      where: 'date = ?',
      whereArgs: [dateString],
    );
    return List.generate(maps.length, (i) => Meal.fromMap(maps[i]));
  }

  Future<void> deleteMeal(int id) async {
    final db = await database;
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  // --- EXISTING GROCERY METHODS ---

  Future<int> upsertGroceryItem(String name, double price, String category) async {
    final db = await database;
    return await db.insert(
      'grocery_items',
      {'name': name, 'price': price, 'category': category},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllGroceryItems() async {
    final db = await database;
    return await db.query('grocery_items');
  }

  Future<int> removeGroceryItem(String name) async {
    final db = await database;
    return await db.delete('grocery_items', where: 'name = ?', whereArgs: [name]);
  }

  // --- NEW PROFILE METHODS (For Hybrid/Local Management) ---

  Future<int> saveLocalProfile(Map<String, dynamic> profileData) async {
    final db = await database;
    // Add a timestamp to know when we last synced with Supabase
    profileData['last_synced'] = DateTime.now().toIso8601String();

    return await db.insert(
      'user_profile',
      profileData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLocalProfile(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> clearLocalProfile() async {
    final db = await database;
    await db.delete('user_profile');
  }

  Future<void> savePostsLocally(List<dynamic> posts) async {
    final db = await database;
    Batch batch = db.batch(); // Use batch for faster multiple inserts

    for (var post in posts) {
      batch.insert(
        'cached_posts',
        {
          'id': post['id'].toString(),
          'user_id': post['user_id'],
          'title': post['title'],
          'content': post['content'],
          'image_url': post['image_url'],
          'author_name': post['profiles']?['username'] ?? 'Unknown',
          'author_avatar': post['profiles']?['avatar_url'] ?? '',
          'created_at': post['created_at'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getLocalPosts() async {
    final db = await database;
    return await db.query('cached_posts', orderBy: 'created_at DESC');
  }

  Future<void> saveLikedPostsLocally(List<dynamic> likedData) async {
    final db = await database;
    Batch batch = db.batch();

    // Clear out the old cached likes to ensure we don't show un-liked posts
    await db.delete('cached_liked_posts');

    for (var item in likedData) {
      final post = item['posts']; // Extract the actual post data
      if (post != null) {
        batch.insert(
          'cached_liked_posts',
          {
            'id': post['id'].toString(),
            'user_id': post['user_id'],
            'title': post['title'],
            'content': post['content'],
            'image_url': post['image_url'],
            'author_name': post['profiles']?['username'] ?? 'Unknown',
            'author_avatar': post['profiles']?['avatar_url'] ?? '',
            'created_at': post['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getLocalLikedPosts() async {
    final db = await database;
    return await db.query('cached_liked_posts', orderBy: 'created_at DESC');
  }

}