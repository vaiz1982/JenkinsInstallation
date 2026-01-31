pipeline {  
    agent any

    environment {  
        DOCKER_HUB_REPO = 'vaiz82/elementary-echo-app'  
        TEST_PORT = '5001'  
        GIT_REPO = 'elementary-apps'
        GIT_BRANCH = 'main'
    }

    stages {  
        stage('📥 Clone Repository') {  
            steps {  
                cleanWs()
                git branch: 'main', url: "https://github.com/vaiz1982/${GIT_REPO}.git"
            }  
        }

        stage('📝 Update Dockerfile') {  
            steps {  
                dir('echo-app') {
                    script {
                        // Check current Dockerfile
                        sh '''
                        echo "=== Current Dockerfile ==="
                        cat Dockerfile
                        echo ""
                        '''
                        
                        // Create improved Dockerfile (optional improvements)
                        sh '''
                        cat > Dockerfile << 'EOF'
FROM python:3.9-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Run the application
CMD ["python", "main.py"]
EOF
                        
                        echo "=== Updated Dockerfile ==="
                        cat Dockerfile
                        '''
                    }
                }
            }  
        }

        stage('🔨 Build Image') {  
            steps {  
                dir('echo-app') {  
                    script {  
                        sh """
                        docker build -t ${DOCKER_HUB_REPO}:build-${BUILD_NUMBER} .  
                        echo "✅ Image built"  
                        """
                    }  
                }  
            }  
        }

        stage('🚀 Test Container') {  
            steps {  
                script {  
                    sh """
                    # Clean up
                    docker stop test-container-${BUILD_NUMBER} 2>/dev/null || true
                    docker rm test-container-${BUILD_NUMBER} 2>/dev/null || true
                    
                    echo "Starting container on port ${TEST_PORT}..."
                    docker run -d --name test-container-${BUILD_NUMBER} -p ${TEST_PORT}:5000 ${DOCKER_HUB_REPO}:build-${BUILD_NUMBER}
                    
                    sleep 10
                    
                    echo "=== Testing POST /echo ==="
                    curl -X POST http://localhost:${TEST_PORT}/echo \\
                         -H "Content-Type: application/json" \\
                         -d '{"test": "jenkins"}' \\
                         -w "\\nStatus: %{http_code}\\n" || true
                    
                    docker stop test-container-${BUILD_NUMBER}
                    docker rm test-container-${BUILD_NUMBER}
                    """
                }  
            }  
        }

        stage('📤 Push to Docker Hub') {  
            steps {  
                script {  
                    withCredentials([usernamePassword(  
                        credentialsId: 'docker-hub-credentials',  
                        usernameVariable: 'DOCKER_USER',  
                        passwordVariable: 'DOCKER_PAT'  
                    )]) {  
                        sh """
                        echo "\$DOCKER_PAT" | docker login -u "\$DOCKER_USER" --password-stdin
                        docker push ${DOCKER_HUB_REPO}:build-${BUILD_NUMBER}  
                        echo "✅ Pushed to Docker Hub!"  
                        """
                    }  
                }  
            }  
        }

        stage('📝 Create Jenkinsfile') {  
            steps {  
                script {
                    // Create Jenkinsfile at root of repository
                    sh '''
                    cat > Jenkinsfile << 'EOF'
pipeline {
    agent any
    
    environment {
        DOCKER_HUB_REPO = "vaiz82/elementary-echo-app"
        TEST_PORT = "5001"
    }
    
    stages {
        stage("📥 Clone Repository") {
            steps {
                cleanWs()
                git branch: "main", url: "https://github.com/vaiz1982/elementary-apps.git"
            }
        }
        
        stage("🔨 Build Image") {
            steps {
                dir("echo-app") {
                    sh """
                    docker build -t ${DOCKER_HUB_REPO}:build-${BUILD_NUMBER} .
                    echo "✅ Image built"
                    """
                }
            }
        }
        
        stage("🚀 Test Container") {
            steps {
                sh """
                # Clean up
                docker stop test-container-${BUILD_NUMBER} 2>/dev/null || true
                docker rm test-container-${BUILD_NUMBER} 2>/dev/null || true
                
                echo "Starting container..."
                docker run -d --name test-container-${BUILD_NUMBER} -p ${TEST_PORT}:5000 ${DOCKER_HUB_REPO}:build-${BUILD_NUMBER}
                
                sleep 10
                
                echo "=== Testing POST /echo ==="
                curl -X POST http://localhost:${TEST_PORT}/echo \\
                     -H "Content-Type: application/json" \\
                     -d '{"test": "jenkins"}' \\
                     -w "\\nStatus: %{http_code}\\n" || true
                
                docker stop test-container-${BUILD_NUMBER}
                docker rm test-container-${BUILD_NUMBER}
                """
            }
        }
        
        stage("📤 Push to Docker Hub") {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "docker-hub-credentials",
                    usernameVariable: "DOCKER_USER",
                    passwordVariable: "DOCKER_PAT"
                )]) {
                    sh """
                    echo "$DOCKER_PAT" | docker login -u "$DOCKER_USER" --password-stdin
                    docker push ${DOCKER_HUB_REPO}:build-${BUILD_NUMBER}
                    echo "✅ Pushed to Docker Hub!"
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo "✅ Pipeline completed successfully!"
        }
    }
}
EOF
                    
                    echo "✅ Jenkinsfile created"
                    '''
                }
            }  
        }

        stage('🚀 Push to GitHub') {  
            when {
                expression { 
                    try {
                        withCredentials([string(
                            credentialsId: 'github-token',
                            variable: 'GITHUB_TOKEN'
                        )]) {
                            return true
                        }
                    } catch (Exception e) {
                        echo "Note: GitHub token not found. To push to GitHub, create a 'github-token' credential."
                        return false
                    }
                }
            }
            steps {  
                script {  
                    withCredentials([string(  
                        credentialsId: 'github-token',  
                        variable: 'GITHUB_TOKEN'  
                    )]) {  
                        sh """
                        # Configure git
                        git config user.email "jenkins@ci-cd.com"
                        git config user.name "Jenkins CI/CD"
                        
                        # Add both files
                        git add echo-app/Dockerfile
                        git add Jenkinsfile
                        
                        # Check for changes
                        if git diff --cached --quiet; then
                            echo "No changes to commit"
                        else
                            # Commit and push
                            git commit -m "CI/CD: Update Dockerfile and add Jenkinsfile - Build ${BUILD_NUMBER}"
                            git push https://${GITHUB_TOKEN}@github.com/vaiz1982/${GIT_REPO}.git ${GIT_BRANCH}
                            echo "✅ Dockerfile and Jenkinsfile pushed to GitHub!"
                        fi
                        """
                    }  
                }  
            }  
        }
    }

    post {  
        always {  
            sh """
            docker stop test-container-${BUILD_NUMBER} 2>/dev/null || true
            docker rm test-container-${BUILD_NUMBER} 2>/dev/null || true
            """
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully! 🎉"
        }
    }  
}
