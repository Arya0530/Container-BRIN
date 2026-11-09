import 'json_data.dart';

class UiContainer {
  const UiContainer({
    required this.id,
    required this.series,
    required this.company,
    required this.destination,
    required this.contents,
    required this.package,
    required this.status,
  });

  final int id;
  final String series;
  final String company;
  final String destination;
  final String contents;
  final String package;
  final String status;

  factory UiContainer.fromJson(Map<String, dynamic> json) {
    final companyValue = jsonPick(json, [
      'company_name',
      'companyName',
      'company',
    ]);
    final companyName = companyValue is Map
        ? jsonString(
            jsonPick(jsonMap(companyValue), [
              'company_name',
              'companyName',
              'name',
            ]),
          )
        : jsonString(companyValue);
    return UiContainer(
      id:
          jsonInteger(jsonPick(json, ['container_id', 'containerId', 'id'])) ??
          -1,
      series: jsonString(
        jsonPick(json, ['series', 'serial_number', 'serialNumber']),
      ),
      company: companyName,
      destination: jsonString(
        jsonPick(json, ['destination', 'destination_name']),
      ),
      contents: jsonString(jsonPick(json, ['contents', 'content', 'cargo'])),
      package: jsonString(
        jsonPick(json, ['package', 'packages', 'package_count']),
      ),
      status: jsonString(
        jsonPick(json, ['status', 'container_status']),
        'Unknown',
      ),
    );
  }
}
