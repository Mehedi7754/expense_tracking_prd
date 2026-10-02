import { IsBoolean, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateLeaveDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsString()
  @IsNotEmpty()
  startDate: string;

  @IsString()
  @IsNotEmpty()
  endDate: string;

  @IsString()
  @IsIn(['paid', 'unpaid', 'sick', 'casual', 'maternity', 'emergency'])
  @IsNotEmpty()
  leaveType: 'paid' | 'unpaid' | 'sick' | 'casual' | 'maternity' | 'emergency';

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsBoolean()
  isApproved?: boolean;
}
