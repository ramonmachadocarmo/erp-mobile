class Geo {
  const Geo(this.lat, this.lng);

  final double lat;
  final double lng;
}

String mapsDirUrl({Geo? origin, required List<Geo> stops}) {
  final pts = stops.where((s) => s.lat != 0 && s.lng != 0).toList();
  if (pts.isEmpty) return '';
  final path = <Geo>[
    if (origin != null && origin.lat != 0 && origin.lng != 0) origin,
    ...pts,
  ];
  return 'https://www.google.com/maps/dir/${path.map((p) => '${p.lat},${p.lng}').join('/')}';
}

String mapsStopUrl(double lat, double lng) =>
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';

String wazeNavUrl(double lat, double lng) => 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
