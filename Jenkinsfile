pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "maye18/koreflow"
        GITHUB_USERNAME = "MayElbaz18"
        GIT_CREDS      = 'github-credentials'
        DOCKER_CREDS = 'dockerhub-credentials'
        AWS_CREDS_ID = 'aws-credentials'
        SSH_KEY_CRED_ID = 'ssh-credentials'
        DOCKER_BUILDKIT = '1'
    }

    stages {
        stage('Initialize Environment') {
            steps {
                script {
                    def dockerGid = sh(returnStdout: true, script: 'getent group docker | cut -d: -f3').trim()
                    env.DOCKER_GID = dockerGid
                    echo "Discovered Docker GID on agent: ${env.DOCKER_GID}"
                }
            }
        }

        stage('Checkout SCM') {
            steps {
                script {
                    sh "git config --global --add safe.directory ${env.WORKSPACE}"
                    sh 'git clean -fdx'
                    checkout scm

                    if (env.GIT_BRANCH) {
                        env.BRANCH_NAME = env.GIT_BRANCH.replace('origin/', '')
                    } else if (env.BRANCH_NAME == null || env.BRANCH_NAME == 'HEAD') {
                        env.BRANCH_NAME = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
                        if (env.BRANCH_NAME == 'HEAD' && env.CHANGE_BRANCH) {
                            env.BRANCH_NAME = env.CHANGE_BRANCH
                        } else if (env.BRANCH_NAME == 'HEAD') {
                            env.BRANCH_NAME = 'main'
                        }
                    }
                    echo "Checked out branch: ${env.BRANCH_NAME}"
                }
            }
        }

        stage('Parse version.json') {
            steps {
                script {
                    if (!fileExists('version.json')) {
                        error("version.json file not found! Cannot parse version information.")
                    }
                    def versionInfo = readJSON file: 'version.json'
                    env.VERSION = versionInfo.version.toString()

                    def notesList = versionInfo.notes
                    env.NOTES = notesList.collect { "- $it" }.join('\n')

                    echo "Parsed version: ${env.VERSION}"
                    echo "Release notes:\n${env.NOTES}"
                }
            }
        }

        stage('Setup Workspace-Dependent Env Vars') {
            steps {
                script {
                    env.DOCKER_CONFIG = "${env.WORKSPACE}/.docker"
                }
            }
        }

        stage('Test Application (Placeholder)') {
            steps {
                echo "Running application tests..."
            }
        }

        stage('Promote Version (Bump and Push to Main)') {
            when { expression { return currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.GIT_CREDS,
                    usernameVariable: 'GIT_USERNAME',
                    passwordVariable: 'GIT_PASSWORD'
                )]) {
                    script {
                        sh "git config user.name 'Jenkins'"
                        sh "git config user.email 'jenkins@example.com'"

                        def headBranch = env.BRANCH_NAME ?: 'main'

                        sh "git fetch origin"
                        sh "git checkout ${headBranch}"
                        def resetResult = sh(script: "git reset --hard origin/${headBranch}", returnStatus: true)
                        if (resetResult != 0) {
                            error("❌ Failed to reset to origin/${headBranch}")
                        }

                        def jsonContent = readFile('version.json')
                        def currentVersionMatch = (jsonContent =~ /"version":\s*"(\d+\.\d+\.\d+)"/)
                        if (!currentVersionMatch) {
                            error("Could not parse version from version.json")
                        }

                        def currentVersion = currentVersionMatch[0][1]
                        def (major, minor, patch) = currentVersion.tokenize('.').collect { it as int }
                        patch += 1
                        def newVersion = "${major}.${minor}.${patch}"
                        def buildDate = new Date().format("yyyy-MM-dd HH:mm")

                        def updatedJsonContent = jsonContent
                            .replaceFirst(/"version":\s*".*?"/, "\"version\": \"${newVersion}\"")
                            .replaceFirst(/"buildDate":\s*".*?"/, "\"buildDate\": \"${buildDate}\"")

                        writeFile(file: 'version.json', text: updatedJsonContent)

                        if (sh(script: 'git add version.json', returnStatus: true) != 0) {
                            error("Failed to stage version.json")
                        }

                        if (sh(script: "git commit -m '🤖 CI: Version bump to ${newVersion} [ci skip]'", returnStatus: true) != 0) {
                            echo "No changes to commit"
                        }

                        sh "git config --global credential.helper store"
                        sh "echo 'https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com' > ~/.git-credentials"
                        sh "git push origin ${headBranch}"
                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"

                        echo "✔️ Promoted to version ${newVersion}"
                        env.VERSION = newVersion
                    }
                }
            }
        }

        stage('Create Version Branch') {
            when { expression { return currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.GIT_CREDS,
                    usernameVariable: 'GIT_USERNAME',
                    passwordVariable: 'GIT_PASSWORD'
                )]) {
                    script {
                        sh "git config user.email 'jenkins@example.com'"
                        sh "git config user.name 'Jenkins'"
                        sh "git config --global credential.helper store"
                        sh "echo 'https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com' > ~/.git-credentials"

                        def branchToPull = env.BRANCH_NAME ?: 'main'
                        sh "git fetch origin"
                        sh "git pull origin ${branchToPull}"

                        def newBranchName = "release/${env.VERSION}"
                        def remoteBranchRef = "origin/${newBranchName}"

                        def branchExists = sh(script: "git branch -r | grep -w ${remoteBranchRef}", returnStatus: true) == 0

                        if (branchExists) {
                            sh "git checkout ${newBranchName}"
                            sh "git reset --hard ${remoteBranchRef}"
                        } else {
                            sh "git checkout -b ${newBranchName}"
                            sh "git push origin ${newBranchName}"
                        }

                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"
                    }
                }
            }
        }

        stage('Copy Files to New Repo (If Applicable)') {
            when { expression { return currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                echo "Copying files to the new repository/branch (if needed)..."
            }
        }

        stage('Docker Login, Build and Tag') {
            steps {
                sh "mkdir -p ${env.DOCKER_CONFIG}"
                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDS,
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login \
                            --username "$DOCKER_USER" \
                            --password-stdin
                    '''
                }

                sh """
                    docker build \
                        -t ${env.DOCKER_IMAGE}:latest \
                        -t ${env.DOCKER_IMAGE}:${env.VERSION} \
                        .
                """
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh "docker push ${env.DOCKER_IMAGE}:latest"
                sh "docker push ${env.DOCKER_IMAGE}:${env.VERSION}"
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        failure {
            echo "Pipeline failed. Check logs for details."
        }
        success {
            echo "Pipeline completed successfully. Image ${env.DOCKER_IMAGE}:${env.VERSION} pushed."
        }
    }
}
