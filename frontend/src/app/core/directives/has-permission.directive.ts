import { Directive, Input, TemplateRef, ViewContainerRef, effect } from '@angular/core';
import { AuthService } from '../services/auth.service';

@Directive({
  selector: '[appHasPermission]',
  standalone: true
})
export class HasPermissionDirective {
  private permission: string = '';
  private isHidden = true;

  constructor(
    private templateRef: TemplateRef<any>,
    private viewContainer: ViewContainerRef,
    private authService: AuthService
  ) {
    // Re-evaluar cuando cambien los permisos
    effect(() => {
      const perms = this.authService.userPermissions();
      this.updateView();
    });
  }

  @Input() set appHasPermission(val: string) {
    this.permission = val;
    this.updateView();
  }

  private updateView() {
    if (this.authService.hasPermission(this.permission)) {
      if (this.isHidden) {
        this.viewContainer.createEmbeddedView(this.templateRef);
        this.isHidden = false;
      }
    } else {
      this.viewContainer.clear();
      this.isHidden = true;
    }
  }
}
