pipeline {More actions
    agent any            

    environment {
        DOCKER_IMAGE = "maye18/koreflow"
        GIT_CREDS     = 'github-credentials'
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

        stage('Check for version.json Changes') {
            when { changeset 'version.json' }
            steps {
                script {
                    sh "git config --global --add safe.directory ${env.WORKSPACE}"
                    if (!fileExists('version.json')) {
                        error("version.json file not found in changes!")
                    }
                    echo "version.json found and changes detected. Proceeding to parse."
                }
            }
        }

        stage('Parse version.json') {
            steps {
                script {
                    sh "git config --global --add safe.directory ${env.WORKSPACE}"
                    def versionInfo = readJSON file: 'version.json'
                    env.VERSION = versionInfo.version

                    def notesList = versionInfo.notes
                    def tempNotes = ''
                    for (int i = 0; i < notesList.size(); i++) {
                        tempNotes += "- ${notesList[i]}"
                        if (i < notesList.size() - 1) { tempNotes += "\n" }
                    }
                    env.NOTES = tempNotes

                    versionInfo.metadata.buildDate = new Date().format("yyyy-MM-dd HH:mm")
                    writeJSON file: 'version.json', json: versionInfo, pretty: 4

                    echo "Building version: ${env.VERSION}"
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

                        def repoUrl = "https://github.com/${env.DOCKER_IMAGE.split('/')[0]}/${env.DOCKER_IMAGE.split('/')[1]}.git"
                        def branchToPull = env.BRANCH_NAME ?: 'main'

                        echo "Attempting to sync repository from: ${repoUrl} and pull branch: ${branchToPull}"

                        // Fetch all remote branches and prune stale ones
                        sh "git fetch origin" 
                        sh "git remote update origin --prune" 

                        // Pull changes into the current working branch (e.g., 'main')
                        sh "git pull origin ${branchToPull}" 

                        def newBranchName = "release/${env.VERSION}"
                        def remoteBranchRef = "origin/${newBranchName}" // The remote tracking branch
                        def remoteBranchRef = "origin/${newBranchName}"

                        // Check if the remote branch reference exists locally after fetch/update
                        def branchExistsRemotely = sh(script: "git branch -r | grep -w ${remoteBranchRef}", returnStatus: true) == 0

                        if (branchExistsRemotely) {
                            echo "Branch '${newBranchName}' already exists remotely. Checking out and resetting local branch to match remote."
                            // Reset the local branch to the remote tracking branch's HEAD
                            sh "git checkout ${newBranchName}" // Checkout the local branch (it will exist if it was tracked)
                            sh "git reset --hard ${remoteBranchRef}" // Hard reset to the remote's current state
                            sh "git checkout ${newBranchName}"
                            sh "git reset --hard ${remoteBranchRef}"
                        } else {
                            echo "Branch '${newBranchName}' does not exist remotely. Creating and pushing new branch."
                            // Create the new branch locally from the current HEAD
                            sh "git checkout -b ${newBranchName}"
                            echo "Created new branch: ${newBranchName}"
                            // Push the newly created local branch to remote
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
                        echo "$DOCKER_PASS_FOR_DOCKER_BUILD" | sudo docker login \\
                            --username "$DOCKER_USER_FOR_DOCKER_BUILD" \\
                            --password-stdin
                    '''
                }

                sh """
                    sudo docker build \\
                        -t ${env.DOCKER_IMAGE}:latest \\
                        -t ${env.DOCKER_IMAGE}:${env.VERSION} \\
                        .
                """
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh """
                    sudo docker push ${env.DOCKER_IMAGE}:latest
                """
                sh """
                    sudo docker push ${env.DOCKER_IMAGE}:${env.VERSION}
                """
            }
        }
    }
        
        stage('Promote Version (Bump and Push to Main)') {
        when { expression { return currentBuild.result == 'SUCCESS' } }
        steps {
            withCredentials([usernamePassword(
                credentialsId: env.GIT_CREDS,
                usernameVariable: 'GIT_USERNAME',
                passwordVariable: 'GIT_PASSWORD'
            )]) {
                script {
                    def versionInfo = readJSON file: 'version.json'
                    def (major, minor, patch) = versionInfo.version.tokenize('.').collect { it as int }
            when { expression { return currentBuild.result == 'SUCCESS' } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.GIT_CREDS,
                    usernameVariable: 'GIT_USERNAME',
                    passwordVariable: 'GIT_PASSWORD'
                )]) {
                    script {
                        def versionInfo = readJSON file: 'version.json'
                        def (major, minor, patch) = versionInfo.version.tokenize('.').collect { it as int }

                    patch += 1
                    def newVersion = "${major}.${minor}.${patch}"
                    versionInfo.version = newVersion
                    versionInfo.metadata.buildDate = new Date().format("yyyy-MM-dd HH:mm")
                    writeJSON file: 'version.json', json: versionInfo, pretty: 4
                        patch += 1
                        def newVersion = "${major}.${minor}.${patch}"
                        versionInfo.version = newVersion
                        versionInfo.metadata.buildDate = new Date().format("yyyy-MM-dd HH:mm")
                        writeJSON file: 'version.json', json: versionInfo, pretty: 4

                    sh 'git config user.name "Jenkins"'
                    sh 'git config user.email "jenkins@example.com"'
                    sh "git config --global credential.helper store"
                    sh "echo 'https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com' > ~/.git-credentials"
                        sh 'git config user.name "Jenkins"'
                        sh 'git config user.email "jenkins@example.com"'
                        sh "git config --global credential.helper store"
                        sh "echo 'https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com' > ~/.git-credentials"

                    def headBranch = 'main'
                    def headRepo = "https://github.com/${env.DOCKER_IMAGE.split('/')[0]}/${env.DOCKER_IMAGE.split('/')[1]}.git"
                        def headBranch = 'main'
                        def headRepo = "https://github.com/${env.DOCKER_IMAGE.split('/')[0]}/${env.DOCKER_IMAGE.split('/')[1]}.git"

                    sh "git checkout ${headBranch}"
                    sh "git pull ${headRepo} ${headBranch}"
                    sh 'git add version.json'
                    sh "git commit -m '🔁 Version bump to ${newVersion} after successful deployment'"
                    sh "git push ${headRepo} ${headBranch}"
                        sh "git checkout ${headBranch}"
                        sh "git pull ${headRepo} ${headBranch}"
                        sh 'git add version.json'
                        sh "git commit -m '🔁 Version bump to ${newVersion} after successful deployment'"
                        sh "git push ${headRepo} ${headBranch}"

                    sh "rm ~/.git-credentials"
                    sh "git config --global --unset credential.helper"
                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"

                    echo "✔️ Promoted to version ${newVersion} and updated head repo on '${headBranch}'"
                        echo "✔️ Promoted to version ${newVersion} and updated head repo on '${headBranch}'"
                    }
                }
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
