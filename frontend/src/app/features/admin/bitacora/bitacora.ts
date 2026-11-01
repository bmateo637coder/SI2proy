import { ChangeDetectorRef, Component, DestroyRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { finalize, timeout, TimeoutError } from 'rxjs';
import { FormsModule } from '@angular/forms';
import { environment } from '../../../../environments/environment';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-bitacora',
  templateUrl: './bitacora.html',
})
export class Bitacora {
  registros: any[] = [];
  devKey: string = '';
  error: string = '';
  loading: boolean = false;
  loaded: boolean = false;
  private readonly destroyRef = inject(DestroyRef);

  constructor(private http: HttpClient, private cdr: ChangeDetectorRef) {}

  cargarBitacora() {
    if (this.loading) return;
    // Admitir también la forma %2B indicada como solución temporal.
    const key = this.devKey.trim().replace(/%2b/gi, '+').replace(/%3d/gi, '=');
    if (!key) {
      this.error = 'Debe ingresar la llave de desarrollador';
      return;
    }
    
    this.loading = true;
    this.loaded = false;
    this.registros = [];
    this.error = '';
    
    const token = localStorage.getItem('token');
    const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
    
    this.http.get<any[]>(`${environment.apiUrl}/admin/bitacora`, {
      headers, params: new HttpParams().set('dev_key', key)
    }).pipe(
      timeout(90000),
      takeUntilDestroyed(this.destroyRef),
      finalize(() => {
        this.loading = false;
        this.cdr.markForCheck();
      })
    )
      .subscribe({
        next: (res: any) => {
          this.registros = res;
          this.loaded = true;
        },
        error: (err) => {
          this.error = err instanceof TimeoutError
            ? 'El servidor tardó demasiado. Vuelve a intentar; Render puede estar iniciando.'
            : err.status === 401 ? 'Tu sesión venció. Vuelve a iniciar sesión.'
            : err.status === 403 ? 'Llave inválida o acceso denegado. Se requiere el superadministrador SaaS.'
            : err.status === 0 ? 'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.'
            : 'No se pudo leer la bitácora. Vuelve a intentar en unos momentos.';
        }
      });
  }
}
