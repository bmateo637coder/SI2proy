import { Injectable, signal } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = environment.apiUrl;
  
  // Usamos signals para estado reactivo
  public userPermissions = signal<string[]>([]);
  public currentUser = signal<any>(null);

  constructor(private http: HttpClient, private router: Router) {
    this.loadStateFromStorage();
  }

  private loadStateFromStorage() {
    const perms = localStorage.getItem('permissions');
    const user = localStorage.getItem('user');
    if (perms) {
      this.userPermissions.set(JSON.parse(perms));
    }
    if (user) {
      this.currentUser.set(JSON.parse(user));
    }
  }

  login(credentials: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/login`, credentials).pipe(
      tap((res: any) => {
        localStorage.setItem('token', res.access_token);
      })
    );
  }

  loadUserProfile(): Observable<any> {
    const token = localStorage.getItem('token');
    const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
    
    return this.http.get(`${this.apiUrl}/users/me`, { headers }).pipe(
      tap((user: any) => {
        // Guardamos permisos y datos de usuario en localStorage y signals
        localStorage.setItem('permissions', JSON.stringify(user.permisos || []));
        localStorage.setItem('user', JSON.stringify(user));
        localStorage.setItem('user_role', String(user.id_rol || 0));
        localStorage.setItem('id_tenant', String(user.id_tenant || ''));
        this.userPermissions.set(user.permisos || []);
        this.currentUser.set(user);
      })
    );
  }

  logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user_role');
    localStorage.removeItem('permissions');
    localStorage.removeItem('user');
    this.userPermissions.set([]);
    this.currentUser.set(null);
    this.router.navigate(['/login']);
  }

  hasPermission(permission: string): boolean {
    return this.userPermissions().includes(permission);
  }
}
