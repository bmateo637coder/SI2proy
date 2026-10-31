import 'package:flutter/material.dart';

import '../../data/services/reportes_service.dart';
import '../../data/services/api_error.dart';

class ReportTable extends StatelessWidget {
  const ReportTable({
    required this.columns,
    required this.rows,
    this.title = 'Reporte Raíces',
    super.key,
  });
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final String title;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${rows.length} registros', key: const ValueKey('report-count')),
      Wrap(
        spacing: 8,
        children: ['pdf', 'xlsx', 'csv', 'html']
            .map(
              (format) => OutlinedButton.icon(
                onPressed: columns.isEmpty
                    ? null
                    : () async {
                        try {
                          await ReportesService.compartir(
                            format,
                            columns,
                            rows,
                            title: title,
                          );
                        } catch (error) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(apiError(error))),
                            );
                        }
                      },
                icon: const Icon(Icons.download_outlined),
                label: Text(format.toUpperCase()),
              ),
            )
            .toList(),
      ),
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay registros para estos filtros.'),
        ),
      if (columns.isNotEmpty && rows.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
            rows: rows
                .take(500)
                .map(
                  (r) => DataRow(
                    cells: columns
                        .map(
                          (c) => DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: SelectableText(r[c]?.toString() ?? '—'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );
}
