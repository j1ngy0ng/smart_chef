class Meal {
  final int? id;
  final String title;
  final String type;
  final int kcal;
  final String imageUrl;
  final String ingredients;
  final String steps;
  final String date;
  // NEW: Flag to identify if this is an unstructured community post
  final bool isSocialPost;

  Meal({
    this.id,
    required this.title,
    required this.type,
    required this.kcal,
    required this.imageUrl,
    required this.ingredients,
    required this.steps,
    required this.date,
    this.isSocialPost = false, // Default is false (structured)
  });

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
      // SQLite stores booleans as 1 (true) or 0 (false)
      'isSocialPost': isSocialPost ? 1 : 0,
    };
  }

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
      // Convert the 1/0 back to a boolean
      isSocialPost: map['isSocialPost'] == 1,
    );
  }
}