class AutocompleteSuggestion {
  final String id;
  final String description;
  final String? name;
  final String? location;

  AutocompleteSuggestion({
    required this.id,
    required this.description,
    this.name,
    this.location,
  });

  factory AutocompleteSuggestion.fromJson(Map<String, dynamic> json) {
    // Handle both direct JSON and nested properties
    final properties = json['properties'] as Map<String, dynamic>? ?? json;

    return AutocompleteSuggestion(
      id: properties['gid']?.toString() ?? properties['id']?.toString() ?? '',
      description: properties['name']?.toString() ??
          properties['description']?.toString() ??
          '',
      name: properties['name']?.toString(),
      location: properties['coarse_location']?.toString(),
    );
  }
}
