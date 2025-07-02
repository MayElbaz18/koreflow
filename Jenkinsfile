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
                    echo 'Cleaning workspace before checkout...'
                    sh 'git clean -fdx'
                    echo 'Checking out SCM...'
                    checkout scm

                    if (env.GIT_BRANCH) {
                        env.BRANCH_NAME = env.GIT_BRANCH.replace('origin/', '')
                        echo "Set BRANCH_NAME from GIT_BRANCH to: ${env.BRANCH_NAME}"
                    } else if (env.BRANCH_NAME == null || env.BRANCH_NAME == 'HEAD') {
                        env.BRANCH_NAME = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
                        if (env.BRANCH_NAME == 'HEAD' && env.CHANGE_BRANCH) {
                            env.BRANCH_NAME = env.CHANGE_BRANCH
                        } else if (env.BRANCH_NAME == 'HEAD') {
                            env.BRANCH_NAME = 'main'
                        }
                        echo "Re-evaluated BRANCH_NAME to: ${env.BRANCH_NAME}"
                    }
                }
            }
        }

        stage('Parse version.json') {
            steps {
                script {
                    sh "git config --global --add safe.directory ${env.WORKSPACE}"
                    if (!fileExists('version.json')) {
                        error("version.json file not found! Cannot parse version information.")
                    }
                    def versionInfo = readJSON file: 'version.json'
                    env.VERSION = versionInfo.version.toString()

                    def notesList = versionInfo.notes
                    def tempNotes = ''
                    for (int i = 0; i < notesList.size(); i++) {
                        tempNotes += "- ${notesList[i]}"
                        if (i < notesList.size() - 1) { tempNotes += "\n" }
                    }
                    env.NOTES = tempNotes

                    echo "Initial version from version.json: ${env.VERSION}"
                    echo "Release notes:\n${env.NOTES}"
                }
            }
        }

        stage('Setup Workspace-Dependent Env Vars') {
            steps {
                script {
                    env.DOCKER_CONFIG = "${env.WORKSPACE}/.docker"
                    echo "DOCKER_CONFIG is set to: ${env.DOCKER_CONFIG}"
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

                        echo ">>> Fetching from origin"
                        sh "git fetch origin"

                        echo ">>> Listing remote branches"
                        sh "git branch -r"

                        echo ">>> Checking out local branch ${headBranch}"
                        sh "git checkout ${headBranch}"

                        echo ">>> Resetting local branch to origin/${headBranch}"
                        def resetResult = sh(
                            script: "git reset --hard origin/${headBranch}",
                            returnStatus: true
                        )
                        if (resetResult != 0) {
                            error("❌ Failed to reset to origin/${headBranch}. Does it exist?")
                        }

                        echo ">>> Reset successful"

                        def jsonContent = readFile('version.json')
                        def currentVersionRegex = /"version":\s*"(\d+\.\d+\.\d+)"/
                        def currentVersionMatch = (jsonContent =~ currentVersionRegex)

                        if (!currentVersionMatch) {
                            error("Could not find 'version' field in version.json or it's not in expected format (X.Y.Z).")
                        }

                        def currentVersion = currentVersionMatch[0][1]
                        def (major, minor, patch) = currentVersion.tokenize('.').collect { it as int }
                        patch += 1
                        def newVersion = "${major}.${minor}.${patch}"
                        def buildDate = new Date().format("yyyy-MM-dd HH:mm")
                        def escapedOldVersion = java.util.regex.Pattern.quote(currentVersion)

                        def updatedJsonContent = jsonContent.replaceFirst(
                            "\"version\":\\s*\"${escapedOldVersion}\"",
                            "\"version\": \"${newVersion}\""
                        ).replaceFirst(
                            "\"buildDate\":\\s*\".*?\"",
                            "\"buildDate\": \"${buildDate}\""
                        )

                        writeFile(file: 'version.json', text: updatedJsonContent)

                        sh 'git add version.json'
                        sh "git commit -m '🤖 CI: Version bump to ${newVersion} after successful deployment [ci skip]'"

                        sh "git config --global credential.helper store"
                        sh "echo 'https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com' > ~/.git-credentials"

                        echo ">>> Pushing updated branch to origin"
                        sh "git push origin ${headBranch}"

                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"

                        echo "✔️ Promoted to version ${newVersion} and pushed to origin/${headBranch}"
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
                        sh "git remote update origin --prune"
                        sh "git pull origin ${branchToPull}"

                        def newBranchName = "release/${env.VERSION}"
                        def remoteBranchRef = "origin/${newBranchName}"

                        def branchExistsRemotely = sh(script: "git branch -r | grep -w ${remoteBranchRef}", returnStatus: true) == 0

                        if (branchExistsRemotely) {
                            echo "Branch '${newBranchName}' already exists remotely. Checking out and resetting local branch to match remote."
                            sh "git checkout ${newBranchName}"
                            sh "git reset --hard ${remoteBranchRef}"
                        } else {
                            echo "Branch '${newBranchName}' does not exist remotely. Creating and pushing new branch."
                            sh "git checkout -b ${newBranchName}"
                            echo "Created new branch: ${newBranchName}"
                            sh "git push origin ${newBranchName}"
                            echo "Pushed branch ${newBranchName} to remote."
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
                script {
                    echo "Copying files to the new repository/branch..."
                    echo "File copying complete (or skipped if not configured)."
                }
            }
        }

        stage('Docker Login, Build and Tag') {
            steps {
                sh "mkdir -p ${env.DOCKER_CONFIG}"

                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDS,
                    usernameVariable: 'DOCKER_USER_FOR_DOCKER_BUILD',
                    passwordVariable: 'DOCKER_PASS_FOR_DOCKER_BUILD'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS_FOR_DOCKER_BUILD" | sudo docker login \
                            --username "$DOCKER_USER_FOR_DOCKER_BUILD" \
                            --password-stdin
                    '''
                }

                sh """
                    sudo docker build \
                        -t ${env.DOCKER_IMAGE}:latest \
                        -t ${env.DOCKER_IMAGE}:${env.VERSION} \
                        .
                """
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh "sudo docker push ${env.DOCKER_IMAGE}:latest"
                sh "sudo docker push ${env.DOCKER_IMAGE}:${env.VERSION}"
            }
        }
    }

    post {
        always {
            node('built-in') { cleanWs() }
        }
        failure {
            echo "Pipeline failed! Check the logs for details."
        }
        success {
            echo "Pipeline completed successfully! Image ${env.DOCKER_IMAGE}:${env.VERSION} pushed."
        }
    }
}
