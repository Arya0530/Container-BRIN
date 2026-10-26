
class ContainerModel {
  final int containerId;
  final String series;
  final String deviceId;
  final String companyName;
  final String destination;
  final String status;

  const ContainerModel({
    required this.containerId,
    required this.series,
    required this.deviceId,
    required this.companyName,
    required this.destination,
    required this.status,
  });

  // Convert an API JSON object into a Dart model.
  factory ContainerModel.fromJson(Map<String, dynamic> json) {
    return ContainerModel(
      containerId: json['container_id'] as int,
      series: json['series'] as String,
      deviceId: json['device_id'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}
