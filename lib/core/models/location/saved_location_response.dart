import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'saved_location_response.g.dart';

@JsonSerializable()
class SavedLocationResponse extends Equatable {
  const SavedLocationResponse({
    required this.name,
    required this.longitude,
    required this.latitude,
  });

  factory SavedLocationResponse.fromJson(Map<String, dynamic> json) =>
      _$SavedLocationResponseFromJson(json);

  final String name;
  final String longitude;
  final String latitude;

  Map<String, dynamic> toJson() => _$SavedLocationResponseToJson(this);

  @override
  List<Object?> get props => [name, longitude, latitude];
}
