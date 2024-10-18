pipeline {
    agent any

    stages {
        stage('Install Node.js') {
            steps {
                // Install Node.js version 18
                script {
                    def nodeVersion = '18.x'
                    if (isUnix()) {
                        sh "curl -fsSL https://deb.nodesource.com/setup_${nodeVersion} | sudo -E bash -"
                        sh "sudo apt-get install -y nodejs"
                    } else {
                        bat 'choco install nodejs'
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