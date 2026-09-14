class Unit {
  const Unit({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String id;
  final String code;
  final String name;
  final String symbol;
}

class Person {
  const Person({
    required this.id,
    required this.kind,
    required this.document,
    required this.name,
    required this.phone,
    this.companyName = '',
    this.responsibleName = '',
    this.birthDate = '',
    this.gender = '',
    this.addresses = const [],
  });

  final String id;
  final String kind;
  final String document;
  final String name;
  final String phone;
  final String companyName;
  final String responsibleName;
  final String birthDate;
  final String gender;
  final List<Address> addresses;

  String get displayName => kind == 'PJ' && companyName.isNotEmpty ? companyName : name;
}

class Address {
  const Address({
    this.id = '',
    this.alias = '',
    this.zip = '',
    this.street = '',
    this.number = '',
    this.complement = '',
    this.district = '',
    this.city = '',
    this.state = '',
  });

  final String id;
  final String alias;
  final String zip;
  final String street;
  final String number;
  final String complement;
  final String district;
  final String city;
  final String state;

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'alias': alias,
        'zip': zip,
        'street': street,
        'number': number,
        'complement': complement,
        'district': district,
        'city': city,
        'state': state,
      };

  String get label {
    final line = [
      if (street.isNotEmpty) '$street${number.isEmpty ? '' : ', $number'}',
      if (district.isNotEmpty) district,
      if (city.isNotEmpty) '$city${state.isEmpty ? '' : '/$state'}',
      if (zip.isNotEmpty) zip,
    ].join(' · ');
    if (alias.isEmpty) return line.isEmpty ? '—' : line;
    return line.isEmpty ? alias : '$alias — $line';
  }
}

class PaymentMethod {
  const PaymentMethod({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;
}

class PaymentTerm {
  const PaymentTerm({
    required this.id,
    required this.code,
    required this.name,
    required this.installments,
  });

  final String id;
  final String code;
  final String name;
  final List<Installment> installments;

  String get summary =>
      installments.map((i) => '${i.percent}% em ${i.days}d').join(' · ');
}

class Installment {
  const Installment({required this.days, required this.percent});

  final int days;
  final double percent;

  Map<String, dynamic> toJson() => {'days': days, 'percent': percent};
}

class Setting {
  const Setting({required this.key, required this.value});

  final String key;
  final String value;
}

class DistCenter {
  const DistCenter({
    required this.id,
    required this.code,
    required this.name,
    this.lat = 0,
    this.lng = 0,
  });

  final String id;
  final String code;
  final String name;
  final double lat;
  final double lng;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.code,
    required this.name,
    this.capacityKg = 0,
    this.capacityM3 = 0,
    this.active = true,
  });

  final String id;
  final String code;
  final String name;
  final double capacityKg;
  final double capacityM3;
  final bool active;
}
