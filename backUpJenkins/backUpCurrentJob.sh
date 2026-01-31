#!/bin/bash
# extract-real-pipeline-scripts.sh

cd /home/ubuntu/alex/JenkinsInstallation

echo "=== EXTRACTING REAL PIPELINE SCRIPTS ==="
echo ""

# Create backup with clear name
BACKUP="real-pipeline-scripts-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

echo "\U0001f4c1 Backup directory: $BACKUP"
echo ""

# First, let's see what jobs actually exist
echo "=== Current Jenkins Jobs ==="
sudo ls -la /var/lib/jenkins/jobs/ | grep "^d" | awk '{print $9}' | while read JOB; do
    echo "\u2022 $JOB"
done

echo ""
echo "=== Extracting Pipeline Scripts ==="
echo ""

# Process each job
sudo ls /var/lib/jenkins/jobs/ | while read JOB_NAME; do
    CONFIG_FILE="/var/lib/jenkins/jobs/$JOB_NAME/config.xml"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "\U0001f50d Processing: $JOB_NAME"
        
        # Create job directory
        mkdir -p "$BACKUP/$JOB_NAME"
        
        # Copy the original config.xml
        sudo cp "$CONFIG_FILE" "$BACKUP/$JOB_NAME/"
        sudo chown $(whoami):$(whoami) "$BACKUP/$JOB_NAME/config.xml"
        
        # Check if it's a pipeline job
        if sudo grep -q "definition class=\"org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition\"" "$CONFIG_FILE"; then
            echo "  \U0001f4dd This is a PIPELINE job - extracting script..."
            
            # METHOD 1: Use awk to extract script (most reliable)
            sudo awk '
            /<script>/ {script=1; next}
            /<\/script>/ {script=0}
            script {print}
            ' "$CONFIG_FILE" > "$BACKUP/$JOB_NAME/Jenkinsfile" 2>/dev/null
            
            # Check if we got content
            if [ -s "$BACKUP/$JOB_NAME/Jenkinsfile" ]; then
                # Remove empty lines at start
                sed -i '/./,$!d' "$BACKUP/$JOB_NAME/Jenkinsfile"
                
                LINE_COUNT=$(wc -l < "$BACKUP/$JOB_NAME/Jenkinsfile")
                echo "  \u2705 Extracted Jenkinsfile ($LINE_COUNT lines)"
                
                # Show first 2 lines
                head -2 "$BACKUP/$JOB_NAME/Jenkinsfile" | sed 's/^/    /'
                
                # Also create .groovy version
                cp "$BACKUP/$JOB_NAME/Jenkinsfile" "$BACKUP/$JOB_NAME/pipeline.groovy"
            else
                echo "  \u26a0\ufe0f Could not extract script with awk, trying sed..."
                
                # METHOD 2: Try sed
                sudo sed -n '/<script>/,/<\/script>/p' "$CONFIG_FILE" | \
                    sed '1s/.*<script>//; $s/<\/script>.*//; /^$/d' > "$BACKUP/$JOB_NAME/Jenkinsfile" 2>/dev/null
                
                if [ -s "$BACKUP/$JOB_NAME/Jenkinsfile" ]; then
                    LINE_COUNT=$(wc -l < "$BACKUP/$JOB_NAME/Jenkinsfile")
                    echo "  \u2705 Extracted with sed ($LINE_COUNT lines)"
                    cp "$BACKUP/$JOB_NAME/Jenkinsfile" "$BACKUP/$JOB_NAME/pipeline.groovy"
                else
                    echo "  \u274c Failed to extract script"
                    rm -f "$BACKUP/$JOB_NAME/Jenkinsfile"
                fi
            fi
        else
            echo "  \u2699\ufe0f Not a pipeline job (Freestyle or other)"
            echo "Freestyle job" > "$BACKUP/$JOB_NAME/job-type.txt"
        fi
        
        # Extract job description
        sudo grep -oP '(?<=<description>).*?(?=</description>)' "$CONFIG_FILE" > "$BACKUP/$JOB_NAME/description.txt" 2>/dev/null
        
        echo ""
    else
        echo "\u26a0\ufe0f No config.xml found for: $JOB_NAME"
        echo ""
    fi
done

# Fix all permissions
sudo chown -R $(whoami):$(whoami) "$BACKUP"

# Create summary
echo "=== SUMMARY ==="
TOTAL_JOBS=$(ls "$BACKUP" | wc -l)
PIPELINE_JOBS=$(find "$BACKUP" -name "Jenkinsfile" | wc -l)

cat > "$BACKUP/README.md" << EOF
# REAL Jenkins Pipeline Scripts
Extracted on: $(date)

## Statistics
- Total Jenkins jobs: $TOTAL_JOBS
- Pipeline jobs with scripts: $PIPELINE_JOBS

## Job List
$(ls "$BACKUP" | sort | while read JOB; do
    echo "### $JOB"
    if [ -f "$BACKUP/$JOB/Jenkinsfile" ]; then
        LINES=$(wc -l < "$BACKUP/$JOB/Jenkinsfile" 2>/dev/null || echo "0")
        echo "- Type: Pipeline"
        echo "- Script lines: $LINES"
        echo "- Files:"
        echo "  - \`Jenkinsfile\` - The pipeline script"
        echo "  - \`pipeline.groovy\` - Same script in .groovy format"
        echo "  - \`config.xml\` - Original Jenkins configuration"
    elif [ -f "$BACKUP/$JOB/job-type.txt" ]; then
        echo "- Type: Freestyle"
    fi
    if [ -f "$BACKUP/$JOB/description.txt" ] && [ -s "$BACKUP/$JOB/description.txt" ]; then
        DESC=$(cat "$BACKUP/$JOB/description.txt")
        echo "- Description: $DESC"
    fi
    echo ""
done)

## How to Use
1. To recreate a pipeline job in Jenkins:
   - Create a new "Pipeline" job
   - Copy the contents of \`Jenkinsfile\` into the pipeline script section
   - Save and run

2. To restore from SCM:
   - Create a new "Pipeline" job
   - Select "Pipeline script from SCM"
   - Point to a repository containing the \`Jenkinsfile\`
EOF

# Show detailed output
echo ""
echo "=== DETAILED OUTPUT ==="
echo "Backup location: $BACKUP"
echo "Total jobs backed up: $TOTAL_JOBS"
echo "Pipeline scripts extracted: $PIPELINE_JOBS"
echo ""
echo "Pipeline jobs found:"
find "$BACKUP" -name "Jenkinsfile" | while read FILE; do
    JOB_DIR=$(dirname "$FILE")
    JOB_NAME=$(basename "$JOB_DIR")
    LINES=$(wc -l < "$FILE")
    echo "\u2022 $JOB_NAME: $LINES lines"
done

echo ""
echo "=== Adding to GitHub ==="
git add "$BACKUP"
git commit -m "REAL pipeline scripts backup - $(date +%Y-%m-%d_%H:%M:%S) - $PIPELINE_JOBS pipeline jobs"
git push origin master

echo ""
echo "\u2705 SUCCESS! Real pipeline scripts extracted and backed up!"
echo "\U0001f4c1 View at: https://github.com/vaiz1982/JenkinsInstallation/tree/master/$BACKUP"
