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
                    sh """
                    # Clean up
                    docker stop test-container-${BUILD_NUMBER} 2>/dev/null || true
                    docker rm test-container-${BUILD_NUMBER} 2>/dev/null || true
                    
                    echo "Starting container on port ${TEST_PORT}..."
                    docker run -d --name test-container-${BUILD_NUMBER} -p ${TEST_PORT}:5000 ${DOCKER_HUB_REPO}:build-${BUILD_NUMBER}
                    
                    echo "Waiting for app to start..."
                    sleep 10
                    
                    echo "=== Container logs ==="
                    docker logs test-container-${BUILD_NUMBER}
                    
                    echo ""
                    echo "=== Testing the correct endpoint ==="
                    echo "Testing POST /echo endpoint with JSON data..."
                    
                    # Test the correct endpoint with POST method
                    curl -X POST http://localhost:${TEST_PORT}/echo \
                         -H "Content-Type: application/json" \
                         -d '{"message": "hello from jenkins", "test": true}' \
                         -w "\\nStatus: %{http_code}\\n"
                    
                    echo ""
                    echo "Testing GET /echo (should fail with 405 Method Not Allowed)..."
                    curl -v http://localhost:${TEST_PORT}/echo -w "\\nStatus: %{http_code}\\n" || true
                    
                    echo ""
                    echo "Testing GET / (should fail with 404 Not Found)..."
                    curl -v http://localhost:${TEST_PORT}/ -w "\\nStatus: %{http_code}\\n" || true
                    
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
