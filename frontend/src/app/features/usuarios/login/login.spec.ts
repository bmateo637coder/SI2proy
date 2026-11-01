import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Login } from './login';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';

describe('Login', () => {
  let component: Login;
  let fixture: ComponentFixture<Login>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Login],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])]
    })
      .compileComponents();

    fixture = TestBed.createComponent(Login);
    component = fixture.componentInstance;
    fixture.autoDetectChanges();
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('muestra el rechazo del servidor sin otra interacción del usuario', async () => {
    component.loginForm.setValue({correo: 'prueba@example.com', password: 'incorrecta', id_tenant: null});
    component.onSubmit();
    const http = TestBed.inject(HttpTestingController);
    http.expectOne(request => request.url.endsWith('/login')).flush(
      {detail: 'Credenciales inválidas'}, {status: 401, statusText: 'Unauthorized'});
    await fixture.whenStable();
    expect(component.errorMessage()).toBe('Credenciales inválidas');
    expect(fixture.nativeElement.querySelector('.alert-error')?.textContent).toContain('Credenciales inválidas');
    http.verify();
  });
});
