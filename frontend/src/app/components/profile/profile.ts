import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { CommonModule } from '@angular/common';

@Component({
  standalone: true,
  imports: [ReactiveFormsModule, CommonModule],
  selector: 'app-profile',
  styleUrl: './profile.css',
  templateUrl: './profile.html',
})
export class Profile {
  passwordForm: FormGroup;
  mensaje: string = '';
  error: boolean = false;

  constructor(private fb: FormBuilder, private http: HttpClient) {
    this.passwordForm = this.fb.group({
      nueva_password: ['', [
        Validators.required, 
        Validators.minLength(8),
        Validators.pattern(/^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$/)
      ]]
    });
  }

  cambiarPassword() {
    if (this.passwordForm.valid) {
      const token = localStorage.getItem('token');
      const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
      
      this.http.put('http://localhost:8000/gestion_usuarios/users/me/password', this.passwordForm.value, { headers }).subscribe({
        next: (res: any) => {
          this.mensaje = '¡Contraseña actualizada con éxito!';
          this.error = false;
          this.passwordForm.reset();
        },
        error: (err) => {
          this.mensaje = 'Error al actualizar la contraseña.';
          this.error = true;
        }
      });
    } else {
      this.passwordForm.markAllAsTouched();
    }
  }
}
