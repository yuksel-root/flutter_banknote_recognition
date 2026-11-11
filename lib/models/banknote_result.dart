class BanknoteResult {
  const BanknoteResult({
    required this.value,
    required this.confidence,
    required this.securityFeatures,
  });

  final String value;
  final double confidence;
  final List<String> securityFeatures;
}
