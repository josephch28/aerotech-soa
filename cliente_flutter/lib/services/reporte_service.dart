import '../models/dashboard.dart';
import 'api_client.dart';

class ReporteService {
  static Future<Dashboard> dashboard() async =>
      Dashboard.fromJson(await ApiClient.get('/api/reportes/dashboard') as Map<String, dynamic>);
}
