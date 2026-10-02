import { IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class SetSalaryDto {
  @IsNumber()
  @Min(0)
  @IsNotEmpty()
  monthlySalary: number;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  standardWorkingDays?: number;

  @IsOptional()
  @IsString()
  effectiveFrom?: string;
}
