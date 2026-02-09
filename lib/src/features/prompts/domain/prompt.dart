
class Prompt {
  final String id;
  final String name; // e.g., 'extraction', 'quality_analysis', 'similarity'
  final String template;
  final String description;

  Prompt({
    required this.id,
    required this.name,
    required this.template,
    required this.description,
  });

  factory Prompt.fromMap(Map<String, dynamic> map, String id) {
    return Prompt(
      id: id,
      name: map['name'] ?? '',
      template: map['template'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'template': template,
      'description': description,
    };
  }
}
