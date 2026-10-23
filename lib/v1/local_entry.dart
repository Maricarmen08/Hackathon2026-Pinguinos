import 'api_client.dart';

Json localConfirmation(Json entry, String type, Json data) => {
      'entrada': {
        'id_local': entry['id_local'],
        'tipo': entry['tipo'],
        'texto': entry['texto'],
        'propuesta': entry['propuesta']
      },
      'comprobante_id': entry['comprobante_id'],
      'tipo': type,
      'datos': data,
    };
