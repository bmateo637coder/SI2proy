import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ReportesService {
  ReportesService(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> generar(Map<String, dynamic> config) async =>
      Map<String, dynamic>.from(
        (await dio.post('/reportes/generar', data: config)).data,
      );
  Future<List<Map<String, dynamic>>> guardados() async =>
      ((await dio.get('/reportes/guardados')).data as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> guardar(String nombre, Map<String, dynamic> config) async {
    await dio.post(
      '/reportes/guardados',
      data: {'nombre': nombre, 'configuracion': jsonEncode(config)},
    );
  }

  Future<Map<String, dynamic>> interpretar(String texto) async =>
      Map<String, dynamic>.from(
        (await dio.post(
          '/api/ia/reporte-voz',
          data: {'texto': texto},
        )).data['config'],
      );
  static String safeCell(Object? value) {
    final text = value?.toString() ?? '';
    return RegExp(r'^\s*[=+@\-\t\r]').hasMatch(text) ? "'$text" : text;
  }

  static String xml(Object? value) =>
      const HtmlEscape().convert(value?.toString() ?? '');

  /// Exporta los datos consultados sin depender de red o endpoints adicionales.
  static Future<Uint8List> bytes(
    String format,
    List<String> columns,
    List<Map<String, dynamic>> rows, {
    String title = 'Reporte Raíces',
  }) async {
    final table = [
      columns,
      ...rows.map((r) => columns.map((c) => r[c]?.toString() ?? '').toList()),
    ];
    if (format == 'csv') {
      return Uint8List.fromList(
        utf8.encode(
          '\uFEFF${table.map((r) => r.map((v) => '"${safeCell(v).replaceAll('"', '""')}"').join(',')).join('\r\n')}',
        ),
      );
    }
    if (format == 'html') {
      return Uint8List.fromList(
        utf8.encode(
          '<!doctype html><html lang="es"><meta charset="utf-8"><title>${xml(title)}</title><body><h1>${xml(title)}</h1><table border="1">${table.indexed.map((e) => '<tr>${e.$2.map((v) => e.$1 == 0 ? '<th>${xml(v)}</th>' : '<td>${xml(v)}</td>').join()}</tr>').join()}</table></body></html>',
        ),
      );
    }
    if (format == 'xlsx') {
      // inlineStr conserva como texto los valores que parecen fórmulas.
      final archive = Archive();
      void add(String name, String content) {
        final data = utf8.encode(content);
        archive.addFile(ArchiveFile(name, data.length, data));
      }

      add(
        '[Content_Types].xml',
        '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      );
      add(
        '_rels/.rels',
        '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      );
      add(
        'xl/workbook.xml',
        '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Reporte" sheetId="1" r:id="rId1"/></sheets></workbook>',
      );
      add(
        'xl/_rels/workbook.xml.rels',
        '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      );
      add(
        'xl/worksheets/sheet1.xml',
        '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${table.indexed.map((r) => '<row r="${r.$1 + 1}">${r.$2.map((v) => '<c t="inlineStr"><is><t xml:space="preserve">${xml(v)}</t></is></c>').join()}</row>').join()}</sheetData></worksheet>',
      );
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 200,
        build: (_) => [
          pw.Header(level: 0, text: title),
          pw.Text(
            'Generado: ${DateTime.now().toIso8601String()} - ${rows.length} registros',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: columns,
            data: table.skip(1).toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
    return document.save();
  }

  static Future<void> compartir(
    String format,
    List<String> columns,
    List<Map<String, dynamic>> rows, {
    String title = 'Reporte Raíces',
  }) async {
    final data = await bytes(format, columns, rows, title: title);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/raices_${DateTime.now().millisecondsSinceEpoch}.$format',
    );
    await file.writeAsBytes(data, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: title);
  }
}
