import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
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
  errorMessage: string = '';

  constructor(
    private fb: FormBuilder, 
    private authService: AuthService, 
    private router: Router
  ) {
    this.loginForm = this.fb.group({
      correo: ['', [Validators.required, Validators.email]],
      password: ['', Validators.required]
    });
  }

  onSubmit() {
    if (this.loginForm.valid) {
      this.authService.login(this.loginForm.value).subscribe({
        next: (response) => {
          // Una vez validado, obtenemos el perfil completo para cargar permisos
          this.authService.loadUserProfile().subscribe({
            next: () => {
              this.router.navigate(['/dashboard/profile']);
            },
            error: (err) => {
              this.errorMessage = 'Error obteniendo permisos. Contacte al administrador.';
            }
          });
        },
        error: (err) => {
          this.errorMessage = 'Credenciales inválidas. Por favor intenta de nuevo.';
        }
      });
    } else {
      this.loginForm.markAllAsTouched();
    }
  }
}
