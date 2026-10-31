import { Component, ChangeDetectorRef } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { environment } from '../../../environments/environment';

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

  constructor(private fb: FormBuilder, private http: HttpClient, private cdr: ChangeDetectorRef) {
    this.forgotForm = this.fb.group({
      correo: ['', [Validators.required, Validators.email]]
    });
  }

  onSubmit() {
    if (this.forgotForm.valid) {
      this.http.post(`${environment.apiUrl}/forgot-password`, this.forgotForm.value).subscribe({
        next: (res: any) => {
          this.mensaje = res.message;
          this.enviado = true;
          this.cdr.detectChanges();
        },
        error: () => {
          this.mensaje = 'Hubo un error al procesar tu solicitud.';
          this.cdr.detectChanges();
        }
      });
    }
  }
}
