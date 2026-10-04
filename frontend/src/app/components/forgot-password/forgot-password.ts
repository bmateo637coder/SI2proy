import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

@Component({
  standalone: true,
  imports: [ReactiveFormsModule, CommonModule, RouterLink],
  selector: 'app-forgot-password',
  styleUrl: './forgot-password.css',
  templateUrl: './forgot-password.html',
})
export class ForgotPassword {
  forgotForm: FormGroup;
  mensaje: string = '';
  enviado: boolean = false;

  constructor(private fb: FormBuilder, private http: HttpClient) {
    this.forgotForm = this.fb.group({
      correo: ['', [Validators.required, Validators.email]]
    });
  }

  onSubmit() {
    if (this.forgotForm.valid) {
      this.http.post('http://localhost:8000/gestion_usuarios/auth/forgot-password', this.forgotForm.value).subscribe({
        next: (res: any) => {
          this.mensaje = res.message;
          this.enviado = true;
        },
        error: () => {
          this.mensaje = 'Hubo un error al procesar tu solicitud.';
        }
      });
    }
  }
}
