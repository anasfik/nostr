import 'package:equatable/equatable.dart';

class RelayInformations extends Equatable {
  final String? contact;
  final String? description;
  final String? name;
  final String? pubkey;
  final String? software;
  final List<int>? supportedNips;
  final String? version;

  RelayInformations({
    required this.contact,
    required this.description,
    required this.name,
    required this.pubkey,
    required this.software,
    required this.supportedNips,
    required this.version,
  });

  factory RelayInformations.fromNip11Response(Map<String, dynamic> json) {
    final supportedNips = json['supported_nips'].cast<int>();

    return RelayInformations(
      contact: json['contact'] as String?,
      description: json['description'] as String?,
      name: json['name'] as String?,
      pubkey: json['pubkey'] as String?,
      software: json['software'] as String?,
      supportedNips: supportedNips as List<int>?,
      version: json['version'] as String?,
    );
  }
  @override
  List<Object?> get props => [
        contact,
        description,
        name,
        pubkey,
        software,
        supportedNips,
        version,
      ];
}
