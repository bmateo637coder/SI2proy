import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';
import * as XLSX from 'xlsx';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-reportes',
  styleUrl: './generador.css',
  templateUrl: './generador.html',
})
export class GeneradorReportes implements OnInit {
  grabandoVoz = false;
  textoEscuchado = '';
  errorIA: string | null = null;
  entidades = [
    { value: 'propiedades', label: 'Inmuebles/Propiedades' },
    { value: 'usuarios', label: 'Usuarios del Sistema' }
  ];
  
  columnasDisponibles: any = {
    propiedades: [
      { id: 'id_propiedad', label: 'ID' },
      { id: 'titulo', label: 'Título' },
      { id: 'direccion', label: 'Dirección' },
      { id: 'precio', label: 'Precio' },
      { id: 'tipo_operacion', label: 'Operación' },
      { id: 'estado', label: 'Estado' }
    ],
    usuarios: [
      { id: 'ci', label: 'CI' },
      { id: 'nombre', label: 'Nombre' },
      { id: 'correo', label: 'Correo' },
      { id: 'telefono', label: 'Teléfono' }
    ]
  };

  entidadSeleccionada = 'propiedades';
  columnasSeleccionadas: string[] = ['titulo', 'precio', 'estado'];
  
  filtros: any[] = [];
  
  ordenColumna = 'precio';
  ordenDireccion = 'asc';
  
  resultados: any[] = [];
  columnasResultados: string[] = [];
  
  reportesGuardados: any[] = [];
  nombreNuevoReporte = '';
  mensaje = '';

  userRole: number = 0;
  empresas: any[] = [];
  empresaFiltro: string = ''; // '' = Todas

  constructor(private http: HttpClient, private cdr: ChangeDetectorRef) {}

  grabarVoz() {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SpeechRecognition) {
      alert('Su navegador no soporta reconocimiento de voz. Use Chrome o Edge.');
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.lang = 'es-ES';
    recognition.interimResults = true;
    recognition.maxAlternatives = 1;

    this.grabandoVoz = true;
    this.textoEscuchado = 'Escuchando...';
    this.errorIA = null;
    this.cdr.detectChanges();

    recognition.start();

    recognition.onresult = (event: any) => {
      let interimTranscript = '';
      let finalTranscript = '';

      for (let i = event.resultIndex; i < event.results.length; ++i) {
        if (event.results[i].isFinal) {
          finalTranscript += event.results[i][0].transcript;
        } else {
          interimTranscript += event.results[i][0].transcript;
        }
      }

      this.textoEscuchado = finalTranscript + interimTranscript;
      this.cdr.detectChanges();

      if (finalTranscript) {
        this.procesarComandoIA(finalTranscript);
      }
    };

    recognition.onspeechend = () => {
      recognition.stop();
      this.grabandoVoz = false;
      this.cdr.detectChanges();
    };

    recognition.onerror = (event: any) => {
      console.error(event.error);
      this.grabandoVoz = false;
      this.textoEscuchado = 'Error al escuchar.';
      this.cdr.detectChanges();
    };
  }

  procesarComandoIA(texto: string) {
    this.mensaje = 'Procesando comando con IA...';
    this.errorIA = null;
    this.http.post('http://localhost:8000/api/ia/reporte-voz', { texto }, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          if (res.success && res.config) {
            const cfg = res.config;
            this.entidadSeleccionada = cfg.entidad || 'propiedades';
            this.onEntidadChange();
            if (cfg.columnas) this.columnasSeleccionadas = cfg.columnas;
            if (cfg.filtros) this.filtros = cfg.filtros;
            if (cfg.ordenColumna) this.ordenColumna = cfg.ordenColumna;
            if (cfg.ordenDireccion) this.ordenDireccion = cfg.ordenDireccion;
            
            this.mensaje = `¡Comando entendido! "${texto}"`;
            this.cdr.detectChanges();
            setTimeout(() => { this.mensaje = ''; this.cdr.detectChanges(); }, 4000);
            this.generarReporte();
          } else if (!res.success && res.error) {
            this.errorIA = res.error;
            this.mensaje = '';
            this.cdr.detectChanges();
          }
        },
        error: (err) => {
          console.error(err);
          this.errorIA = 'Error de conexión con el servidor IA.';
          this.mensaje = '';
          this.cdr.detectChanges();
        }
      });
  }

  ngOnInit() {
    const userRoleStr = localStorage.getItem('user_role');
    this.userRole = userRoleStr ? parseInt(userRoleStr, 10) : 0;
    
    if (this.userRole === 1) {
      this.cargarEmpresas();
      // Add id_tenant as a selectable column for SuperAdmin
      this.columnasDisponibles.propiedades.unshift({ id: 'id_tenant', label: 'ID Empresa' });
      this.columnasDisponibles.usuarios.unshift({ id: 'id_tenant', label: 'ID Empresa' });
    }

    this.cargarReportesGuardados();
  }

  getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  cargarEmpresas() {
    this.http.get('http://localhost:8000/admin/empresas', { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => this.empresas = res,
        error: err => console.error(err)
      });
  }

  onEntidadChange() {
    this.columnasSeleccionadas = [];
    this.filtros = [];
    this.resultados = [];
  }

  toggleColumna(colId: string, event: any) {
    if (event.target.checked) {
      this.columnasSeleccionadas.push(colId);
    } else {
      this.columnasSeleccionadas = this.columnasSeleccionadas.filter(c => c !== colId);
    }
  }

  agregarFiltro() {
    this.filtros.push({ columna: '', operador: 'eq', valor: '' });
  }

  removerFiltro(index: number) {
    this.filtros.splice(index, 1);
  }

  generarReporte() {
    if (this.columnasSeleccionadas.length === 0) {
      alert("Seleccione al menos una columna");
      return;
    }

    const filtrosFinales = this.filtros.filter(f => f.columna && f.valor !== '');
    
    // Si es SuperAdmin y seleccionó una empresa, agregarla como filtro duro
    if (this.userRole === 1 && this.empresaFiltro !== '') {
      filtrosFinales.push({ columna: 'id_tenant', operador: 'eq', valor: parseInt(this.empresaFiltro, 10) });
    }

    const payload = {
      entidad: this.entidadSeleccionada,
      columnas: this.columnasSeleccionadas,
      filtros: filtrosFinales,
      orden: { columna: this.ordenColumna, direccion: this.ordenDireccion }
    };

    this.http.post('http://localhost:8000/reportes/generar', payload, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          this.resultados = res.data;
          this.columnasResultados = [...this.columnasSeleccionadas];
          this.cdr.detectChanges();
        },
        error: err => console.error(err)
      });
  }

  guardarConfiguracion() {
    if (!this.nombreNuevoReporte) return;
    
    const config = {
      entidad: this.entidadSeleccionada,
      columnas: this.columnasSeleccionadas,
      filtros: this.filtros,
      ordenColumna: this.ordenColumna,
      ordenDireccion: this.ordenDireccion,
      empresaFiltro: this.empresaFiltro
    };

    const payload = {
      nombre: this.nombreNuevoReporte,
      configuracion: JSON.stringify(config)
    };

    this.http.post('http://localhost:8000/reportes/guardados', payload, { headers: this.getHeaders() })
      .subscribe({
        next: () => {
          this.mensaje = "Reporte guardado exitosamente";
          this.nombreNuevoReporte = '';
          this.cargarReportesGuardados();
          setTimeout(() => this.mensaje = '', 3000);
        },
        error: err => console.error(err)
      });
  }

  cargarReportesGuardados() {
    this.http.get('http://localhost:8000/reportes/guardados', { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => this.reportesGuardados = res,
        error: err => console.error(err)
      });
  }

  cargarConfiguracion(reporte: any) {
    const config = JSON.parse(reporte.configuracion);
    this.entidadSeleccionada = config.entidad;
    this.columnasSeleccionadas = config.columnas;
    this.filtros = config.filtros || [];
    this.ordenColumna = config.ordenColumna;
    this.ordenDireccion = config.ordenDireccion;
    this.empresaFiltro = config.empresaFiltro || '';
    this.resultados = []; // Limpiar tabla anterior
    // Llamar a generar automáticamente
    this.generarReporte();
  }

  // Exportar a CSV (Excel lo lee bien)
  exportarCSV() {
    if (this.resultados.length === 0) return;
    let csvContent = "data:text/csv;charset=utf-8,";
    // Header
    csvContent += this.columnasResultados.join(";") + "\r\n";
    // Rows
    this.resultados.forEach(row => {
      let rowArray = this.columnasResultados.map(col => {
        let val = row[col] === null || row[col] === undefined ? '' : String(row[col]);
        // Escapar comillas dobles y comas si es necesario
        return `"${val.replace(/"/g, '""')}"`;
      });
      csvContent += rowArray.join(";") + "\r\n";
    });

    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `Reporte_${this.entidadSeleccionada}_${new Date().getTime()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  exportarHTML() {
    if (this.resultados.length === 0) return;
    
    let html = `
      <html>
      <head>
        <meta charset="utf-8">
        <title>Reporte de ${this.entidadSeleccionada}</title>
        <style>
          body { font-family: Arial, sans-serif; padding: 20px; }
          table { border-collapse: collapse; width: 100%; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          th { background-color: #D4AF37; color: white; }
        </style>
      </head>
      <body>
        <h2>Reporte de ${this.entidadSeleccionada}</h2>
        <p>Fecha de generación: ${new Date().toLocaleString()}</p>
        <table>
          <thead>
            <tr>${this.columnasResultados.map(c => `<th>${c.toUpperCase()}</th>`).join('')}</tr>
          </thead>
          <tbody>
            ${this.resultados.map(row => `<tr>${this.columnasResultados.map(col => `<td>${row[col] || ''}</td>`).join('')}</tr>`).join('')}
          </tbody>
        </table>
      </body>
      </html>
    `;

    const blob = new Blob([html], { type: 'text/html' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `Reporte_${this.entidadSeleccionada}_${new Date().getTime()}.html`;
    link.click();
  }

  exportarPDF() {
    if (this.resultados.length === 0) return;
    const doc = new jsPDF();
    doc.text(`Reporte de ${this.entidadSeleccionada}`, 14, 15);
    
    const tableData = this.resultados.map(row => 
      this.columnasResultados.map(col => String(row[col] || ''))
    );

    autoTable(doc, {
      head: [this.columnasResultados.map(c => c.toUpperCase())],
      body: tableData,
      startY: 20,
      theme: 'grid',
      headStyles: { fillColor: [212, 175, 55] } // Dorado
    });

    doc.save(`Reporte_${this.entidadSeleccionada}_${new Date().getTime()}.pdf`);
  }

  exportarExcel() {
    if (this.resultados.length === 0) return;
    
    // Prepare data
    const wsData = this.resultados.map(row => {
      let newRow: any = {};
      this.columnasResultados.forEach(col => {
        newRow[col.toUpperCase()] = row[col];
      });
      return newRow;
    });

    const worksheet: XLSX.WorkSheet = XLSX.utils.json_to_sheet(wsData);
    const workbook: XLSX.WorkBook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Reporte');
    XLSX.writeFile(workbook, `Reporte_${this.entidadSeleccionada}_${new Date().getTime()}.xlsx`);
  }
}
