import { IsNotEmpty, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

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
  @Max(31)
  standardWorkingDays?: number;

  @IsOptional()
  @IsString()
  effectiveFrom?: string;
}
