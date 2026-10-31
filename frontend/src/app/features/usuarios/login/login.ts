import { Component, signal } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { Router, RouterLink, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';

@Component({
  standalone: true,
  imports: [ReactiveFormsModule, CommonModule, RouterLink],
  selector: 'app-login',
  styleUrl: './login.css',
  templateUrl: './login.html',
})
export class Login {
  loginForm: FormGroup;
  errorMessage = signal('');

  constructor(
    private fb: FormBuilder,
    private authService: AuthService,
    private router: Router,
    private route: ActivatedRoute
  ) {
    if (this.route.snapshot.queryParamMap.get('reason') === 'expired') {
      this.errorMessage.set('Tu sesión venció. Inicia sesión nuevamente para continuar.');
    }
    this.loginForm = this.fb.group({
      correo: ['', [Validators.required, Validators.email]],
      id_tenant: [null],
      password: ['', Validators.required]
    });
  }

  onSubmit() {
    if (this.loginForm.valid) {
      this.errorMessage.set('');
      this.authService.login(this.loginForm.value).subscribe({
        next: (response) => {
          // Una vez validado, obtenemos el perfil completo para cargar permisos
          this.authService.loadUserProfile().subscribe({
            next: () => {
              this.router.navigate(['/dashboard/profile']);
            },
            error: (err) => {
              this.errorMessage.set('Error obteniendo permisos. Contacte al administrador.');
            }
          });
        },
        error: (err) => {
          const detail = err.error?.detail;
          this.errorMessage.set(typeof detail === 'string' ? detail :
            err.status === 0 ? 'No se pudo conectar con el servidor. Revisa tu conexión.' :
            err.status === 422 ? 'Revisa el correo y los datos ingresados.' :
            'No se pudo iniciar sesión. Por favor intenta de nuevo.');
        }
      });
    } else {
      this.loginForm.markAllAsTouched();
    }
  }
}
