import '../../../core/json.dart';
import '../domain/entities.dart';

Unit unitFrom(Map<String, dynamic> j) => Unit(
      id: asString(j, 'id'),
      code: asString(j, 'code'),
      name: asString(j, 'name'),
      symbol: asString(j, 'symbol'),
    );

PaymentMethod methodFrom(Map<String, dynamic> j) => PaymentMethod(
      id: asString(j, 'id'),
      code: asString(j, 'code'),
      name: asString(j, 'name'),
    );

PaymentTerm termFrom(Map<String, dynamic> j) => PaymentTerm(
      id: asString(j, 'id'),
      code: asString(j, 'code'),
      name: asString(j, 'name'),
      installments: asMapList(j['installments'])
          .map(
            (i) => Installment(
              days: asInt(i, 'days'),
              percent: asDouble(i, 'percent'),
            ),
          )
          .toList(),
    );

Person personFrom(Map<String, dynamic> j) => Person(
      id: asString(j, 'id'),
      kind: asString(j, 'kind'),
      document: asString(j, 'document'),
      name: asString(j, 'name'),
      phone: asString(j, 'phone'),
      companyName: asString(j, 'company_name'),
      responsibleName: asString(j, 'responsible_name'),
      birthDate: asString(j, 'birth_date'),
      gender: asString(j, 'gender'),
      addresses: asMapList(j['addresses'])
          .map(
            (a) => Address(
              id: asString(a, 'id'),
              alias: asString(a, 'alias'),
              zip: asString(a, 'zip'),
              street: asString(a, 'street'),
              number: asString(a, 'number'),
              complement: asString(a, 'complement'),
              district: asString(a, 'district'),
              city: asString(a, 'city'),
              state: asString(a, 'state'),
            ),
          )
          .toList(),
    );

Map<String, dynamic> personBody(Person p) => {
      'kind': p.kind,
      'document': p.document,
      'name': p.name,
      'phone': p.phone,
      'addresses': p.addresses.map((a) => a.toJson()).toList(),
      'birth_date': p.birthDate,
      'gender': p.gender,
      'company_name': p.companyName,
      'responsible_name': p.responsibleName,
    };

DistCenter centerFrom(Map<String, dynamic> j) => DistCenter(
      id: asString(j, 'id'),
      code: asString(j, 'code'),
      name: asString(j, 'name'),
      lat: asDouble(j, 'lat'),
      lng: asDouble(j, 'lng'),
    );

Vehicle vehicleFrom(Map<String, dynamic> j) => Vehicle(
      id: asString(j, 'id'),
      code: asString(j, 'code'),
      name: asString(j, 'name'),
      capacityKg: asDouble(j, 'capacity_kg'),
      capacityM3: asDouble(j, 'capacity_m3'),
      active: j['active'] == null ? true : asBool(j, 'active'),
    );
