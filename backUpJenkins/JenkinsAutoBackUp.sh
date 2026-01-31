pipeline {
    agent any
    stages {
        stage('Backup to GitHub') {
            steps {
                sh '''
                    cd /opt/jenkins-backup
                    git add .
                    git commit -m "Auto-backup $(date)"
                    git push
                '''
            }
        }
    }
}
