import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from './roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }
    const { user } = context.switchToHttp().getRequest();
    if (!user) {
      throw new ForbiddenException('User context missing');
    }
    const normalizedUserRole = user.role.replace(/_/g, '').toLowerCase();
    const hasRole = requiredRoles.some((role) => {
      const normalizedReqRole = role.replace(/_/g, '').toLowerCase();
      return normalizedUserRole === normalizedReqRole;
    });

    if (!hasRole) {
      throw new ForbiddenException(`Insufficient permissions for role: ${user.role}`);
    }
    return true;
  }
}
