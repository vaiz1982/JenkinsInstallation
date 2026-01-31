pipeline {  
    agent any

    environment {  
        DOCKER_HUB_REPO = 'vaiz82/elementary-echo-app'  
        TEST_PORT = '5001'  
    }

    stages {  
        stage('📥 Clone Repository') {  
            steps {  
                cleanWs()
                git branch: 'main', url: 'https://github.com/vaiz1982/elementary-apps.git'
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
                    // First, let's check what's in the app
                    sh """
                    echo "=== Looking at app structure ==="
                    ls -la echo-app/
                    echo ""
                    echo "=== Checking main.py ==="
                    head -20 echo-app/main.py
                    """
                    
                    // Now test the container
                    sh """
                    # Clean up any existing container
                    docker stop test-container-${BUILD_NUMBER} 2>/dev/null || true
                    docker rm test-container-${BUILD_NUMBER} 2>/dev/null || true
                    
                    echo "Starting container on port ${TEST_PORT}..."
                    
                    # Start container with logs visible
                    docker run -d --name test-container-${BUILD_NUMBER} -p ${TEST_PORT}:5000 ${DOCKER_HUB_REPO}:build-${BUILD_NUMBER}
                    
                    echo "Waiting for app to start..."
                    sleep 10
                    
                    echo "=== Container logs ==="
                    docker logs test-container-${BUILD_NUMBER}
                    
                    echo ""
                    echo "=== Testing connection ==="
                    echo "Trying simple curl to port ${TEST_PORT}..."
                    
                    # Try curl with timeout and verbose output
                    curl -s -o /dev/null -w "Response: %{http_code}\\n" --max-time 10 http://localhost:${TEST_PORT}/ || echo "Curl command failed"
                    
                    # Also try common endpoints
                    for endpoint in "/" "/health" "/echo" "/api"; do
                        echo "Testing http://localhost:${TEST_PORT}\${endpoint}"
                        curl -s -o /dev/null -w "  Status: %{http_code}\\n" --max-time 5 http://localhost:${TEST_PORT}\${endpoint} || true
                    done
                    
                    echo ""
                    echo "=== Cleanup ==="
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
