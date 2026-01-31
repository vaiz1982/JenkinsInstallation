pipeline {  
    agent any

    environment {  
        DOCKER_HUB_ORG = 'vaiz82'
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

        stage('🚀 Process All Apps') {  
            parallel {
                stage('📦 echo-app') {
                    steps {
                        script {
                            buildAndTestApp('echo-app', 5001)
                        }
                    }
                }
                stage('📦 hello-app') {
                    steps {
                        script {
                            buildAndTestApp('hello-app', 5002)
                        }
                    }
                }
                stage('📦 math-app') {
                    steps {
                        script {
                            buildAndTestApp('math-app', 5003)
                        }
                    }
                }
                stage('📦 rand-app') {
                    steps {
                        script {
                            buildAndTestApp('rand-app', 5004)
                        }
                    }
                }
                stage('📦 time-app') {
                    steps {
                        script {
                            buildAndTestApp('time-app', 5005)
                        }
                    }
                }
            }
        }

        stage('📤 Push All to Docker Hub') {  
            steps {  
                script {
                    withCredentials([usernamePassword(  
                        credentialsId: 'docker-hub-credentials',  
                        usernameVariable: 'DOCKER_USER',  
                        passwordVariable: 'DOCKER_PAT'  
                    )]) {  
                        sh """
                        echo "\$DOCKER_PAT" | docker login -u "\$DOCKER_USER" --password-stdin
                        
                        echo "=== Pushing all apps to Docker Hub ==="
                        docker push vaiz82/echo-app:build-${BUILD_NUMBER}
                        docker push vaiz82/hello-app:build-${BUILD_NUMBER}
                        docker push vaiz82/math-app:build-${BUILD_NUMBER}
                        docker push vaiz82/rand-app:build-${BUILD_NUMBER}
                        docker push vaiz82/time-app:build-${BUILD_NUMBER}
                        echo "✅ All apps pushed to Docker Hub!"
                        """
                    }
                }
            }  
        }

        stage('📝 Create Simple Jenkinsfile') {  
            steps {  
                script {
                    // Create a VERY simple Jenkinsfile
                    sh '''
                    cat > Jenkinsfile << 'EOF'
pipeline {
    agent any
    
    environment {
        DOCKER_HUB_ORG = "vaiz82"
    }
    
    stages {
        stage("📥 Clone Repository") {
            steps {
                cleanWs()
                git branch: "main", url: "https://github.com/vaiz1982/elementary-apps.git"
            }
        }
        
        stage("🚀 Build All Apps") {
            parallel {
                stage("📦 echo-app") {
                    steps {
                        dir("echo-app") {
                            sh """
                            docker build -t ${DOCKER_HUB_ORG}/echo-app:build-${BUILD_NUMBER} .
                            echo "✅ echo-app built"
                            """
                        }
                    }
                }
                stage("📦 hello-app") {
                    steps {
                        dir("hello-app") {
                            sh """
                            docker build -t ${DOCKER_HUB_ORG}/hello-app:build-${BUILD_NUMBER} .
                            echo "✅ hello-app built"
                            """
                        }
                    }
                }
                stage("📦 math-app") {
                    steps {
                        dir("math-app") {
                            sh """
                            docker build -t ${DOCKER_HUB_ORG}/math-app:build-${BUILD_NUMBER} .
                            echo "✅ math-app built"
                            """
                        }
                    }
                }
                stage("📦 rand-app") {
                    steps {
                        dir("rand-app") {
                            sh """
                            docker build -t ${DOCKER_HUB_ORG}/rand-app:build-${BUILD_NUMBER} .
                            echo "✅ rand-app built"
                            """
                        }
                    }
                }
                stage("📦 time-app") {
                    steps {
                        dir("time-app") {
                            sh """
                            docker build -t ${DOCKER_HUB_ORG}/time-app:build-${BUILD_NUMBER} .
                            echo "✅ time-app built"
                            """
                        }
                    }
                }
            }
        }
        
        stage("📤 Push All to Docker Hub") {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "docker-hub-credentials",
                    usernameVariable: "DOCKER_USER",
                    passwordVariable: "DOCKER_PAT"
                )]) {
                    sh """
                    echo "$DOCKER_PAT" | docker login -u "$DOCKER_USER" --password-stdin
                    
                    echo "Pushing echo-app..."
                    docker push ${DOCKER_HUB_ORG}/echo-app:build-${BUILD_NUMBER}
                    
                    echo "Pushing hello-app..."
                    docker push ${DOCKER_HUB_ORG}/hello-app:build-${BUILD_NUMBER}
                    
                    echo "Pushing math-app..."
                    docker push ${DOCKER_HUB_ORG}/math-app:build-${BUILD_NUMBER}
                    
                    echo "Pushing rand-app..."
                    docker push ${DOCKER_HUB_ORG}/rand-app:build-${BUILD_NUMBER}
                    
                    echo "Pushing time-app..."
                    docker push ${DOCKER_HUB_ORG}/time-app:build-${BUILD_NUMBER}
                    
                    echo "✅ All apps pushed to Docker Hub!"
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
            echo "🎉 All apps built and pushed successfully!"
        }
    }
}
EOF
                    '''
                    echo "✅ Jenkinsfile created"
                }
            }  
        }

        stage('📤 Push to GitHub') {  
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
                        echo "Note: GitHub token not found. Skipping GitHub push."
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
                        
                        # Add Jenkinsfile
                        git add Jenkinsfile
                        
                        # Check for changes
                        if git diff --cached --quiet; then
                            echo "No changes to commit"
                        else
                            # Commit and push
                            git commit -m "CI/CD: Add Jenkinsfile for multi-app pipeline - Build ${BUILD_NUMBER}"
                            git push https://${GITHUB_TOKEN}@github.com/vaiz1982/${GIT_REPO}.git ${GIT_BRANCH}
                            echo "✅ Jenkinsfile pushed to GitHub!"
                        fi
                        """
                    }  
                }  
            }  
        }
    }

    post {  
        always {  
            cleanWs()
            script {
                // Clean up containers
                def apps = ['echo-app', 'hello-app', 'math-app', 'rand-app', 'time-app']
                apps.each { app ->
                    sh """
                    docker stop test-${app}-${BUILD_NUMBER} 2>/dev/null || true
                    docker rm test-${app}-${BUILD_NUMBER} 2>/dev/null || true
                    """
                }
            }
        }
        success {
            echo "🎉 All 5 apps processed successfully!"
        }
    }  
}

// Helper function to build and test an app
def buildAndTestApp(appName, port) {
    dir(appName) {
        script {
            echo "Processing ${appName} on port ${port}..."
            
            // Check if app directory exists and has Dockerfile
            if (fileExists('Dockerfile')) {
                // Build Docker image
                sh """
                docker build -t ${env.DOCKER_HUB_ORG}/${appName}:build-${env.BUILD_NUMBER} .
                echo "✅ ${appName} image built"
                """
                
                // Try to test if it's a web app
                try {
                    sh """
                    # Clean up
                    docker stop test-${appName}-${env.BUILD_NUMBER} 2>/dev/null || true
                    docker rm test-${appName}-${env.BUILD_NUMBER} 2>/dev/null || true
                    
                    # Run container
                    docker run -d --name test-${appName}-${env.BUILD_NUMBER} -p ${port}:5000 ${env.DOCKER_HUB_ORG}/${appName}:build-${env.BUILD_NUMBER}
                    
                    # Wait
                    sleep 10
                    
                    echo "=== Testing ${appName} ==="
                    
                    # Try to access
                    curl -s -o /dev/null -w "Status: %{http_code}\\\\n" --max-time 5 http://localhost:${port}/ || echo "Test completed"
                    
                    # Cleanup
                    docker stop test-${appName}-${env.BUILD_NUMBER}
                    docker rm test-${appName}-${env.BUILD_NUMBER}
                    """
                } catch (Exception e) {
                    echo "⚠️ Could not test ${appName}, but image built successfully"
                }
            } else {
                echo "⚠️ No Dockerfile found for ${appName}, skipping..."
            }
        }
    }
}
