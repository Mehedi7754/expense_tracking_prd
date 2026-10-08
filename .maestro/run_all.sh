#!/bin/bash
echo "Running Employee Flow..."
maestro-runner test .maestro/01_login_employee.yaml
echo "Running Manager Flow..."
maestro-runner test .maestro/02_login_manager.yaml
echo "Running HR/Admin Flow..."
maestro-runner test .maestro/03_login_hr_admin.yaml
echo "All tests complete!"
