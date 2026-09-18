import 'package:flutter/material.dart';
import '../../models/project_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class ProjectDropdown extends StatelessWidget {
  final List<ProjectModel> projects;
  final String? selectedProjectId;
  final ValueChanged<ProjectModel?> onChanged;
  final String? Function(String?)? validator;

  const ProjectDropdown({
    super.key,
    required this.projects,
    required this.selectedProjectId,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedProjectId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Assigned Project *',
        hintText: 'Select project',
      ),
      validator: validator ??
          (val) {
            if (val == null || val.isEmpty) {
              return 'Please select a project';
            }
            return null;
          },
      items: projects.map((p) {
        return DropdownMenuItem<String>(
          value: p.id,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                p.client,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) {
          onChanged(null);
        } else {
          final p = projects.firstWhere((item) => item.id == id);
          onChanged(p);
        }
      },
    );
  }
}
