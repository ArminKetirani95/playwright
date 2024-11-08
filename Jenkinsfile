pipeline {
    agent any
    stages {
        stage('Install Browsers') {
            steps {
                bat 'npx playwright install'
            }
        }
        stage('Install Dependencies') {
            steps {
                bat 'npm install playwright'
            }
        }
        stage('Run Tests') {
            steps {
                bat 'npx playwright test --reporter=line,allure-playwright'
            }
        }
    }
}