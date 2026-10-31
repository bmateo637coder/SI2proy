import { Injectable, signal } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class ApiFeedback {
  error = signal('');
  clear() { this.error.set(''); }
}
