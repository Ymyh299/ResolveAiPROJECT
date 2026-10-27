DateTime? lerData(dynamic v) => v == null ? null : DateTime.parse(v.toString());

double? lerDouble(dynamic v) => v == null ? null : double.parse(v.toString());

String? gravarData(DateTime? d) => d?.toIso8601String().substring(0, 10);

String? gravarDataHora(DateTime? d) =>
    d?.toIso8601String().substring(0, 19).replaceFirst('T', ' ');