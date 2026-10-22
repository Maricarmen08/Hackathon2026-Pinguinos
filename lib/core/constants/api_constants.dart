import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl =>
      dotenv.env['API_URL'] ?? 'http://127.0.0.1:3000/api';

  static String get dbHost => dotenv.env['DB_HOST'] ?? '127.0.0.1';
  static String get dbPort => dotenv.env['DB_PORT'] ?? '3306';
  static String get dbName => dotenv.env['DB_DATABASE'] ?? 'hackathon_pinguinos';
}

