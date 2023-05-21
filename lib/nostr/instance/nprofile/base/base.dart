abstract class NProfileBase {
  Map<String, dynamic> bech32toMap(String bech32);
  String bech32toHr(String bech32, {int cutLength = 15});
  String mapToBech32(Map<String, dynamic> map);
  String mapToBech32Hr(Map<String, dynamic> map);
}
