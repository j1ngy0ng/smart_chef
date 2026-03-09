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
      version: 1, // Reset to version 1
      onCreate: (db, version) async {
        // Single source of truth for your tables
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
      },
    );
  }

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
      whereArgs: [meal.id], // This targets the specific meal we just fixed
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
        'isSocialPost': 0, // 0 = false in SQLite. This hides the "Fix" button for all.
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
    await db.delete(
      'meals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- NEW GROCERY METHODS ---

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
}