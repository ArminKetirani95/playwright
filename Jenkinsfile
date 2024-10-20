pipeline {
    agent {
        docker {
            image 'your-docker-image-name' // Use the Docker image you created
            args '-v /path/to/project:/app' // Mount your project folder
        }
    }

    stages {
        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Install Playwright Browsers') {
            steps {
                sh 'npx playwright install --with-deps'
            }
        }

        stage('Run Playwright Tests') {
            steps {
                sh 'npx playwright test'
            }
            environment {
                CI = 'true' // Set CI environment variable
            }
        }

        stage('Publish Playwright Report') {
            steps {
                archiveArtifacts artifacts: 'playwright-report/**', allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished'
        }
    }
}