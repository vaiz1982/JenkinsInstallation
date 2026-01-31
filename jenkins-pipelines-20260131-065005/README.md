# Jenkins Pipeline Scripts Backup
Extracted from config.xml files

## Extraction Date
Sat Jan 31 06:50:06 UTC 2026

## Job Statistics
- Total jobs processed: 0
- Pipeline jobs extracted: 6
- SCM-based pipelines: 0

## Contents
Each job folder contains:
1. `config.xml.original` - Original Jenkins job configuration
2. `pipeline-script.groovy` - Extracted pipeline script (if pipeline job)
3. `Jenkinsfile` - Same as pipeline script in Jenkinsfile format
4. `scm-info.txt` - SCM repository information (if SCM-based)
5. `description.txt` - Job description (if available)

## Restoration
To restore a pipeline:
1. Create a new Pipeline job in Jenkins
2. Copy the contents of `pipeline-script.groovy` into the Pipeline script section
3. Or use the `Jenkinsfile` if setting up from SCM

## Extracted Jobs
- echo-app1
  - Pipeline script: 112 lines
- echo-app2
  - Pipeline script: 105 lines
- echo-app2_withGitpush
  - Pipeline script: 271 lines
- echo-app2_withGitpush_all5thApps
  - Pipeline script: 316 lines
- echo-app2_withGitpush_all5thApps_2
  - Pipeline script: 198 lines
- echo-app2_withGitpush_all5thApps_3
  - Pipeline script: 418 lines
