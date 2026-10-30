import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../data/services/reportes_service.dart';
import '../providers/auth_provider.dart';

class Filtro {
  Filtro({this.columna = '', this.operador = 'eq', this.valor = ''});
  String columna;
  String operador;
  String valor;
  Map<String, dynamic> toJson() => {
        'columna': columna,
        'operador': operador,
        'valor': valor,
      };
}

class ReportesDinamicosScreen extends StatefulWidget {
  const ReportesDinamicosScreen({super.key});
  @override
  State<ReportesDinamicosScreen> createState() => _ReportesDinamicosScreenState();
}

class _ReportesDinamicosScreenState extends State<ReportesDinamicosScreen> {
  final ReportesService _service = ReportesService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _escuchando = false;
  String _textoEscuchado = '';
  String _errorIa = '';
  String _mensaje = '';
  bool _cargando = false;

  String _entidad = 'propiedades';
  List<String> _columnasSeleccionadas = ['titulo', 'precio', 'estado'];
  final List<Filtro> _filtros = [];
  String _ordenColumna = 'precio';
  String _ordenDireccion = 'asc';
  List<Map<String, dynamic>> _resultados = [];
  List<String> _columnasResultados = [];
  List<Map<String, dynamic>> _guardados = [];
  String _nombreNuevo = '';

  final Map<String, List<Map<String, String>>> _columnasDisponibles = {
    'propiedades': [
      {'id': 'id_propiedad', 'label': 'ID'},
      {'id': 'titulo', 'label': 'Título'},
      {'id': 'direccion', 'label': 'Dirección'},
      {'id': 'precio', 'label': 'Precio'},
      {'id': 'tipo_operacion', 'label': 'Operación'},
      {'id': 'estado', 'label': 'Estado'},
    ],
    'usuarios': [
      {'id': 'ci', 'label': 'CI'},
      {'id': 'nombre', 'label': 'Nombre'},
      {'id': 'correo', 'label': 'Correo'},
      {'id': 'telefono', 'label': 'Teléfono'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _speech.initialize();
    _cargarGuardados();
  }

  Future<void> _cargarGuardados() async {
    try {
      final l = await _service.listarGuardados();
      setState(() => _guardados = l);
    } catch (_) {}
  }

  void _onEntidadChange(String? v) {
    if (v == null) return;
    setState(() {
      _entidad = v;
      _columnasSeleccionadas = [];
      final cols = _columnasDisponibles[_entidad] ?? [];
      if (cols.isNotEmpty) _columnasSeleccionadas.add(cols[0]['id']!);
      _ordenColumna = cols.isNotEmpty ? cols[0]['id']! : 'id';
    });
  }

  bool _colSel(String id) => _columnasSeleccionadas.contains(id);

  void _toggleCol(String id, bool checked) {
    setState(() {
      if (checked) {
        if (!_columnasSeleccionadas.contains(id)) _columnasSeleccionadas.add(id);
      } else {
        _columnasSeleccionadas.remove(id);
      }
    });
  }

  void _addFiltro() => setState(() => _filtros.add(Filtro()));
  void _remFiltro(int i) => setState(() => _filtros.removeAt(i));

  Future<void> _generar() async {
    setState(() { _cargando = true; _mensaje = ''; });
    try {
      final res = await _service.generarReporte(
        entidad: _entidad,
        columnas: _columnasSeleccionadas,
        filtros: _filtros.map((e) => e.toJson()).toList(),
        ordenColumna: _ordenColumna,
        ordenDireccion: _ordenDireccion,
      );
      setState(() {
        _resultados = (res['datos'] as List<dynamic>? ?? []).map((e) => Map<String,dynamic>.from(e)).toList();
        _columnasResultados = List<String>.from(res['columnas'] as List<dynamic>? ?? []);
        _mensaje = '${_resultados.length} registros';
      });
    } catch (e) {
      setState(() => _mensaje = 'Error: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (_nombreNuevo.isEmpty) { setState(() => _mensaje = 'Nombre requerido'); return; }
    try {
      await _service.guardarConfiguracion(
        nombre: _nombreNuevo,
        entidad: _entidad,
        columnas: _columnasSeleccionadas,
        filtros: _filtros.map((e)=>e.toJson()).toList(),
        ordenColumna: _ordenColumna,
        ordenDireccion: _ordenDireccion,
      );
      _nombreNuevo = '';
      await _cargarGuardados();
      setState(() => _mensaje = 'Guardado');
    } catch (e) {
      setState(() => _mensaje = 'Error: $e');
    }
  }

  Future<void> _cargar(Map<String,dynamic> rep) async {
    try {
      final cfg = await _service.cargarGuardado(rep['id_reporte'] as int);
      final c = cfg['configuracion'] as Map<String,dynamic>? ?? {};
      setState(() {
        _entidad = c['entidad']?.toString() ?? _entidad;
        _columnasSeleccionadas = List<String>.from(c['columnas'] as List<dynamic>? ?? []);
        _filtros.clear();
        for (final f in (c['filtros'] as List<dynamic>? ?? [])) {
          final m = Map<String,dynamic>.from(f);
          _filtros.add(Filtro(columna: m['columna']?.toString()??'', operador: m['operador']?.toString()??'eq', valor: m['valor']?.toString()??''));
        }
        _ordenColumna = c['orden_columna']?.toString() ?? _ordenColumna;
        _ordenDireccion = c['orden_direccion']?.toString() ?? _ordenDireccion;
      });
    } catch (e) {
      setState(() => _mensaje = 'Error: $e');
    }
  }

  Future<void> _iniciarVoz() async {
    final ok = await _speech.initialize();
    if (!ok) { setState(() => _errorIa = 'Voz no disponible'); return; }
    setState(() { _escuchando = true; _textoEscuchado = 'Escuchando...'; _errorIa=''; });
    _speech.listen(localeId: 'es_ES', onResult: (r){ setState(()=>_textoEscuchado=r.recognizedWords); });
  }

  Future<void> _detenerVoz() async {
    await _speech.stop(); setState(()=>_escuchando=false);
    if (_textoEscuchado.isEmpty||_textoEscuchado=='Escuchando...') return;
    try {
      final resp = await _service.comandoVoz(_textoEscuchado);
      setState(() {
        _entidad = resp['entidad']?.toString()??_entidad;
        if (resp['columnas']!=null) _columnasSeleccionadas = List<String>.from(resp['columnas']);
        _filtros.clear();
        if (resp['filtros']!=null) {
          for (final f in resp['filtros']) {
            final m = Map<String,dynamic>.from(f);
            _filtros.add(Filtro(columna:m['columna']?.toString()??'', operador:m['operador']?.toString()??'eq', valor:m['valor']?.toString()??''));
          }
        }
        _ordenColumna = resp['orden_columna']?.toString()??_ordenColumna;
        _ordenDireccion = resp['orden_direccion']?.toString()??_ordenDireccion;
        _textoEscuchado = 'Aplicado';
      });
      await _generar();
    } catch (e) {
      setState(()=>_errorIa='IA: $e');
    }
  }

  Future<void> _exp(String t) async {
    try {
      final file = switch(t){ 'pdf'=>await _service.exportarPdf(_resultados,_columnasResultados), 'csv'=>await _service.exportarCsv(_resultados,_columnasResultados), 'excel'=>await _service.exportarExcel(_resultados,_columnasResultados), 'html'=>await _service.exportarHtml(_resultados,_columnasResultados), _=>null };
      if (file!=null) await _service.abrirYCompartir(file);
    } catch(e){ setState(()=>_mensaje='Error export: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes Dinámicos')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(children: [
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
            const Text('Asistente de Reportes', style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
            ElevatedButton.icon(onPressed:_escuchando?_detenerVoz:_iniciarVoz, icon:Icon(_escuchando?Icons.mic:Icons.mic_none), label:Text(_escuchando?'Escuchando':'Voz IA')),
          ]),
          if(_textoEscuchado.isNotEmpty||_errorIa.isNotEmpty) Text(_errorIa.isNotEmpty?_errorIa:_textoEscuchado),
          const SizedBox(height:8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
