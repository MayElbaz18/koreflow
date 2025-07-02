pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "maye18/koreflow"
        GITHUB_USERNAME = "MayElbaz18"
        GIT_CREDS = 'github-credentials'
        DOCKER_CREDS = 'dockerhub-credentials'
        AWS_CREDS_ID = 'aws-credentials'
        SSH_KEY_CRED_ID = 'ssh-credentials'
        DOCKER_BUILDKIT = '1'
    }

    // Reusable function for Git operations with credentials
    // Using a shared library would be even better for larger pipelines
    def withGitCredentials(body) {
        withCredentials([usernamePassword(
            credentialsId: env.GIT_CREDS,
            usernameVariable: 'GIT_USERNAME',
            passwordVariable: 'GIT_PASSWORD'
        )]) {
            // Set up Git user and global credential helper
            sh "git config user.name 'Jenkins'"
            sh "git config user.email 'jenkins@example.com'"
            writeFile file: "${env.WORKSPACE}/.git-credentials", text: "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com\n"
            sh "mv ${env.WORKSPACE}/.git-credentials ~/.git-credentials"
            sh "git config --global credential.helper store"

            try {
                body()
            } finally {
                // Clean up credentials
                sh "rm -f ~/.git-credentials" // Use -f to avoid error if file doesn't exist
                sh "git config --global --unset credential.helper"
            }
        }
    }

    stages {
        stage('Initialize Environment') {
            steps {
                script {
                    env.DOCKER_GID = sh(returnStdout: true, script: 'getent group docker | cut -d: -f3').trim()
                    echo "Discovered Docker GID on agent: ${env.DOCKER_GID}"
                }
            }
        }

        stage('Checkout SCM') {
            steps {
                script {
                    dir(env.WORKSPACE) {
                        sh "git config --global --add safe.directory ${env.WORKSPACE}"
                        sh 'git clean -fdx'
                        checkout scm

                        // Determine the branch name
                        if (env.GIT_BRANCH) {
                            env.BRANCH_NAME = env.GIT_BRANCH.replace('origin/', '')
                        } else if (env.BRANCH_NAME == null || env.BRANCH_NAME == 'HEAD') {
                            env.BRANCH_NAME = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
                            if (env.BRANCH_NAME == 'HEAD' && env.CHANGE_BRANCH) {
                                env.BRANCH_NAME = env.CHANGE_BRANCH
                            } else if (env.BRANCH_NAME == 'HEAD') {
                                env.BRANCH_NAME = 'main' // Fallback to 'main'
                            }
                        }
                        echo "Checked out branch: ${env.BRANCH_NAME}"
