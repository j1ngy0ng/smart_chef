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
    // Get the location of the database file on the phone
    String path = join(await getDatabasesPath(), 'smart_chef_planner.db');

    return await openDatabase(
      path,
      version: 1,
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
            date TEXT
          )
        ''');
      },
    );
  }

  // Insert a new meal into the local database
  Future<int> insertMeal(Meal meal) async {
    final db = await database;
    return await db.insert('meals', meal.toMap());
  }

  // Fetch meals saved for a specific date
  Future<List<Meal>> getMealsByDate(String dateString) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meals',
      where: 'date = ?',
      whereArgs: [dateString],
    );
    return maps.map((item) => Meal.fromMap(item)).toList();
  }

  Future<void> deleteMeal(int id) async {
    final db = await database;
    await db.delete(
      'meals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

