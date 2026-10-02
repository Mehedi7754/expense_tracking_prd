import { Reflector } from '@nestjs/core';
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { RolesGuard } from './roles.guard';

describe('RolesGuard', () => {
  let guard: RolesGuard;
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
    guard = new RolesGuard(reflector);
  });

  function createMockContext(userRole?: string): ExecutionContext {
    return {
      getHandler: () => ({}),
      getClass: () => ({}),
      switchToHttp: () => ({
        getRequest: () => ({
          user: userRole ? { id: 'u-1', email: 'test@pfis.com', role: userRole } : null,
        }),
      }),
    } as any;
  }

  it('allows access when no roles are required', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(undefined);
    const context = createMockContext('project_member');
    expect(guard.canActivate(context)).toBe(true);
  });

  it('throws ForbiddenException when user context is missing', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['main_admin']);
    const context = createMockContext(undefined);
    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });

  it('allows access when user has the required role (exact match)', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['main_admin']);
    const context = createMockContext('main_admin');
    expect(guard.canActivate(context)).toBe(true);
  });

  it('allows access when role normalizes (underscores/casing)', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['main_admin', 'project_manager']);
    const context = createMockContext('Project_Manager');
    expect(guard.canActivate(context)).toBe(true);
  });

  it('throws ForbiddenException when user role is not authorized', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['main_admin', 'project_manager']);
    const context = createMockContext('project_member');
    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });

  it('allows finance manager when finance_manager is in allowed roles', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['main_admin', 'finance_manager']);
    const context = createMockContext('finance_manager');
    expect(guard.canActivate(context)).toBe(true);
  });
});
