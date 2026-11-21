import { Controller, Get, Post, Body, UseGuards, Put, Delete, Param } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get()
  async getCategories() {
    return this.categoriesService.findAll();
  }

  @Roles('main_admin', 'finance_manager', 'finance')
  @Post()
  async createCategory(@Body() body: any) {
    return this.categoriesService.create(body);
  }

  @Roles('main_admin', 'finance_manager', 'finance')
  @Put(':id')
  async updateCategory(@Param('id') id: string, @Body() body: any) {
    return this.categoriesService.update(id, body);
  }

  @Roles('main_admin', 'finance_manager', 'finance')
  @Delete(':id')
  async removeCategory(@Param('id') id: string) {
    return this.categoriesService.remove(id);
  }
}
