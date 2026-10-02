import { IsNotEmpty, IsNumber, IsOptional, IsString, IsIn } from 'class-validator';

export class CheckInDto {
  @IsNumber()
  @IsNotEmpty()
  latitude: number;

  @IsNumber()
  @IsNotEmpty()
  longitude: number;

  @IsOptional()
  @IsString()
  addressText?: string;

  @IsOptional()
  @IsString()
  address_text?: string;

  @IsOptional()
  @IsString()
  @IsIn(['morning', 'afternoon'])
  sessionType?: 'morning' | 'afternoon';

  @IsOptional()
  @IsString()
  @IsIn(['morning', 'afternoon'])
  session_type?: 'morning' | 'afternoon';

  @IsOptional()
  @IsString()
  deviceInfo?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
