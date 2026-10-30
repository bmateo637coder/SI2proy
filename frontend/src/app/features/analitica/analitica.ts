import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { environment } from '../../../environments/environment';

@Component({ standalone: true, imports: [CommonModule, FormsModule], templateUrl: './analitica.html', styleUrl: '../parcial2.css' })
export class AnaliticaPage {
  private http = inject(HttpClient);
  readonly report = signal<any>(null);
  readonly dashboard = signal<any>(null);
  readonly error = signal('');
  readonly busy = signal(false);
  readonly listening = signal(false);
  text = 'Mostrame las ventas de este mes agrupadas por sucursal';
  tipo = 'ventas_sucursal';
  desde = '';
  hasta = '';
  sucursal = '';
  private headers() { return new HttpHeaders({ Authorization: `Bearer ${localStorage.getItem('token')}` }); }
  async generate(natural: boolean) {
    this.busy.set(true); this.error.set('');
    try {
      const body = natural ? { texto: this.text } : { tipo: this.tipo, desde: this.desde || null,
        hasta: this.hasta || null, id_sucursal: this.sucursal ? Number(this.sucursal) : null };
      this.report.set(await firstValueFrom(this.http.post(`${environment.apiUrl}/api/analitica/${natural ? 'reporte' : 'convencional'}`, body, { headers: this.headers() })));
    } catch (e: any) { this.report.set(null); this.error.set(typeof e.error?.detail === 'string' ? e.error.detail : 'No se pudo generar el reporte.'); }
    finally { this.busy.set(false); }
  }
  voice() {
    const Recognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!Recognition) { this.error.set('Este navegador no admite dictado. Escribe la solicitud.'); return; }
    const recognition = new Recognition(); recognition.lang = 'es-BO';
    recognition.onresult = (e: any) => { this.text = e.results[0][0].transcript; this.listening.set(false); };
    recognition.onerror = () => { this.error.set('No se pudo capturar la voz. Revise el permiso de micrófono.'); this.listening.set(false); };
    recognition.onend = () => this.listening.set(false);
    this.listening.set(true); recognition.start();
  }
  async loadML() {
    this.busy.set(true); this.error.set('');
    try { this.dashboard.set(await firstValueFrom(this.http.get(`${environment.apiUrl}/api/analitica/dashboard`, { headers: this.headers() }))); }
    catch (e: any) { this.error.set(e.error?.detail || 'No se pudo cargar la analítica.'); }
    finally { this.busy.set(false); }
  }
  width(row: any[]) {
    const max = Math.max(1, ...this.report().filas.map((r: any[]) => Number(r[r.length - 1]) || 0));
    return Math.max(0, Number(row[row.length - 1]) / max * 100);
  }
  async excel() {
    const XLSX = await import('xlsx');
    const r = this.report();
    const ws = XLSX.utils.aoa_to_sheet([[r.titulo], [`Empresa ${r.id_tenant} · ${r.generado_en}`], [JSON.stringify(r.filtros)], [], r.columnas, ...r.filas]);
    // Celdas explícitas de texto: no permitir fórmulas provenientes de nombres.
    const book = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(book, ws, 'Reporte');
    XLSX.writeFile(book, 'reporte-raices.xlsx');
  }
  async pdf() {
    const { jsPDF } = await import('jspdf');
    const { default: autoTable } = await import('jspdf-autotable');
    const r = this.report(); const doc = new jsPDF();
    doc.setFontSize(16); doc.text(r.titulo, 14, 18);
    doc.setFontSize(9); doc.text(`Empresa ${r.id_tenant} | ${r.generado_en}`, 14, 26);
    const filters = doc.splitTextToSize(JSON.stringify(r.filtros), 180); doc.text(filters, 14, 33);
    autoTable(doc, { head: [r.columnas], body: r.filas, startY: 40 + filters.length * 4 });
    doc.save('reporte-raices.pdf');
  }
}
