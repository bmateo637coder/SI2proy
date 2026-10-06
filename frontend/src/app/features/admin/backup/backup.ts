import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { environment } from '../../../../environments/environment';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-backup',
  styleUrl: './backup.css',
  templateUrl: './backup.html',
})
export class Backup {
  archivoSeleccionado: File | null = null;
  mensaje: string = '';
  error: string = '';
  isUploading = false;
  isDownloading = false;

  constructor(private http: HttpClient) {}

  getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  descargarBackup() {
    this.isDownloading = true;
    this.mensaje = '';
    this.error = '';

    this.http.get(`${environment.apiUrl}/admin/backup`, {
      headers: this.getHeaders(),
      responseType: 'blob'
    }).subscribe({
      next: (blob) => {
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        // The backend filename will be provided in headers, but for simplicity we generate one
        link.download = `backup_raices_${new Date().getTime()}.sql`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
        this.isDownloading = false;
        this.mensaje = 'Copia de seguridad descargada exitosamente.';
      },
      error: (err) => {
        console.error(err);
        this.isDownloading = false;
        this.error = 'Hubo un error al generar la copia de seguridad.';
      }
    });
  }

  onFileSelected(event: any) {
    if (event.target.files.length > 0) {
      this.archivoSeleccionado = event.target.files[0];
    }
  }

  restaurarBackup() {
    if (!this.archivoSeleccionado) {
      this.error = 'Por favor seleccione un archivo .sql';
      return;
    }

    if (!confirm('¡ADVERTENCIA! Esta acción sobreescribirá toda la base de datos actual y es irreversible. ¿Está completamente seguro de continuar?')) {
      return;
    }

    this.isUploading = true;
    this.mensaje = '';
    this.error = '';

    const formData = new FormData();
    formData.append('file', this.archivoSeleccionado);

    this.http.post(`${environment.apiUrl}/admin/restore`, formData, {
      headers: this.getHeaders() // El HttpClient detectará automáticamente multipart/form-data
    }).subscribe({
      next: (res: any) => {
        this.isUploading = false;
        this.mensaje = res.mensaje || 'Restauración completada con éxito.';
        this.archivoSeleccionado = null;
        // Optionally reset the file input visually by relying on two-way binding or a template ref,
        // but for now setting the variable is enough.
      },
      error: (err) => {
        console.error(err);
        this.isUploading = false;
        this.error = err.error?.detail || 'Error al intentar restaurar la base de datos.';
      }
    });
  }
}
