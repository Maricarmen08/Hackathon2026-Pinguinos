/// Países disponibles. Para agregar uno: una línea aquí, la misma en
/// backend/src/countries.js y su moneda en la migración 003 (solo monedas con 2 decimales).
class CountryInfo {
  final String code, name, currency, symbol, dialCode, currencyName, currencyWord;
  final int utcOffset;
  const CountryInfo(this.code, this.name, this.currency, this.symbol,
      this.dialCode, this.utcOffset, this.currencyName, this.currencyWord);
}

const kCountries = <CountryInfo>[
  CountryInfo('PE', 'Perú', 'PEN', 'S/', '+51', -5, 'Soles', 'soles'),
  CountryInfo('CO', 'Colombia', 'COP', r'$', '+57', -5, 'Pesos colombianos', 'pesos'),
  CountryInfo('MX', 'México', 'MXN', r'$', '+52', -6, 'Pesos mexicanos', 'pesos'),
  CountryInfo('EC', 'Ecuador', 'USD', r'US$', '+593', -5, 'Dólares', 'dólares'),
  CountryInfo('BO', 'Bolivia', 'BOB', 'Bs', '+591', -4, 'Bolivianos', 'bolivianos'),
  CountryInfo('AR', 'Argentina', 'ARS', r'$', '+54', -3, 'Pesos argentinos', 'pesos'),
];

CountryInfo countryByCode(String? code) =>
    kCountries.firstWhere((c) => c.code == code, orElse: () => kCountries.first);

CountryInfo? countryByCurrency(String? currency) {
  for (final c in kCountries) {
    if (c.currency == currency) return c;
  }
  return null;
}
