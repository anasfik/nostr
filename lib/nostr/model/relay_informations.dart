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
      contact: json['contact'],
      description: json['description'],
      name: json['name'],
      pubkey: json['pubkey'],
      software: json['software'],
      supportedNips: supportedNips,
      version: json['version'],
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
