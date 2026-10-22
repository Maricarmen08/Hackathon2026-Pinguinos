import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/business_model.dart';
import '../models/transaction_model.dart';

class DatabaseService {
  static Future<BusinessModel> fetchBusiness() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/negocio'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BusinessModel.fromJson(data);
      }
    } catch (_) {}
    return BusinessModel(
      id: 1,
      nombreNegocio: 'Bodega Doña Rosa',
      propietario: 'Rosa Quispe',
      rubro: 'Bodega y Abarrotes',
      codigoReferido: 'ROSA2026',
      puntosDifusion: 30,
      scoreCrediticio: 78,
    );
  }

  static Future<List<TransactionModel>> fetchTransactions() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/transacciones'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((item) => TransactionModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [
      TransactionModel(
        id: 1,
        title: '3 Gaseosas + 2 Galletas',
        category: 'Venta mostrador',
        amount: 18.50,
        isIncome: true,
        source: 'voz',
        originalPrompt:
            'Vendí tres gaseosas y dos paquetes de galletas a 18.50',
        timeLabel: 'Hace 10 min',
      ),
      TransactionModel(
        id: 2,
        title: 'Boleta Distribuidora Alicorp',
        category: 'Compra mercadería',
        amount: 65.00,
        isIncome: false,
        source: 'foto',
        originalPrompt: 'BOLETA DE VENTA: Aceite vegetal x6 - S/ 65.00',
        timeLabel: 'Hace 1 hora',
      ),
      TransactionModel(
        id: 3,
        title: 'Venta 5 kg de Arroz y Azúcar',
        category: 'Abarrotes',
        amount: 32.00,
        isIncome: true,
        source: 'voz',
        originalPrompt: 'Cinco kilos de arroz y azúcar por 32 soles',
        timeLabel: '9:15 AM',
      ),
      TransactionModel(
        id: 4,
        title: '2 Botellas de Aceite y Leche',
        category: 'Abarrotes',
        amount: 26.00,
        isIncome: true,
        source: 'voz',
        originalPrompt: 'Dos botellas de aceite y un tarro de leche a 26 soles',
        timeLabel: '8:40 AM',
      ),
    ];
  }

  static Future<bool> saveTransaction(TransactionModel item) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/transacciones'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item.toJson()),
          )
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}

