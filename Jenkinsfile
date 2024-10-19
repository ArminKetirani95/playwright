pipeline {
    agent any

    stages {
        stage('Install Node.js') {
            steps {
                script {
                    // Install Node.js version 18
                    def nodeVersion = '18.x'
                    if (isUnix()) {
                        // Install Node.js directly without sudo
                        sh """
                        curl -fsSL https://deb.nodesource.com/setup_${nodeVersion} | bash -
                        apt-get install -y nodejs
                        """
                    } else {
                        // For Windows, install Node.js using Chocolatey
                        bat 'choco install nodejs -y'
                    }
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                // Run npm ci (same as in Azure DevOps)
                sh 'npm ci'
            }
        }

        stage('Install Playwright Browsers') {
            steps {
                // Install Playwright browsers (same as Azure DevOps)
                sh 'npx playwright install --with-deps'
            }
        }

        stage('Run Playwright Tests') {
            steps {
                // Run Playwright tests
                sh 'npx playwright test'
            }
            environment {
                CI = 'true' // Set CI environment variable
            }
        }

        stage('Publish Playwright Report') {
            steps {
                // Publish the Playwright test report
                archiveArtifacts artifacts: 'playwright-report/**', allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            // You can also configure post steps for notifications or cleanup here
            echo 'Pipeline finished'
        }
    }
}