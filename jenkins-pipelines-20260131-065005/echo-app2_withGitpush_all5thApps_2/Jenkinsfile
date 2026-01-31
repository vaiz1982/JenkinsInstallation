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

        stage('🔍 Check Apps') {  
            steps {  
                script {
                    sh '''
                    echo "=== Available Apps ==="
                    ls -d */ | sed 's|/$||'
                    echo ""
                    
                    echo "=== Dockerfile Status ==="
                    for app in */; do
                        app_name=$(basename "$app")
                        if [ -f "$app/Dockerfile" ]; then
                            echo "✅ $app_name: Has Dockerfile"
                        else
                            echo "⚠️  $app_name: No Dockerfile"
                        fi
                    done
                    '''
                }
            }  
        }

        stage('🚀 Build Apps with Dockerfiles') {  
            steps {  
                script {
                    // Find apps with Dockerfiles
                    def appsWithDocker = sh(script: '''
                    for app in */; do
                        if [ -f "$app/Dockerfile" ]; then
                            basename "$app"
                        fi
                    done
                    ''', returnStdout: true).trim()
                    
                    if (appsWithDocker) {
                        def apps = appsWithDocker.split('\n')
                        echo "Building apps with Dockerfiles: ${apps}"
                        
                        // Build each app
                        apps.each { app ->
                            dir(app) {
                                sh """
                                docker build -t ${env.DOCKER_HUB_ORG}/${app}:build-${env.BUILD_NUMBER} .
                                echo "✅ ${app} image built"
                                """
                            }
                        }
                    } else {
                        echo "⚠️ No apps have Dockerfiles to build"
                    }
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
                        """
                        
                        // Find built images
                        def builtImages = sh(script: """
                        docker images --format '{{.Repository}}' | grep '^${env.DOCKER_HUB_ORG}/' | cut -d'/' -f2
                        """, returnStdout: true).trim()
                        
                        if (builtImages) {
                            def images = builtImages.split('\n')
                            images.each { app ->
                                sh """
                                echo "Pushing ${app}..."
                                docker push ${env.DOCKER_HUB_ORG}/${app}:build-${env.BUILD_NUMBER}
                                echo "✅ ${app} pushed"
                                """
                            }
                        } else {
                            echo "⚠️ No images to push"
                        }
                    }
                }
            }  
        }

        stage('📝 Create Simple Jenkinsfile') {  
            steps {  
                script {
                    // Create a VERY basic Jenkinsfile
                    sh '''
                    cat > Jenkinsfile << 'EOF'
pipeline {
    agent any
    
    environment {
        DOCKER_HUB_ORG = "vaiz82"
    }
    
    stages {
        stage("📥 Clone") {
            steps {
                cleanWs()
                git branch: "main", url: "https://github.com/vaiz1982/elementary-apps.git"
            }
        }
        
        stage("🔨 Build Apps") {
            steps {
                sh """
                # Build all apps with Dockerfiles
                for app in */; do
                    app_name=$(basename "$app")
                    if [ -f "$app/Dockerfile" ]; then
                        echo "Building $app_name..."
                        cd "$app"
                        docker build -t ${DOCKER_HUB_ORG}/$app_name:build-${BUILD_NUMBER} .
                        echo "✅ $app_name built"
                        cd ..
                    fi
                done
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
                    
                    # Push all built images
                    for app in */; do
                        app_name=$(basename "$app")
                        if docker images | grep -q "${DOCKER_HUB_ORG}/$app_name.*build-${BUILD_NUMBER}"; then
                            echo "Pushing $app_name..."
                            docker push ${DOCKER_HUB_ORG}/$app_name:build-${BUILD_NUMBER}
                        fi
                    done
                    
                    echo "✅ All apps pushed!"
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
EOF
                    '''
                    echo "✅ Jenkinsfile created"
                }
            }  
        }
    }

    post {  
        always {  
            cleanWs()
            sh """
            echo "Cleaning up..."
            docker ps -a --filter "name=test-" --format "{{.Names}}" | xargs -r docker stop 2>/dev/null || true
            docker ps -a --filter "name=test-" --format "{{.Names}}" | xargs -r docker rm 2>/dev/null || true
            """
        }
        success {
            echo "✅ Pipeline completed successfully!"
        }
    }  
}
