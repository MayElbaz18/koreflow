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
                    echo "Discovered Docker GID: ${env.DOCKER_GID}"
                }
            }
        }

        stage('Checkout SCM') {
            steps {
                script {
                    sh "git config --global --add safe.directory ${env.WORKSPACE}"
                    sh 'git clean -fdx'
                    checkout scm

                    env.BRANCH_NAME = env.GIT_BRANCH?.replace('origin/', '') ?: sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
                    if (env.BRANCH_NAME == 'HEAD' && env.CHANGE_BRANCH) {
                        env.BRANCH_NAME = env.CHANGE_BRANCH
                    } else if (env.BRANCH_NAME == 'HEAD') {
                        env.BRANCH_NAME = 'main'
                    }
                    echo "Checked out branch: ${env.BRANCH_NAME}"
                }
            }
        }

        stage('Parse version.json') {
            steps {
                script {
                    if (!fileExists('version.json')) {
                        error("version.json not found.")
                    }
                    def versionInfo = readJSON file: 'version.json'
                    env.VERSION = versionInfo.version.toString()
                    env.NOTES = versionInfo.notes.collect { "- $it" }.join('\n')
                    echo "Version: ${env.VERSION}\nNotes:\n${env.NOTES}"
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
                echo "Running tests (placeholder)..."
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
                        sh "git reset --hard origin/${headBranch}"

                        def jsonContent = readFile('version.json')
                        def versionMatch = (jsonContent =~ /"version":\s*"(\d+\.\d+\.\d+)"/)
                        if (!versionMatch) {
                            error("Invalid version format in version.json")
                        }

                        def currentVersion = versionMatch[0][1]
                        def (major, minor, patch) = currentVersion.tokenize('.').collect { it as int }
                        def newVersion = "${major}.${minor}.${patch + 1}"
                        def buildDate = new Date().format("yyyy-MM-dd HH:mm")

                        def updatedJson = jsonContent
                            .replaceFirst(/"version":\s*".*?"/, "\"version\": \"${newVersion}\"")
                            .replaceFirst(/"buildDate":\s*".*?"/, "\"buildDate\": \"${buildDate}\"")

                        writeFile(file: 'version.json', text: updatedJson)

                        def addStatus = sh(script: 'git add version.json', returnStatus: true)
                        if (addStatus != 0) {
                            error("❌ git add failed")
                        }

                        def commitStatus = sh(script: "git commit -m '🤖 CI: Version bump to ${newVersion} [ci skip]'", returnStatus: true)
                        if (commitStatus != 0) {
                            echo "Nothing to commit — version may already be bumped."
                        }

                        sh "git config --global credential.helper store"
                        writeFile file: "${env.WORKSPACE}/.git-credentials", text: "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com\n"
                        sh "mv ${env.WORKSPACE}/.git-credentials ~/.git-credentials"

                        def pushStatus = sh(script: "git push origin ${headBranch}", returnStatus: true)
                        if (pushStatus != 0) {
                            error("❌ git push failed")
                        }

                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"

                        env.VERSION = newVersion
                        echo "✅ Version promoted to ${newVersion}"
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
                        writeFile file: "${env.WORKSPACE}/.git-credentials", text: "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com\n"
                        sh "mv ${env.WORKSPACE}/.git-credentials ~/.git-credentials"
                        sh "git config --global credential.helper store"

                        def newBranchName = "release/${env.VERSION}"
                        def branchExists = sh(script: "git ls-remote --heads origin ${newBranchName}", returnStatus: true) == 0

                        if (branchExists) {
                            sh "git checkout ${newBranchName}"
                            sh "git reset --hard origin/${newBranchName}"
                        } else {
                            sh "git checkout -b ${newBranchName}"
                            sh "git push origin ${newBranchName}"
                        }

                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"
                        echo "📦 Branch ${newBranchName} created or updated"
                    }
                }
            }
        }

        stage('Copy Files to New Repo (If Applicable)') {
            when { expression { return currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                echo "Copying files... (skipped if not configured)"
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
            echo "🚨 Pipeline failed. Check logs above."
        }
        success {
            echo "✅ Pipeline completed. Image ${env.DOCKER_IMAGE}:${env.VERSION} pushed."
        }
    }
}
