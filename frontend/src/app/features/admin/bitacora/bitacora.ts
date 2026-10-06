import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../../core/services/auth.service';
import { environment } from '../../../../environments/environment';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-bitacora',
  templateUrl: './bitacora.html',
})
export class Bitacora implements OnInit {
  registros: any[] = [];
  devKey: string = '';
  error: string = '';
  loading: boolean = false;

  constructor(private http: HttpClient, private authService: AuthService) {}

  ngOnInit() {}

  cargarBitacora() {
    if (!this.devKey) {
      this.error = 'Debe ingresar la llave de desarrollador';
      return;
    }
    
    this.loading = true;
    this.error = '';
    
    const token = localStorage.getItem('token');
    const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
    
    this.http.get(`${environment.apiUrl}/admin/bitacora?dev_key=${this.devKey}`, { headers })
      .subscribe({
        next: (res: any) => {
          this.registros = res;
          this.loading = false;
        },
        error: (err) => {
          this.error = 'Llave inválida o error de permisos';
          this.loading = false;
        }
      });
  }
}
