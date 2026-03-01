class Meal {
  final int? id; // SQLite auto-increments this
  final String title;
  final String type; // Breakfast, Lunch, Dinner
  final int kcal;
  final String imageUrl;
  final String ingredients; // Saved as "Eggs, Milk, Flour"
  final String steps;       // Saved as "1. Mix\n2. Cook"
  final String date;        // Format: "2024-05-20"

  Meal({
    this.id,
    required this.title,
    required this.type,
    required this.kcal,
    required this.imageUrl,
    required this.ingredients,
    required this.steps,
    required this.date,
  });

  // Convert Meal object to a Map for SQL insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'kcal': kcal,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'steps': steps,
      'date': date,
    };
  }

  // Convert Map from SQL back into a Meal object
  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map['id'],
      title: map['title'],
      type: map['type'],
      kcal: map['kcal'],
      imageUrl: map['imageUrl'],
      ingredients: map['ingredients'],
      steps: map['steps'],
      date: map['date'],
    );
  }
}