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
        }

        stage('Check for meaningful changes') {
            steps {
                script {
                    def changeLogSets = currentBuild.changeSets
                    def filesChanged = []
                    for (changeSet in changeLogSets) {
                        for (entry in changeSet.items) {
                            filesChanged.addAll(entry.affectedFiles.collect { it.path })
                        }
                    }
                    filesChanged = filesChanged.unique()
                    echo "Changed files: ${filesChanged}"

                    if (filesChanged.size() == 1 && filesChanged[0] == 'version.json') {
                        echo "Only version.json changed - skipping rest of the pipeline."
                        currentBuild.result = 'SUCCESS'
                        return
                    }
                }
            }
        }

        stage('Parse version.json') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
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
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                script {
                    env.DOCKER_CONFIG = "${env.WORKSPACE}/.docker"
                    echo "DOCKER_CONFIG is set to: ${env.DOCKER_CONFIG}"
                }
            }
        }

        stage('Test Application (Placeholder)') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                echo "Running application tests..."
            }
        }

        ---

        stage('Promote Version (Bump and Push to Main)') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
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
                        def repoUrl = "https://github.com/${env.GITHUB_USERNAME}/koreflow.git"

                        dir(env.WORKSPACE) {
                            echo "Attempting to sync with the latest '${headBranch}' from ${repoUrl}..."
                            sh "git fetch origin"
                            sh "git checkout ${headBranch}"
                            def resetResult = sh(script: "git reset --hard origin/${headBranch}", returnStatus: true)
                            if (resetResult != 0) {
                                error("❌ Failed to reset to origin/${headBranch}")
                            }

                            def jsonContent = readFile('version.json')

                            // Use Pattern.compile for robust regex with interpolated variables
                            java.util.regex.Pattern currentVersionPattern = java.util.regex.Pattern.compile("\"version\":\\s*\"(\\d+\\.\\d+\\.\\d+)\"")
                            java.util.regex.Matcher currentVersionMatcher = currentVersionPattern.matcher(jsonContent)

                            if (!currentVersionMatcher.find()) {
                                error("Could not find 'version' field in version.json or it's not in expected format (X.Y.Z).")
                            }
                            def currentVersion = currentVersionMatcher.group(1)
                            echo "Current version parsed: ${currentVersion}"

                            def (major, minor, patch) = currentVersion.tokenize('.').collect { it as int }
                            patch += 1
                            def newVersion = "${major}.${minor}.${patch}"

                            def buildDate = new Date().format("yyyy-MM-dd HH:mm")

                            // Use Pattern.compile for robust regex with interpolated variables
                            java.util.regex.Pattern oldVersionReplacePattern = java.util.regex.Pattern.compile(java.util.regex.Pattern.quote("\"version\":\\s*\"${currentVersion}\""))
                            def updatedJsonContent = oldVersionReplacePattern.matcher(jsonContent).replaceFirst("\"version\": \"${newVersion}\"")

                            java.util.regex.Pattern buildDateReplacePattern = java.util.regex.Pattern.compile("\"buildDate\":\\s*\".*?\"")
                            updatedJsonContent = buildDateReplacePattern.matcher(updatedJsonContent).replaceFirst("\"buildDate\": \"${buildDate}\"")

                            writeFile(file: 'version.json', text: updatedJsonContent)
                            echo "Updated version.json content in workspace."

                            def addStatus = sh(script: 'git add version.json', returnStatus: true)
                            if (addStatus != 0) {
                                error("❌ git add failed")
                            }

                            def commitStatus = sh(script: "git commit -m '🤖 CI: Version bump to ${newVersion} [ci skip]'", returnStatus: true)
                            if (commitStatus != 0) {
                                echo "No changes to commit (version may already be bumped or other issues)."
                            }

                            writeFile file: "${env.WORKSPACE}/.git-credentials", text: "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com\n"
                            sh "git config --global credential.helper store"
                            sh "mv ${env.WORKSPACE}/.git-credentials ~/.git-credentials"

                            echo "Attempting to push updated branch ${headBranch} to ${repoUrl}..."
                            def pushStatus = sh(script: "git push origin ${headBranch}", returnStatus: true)
                            if (pushStatus != 0) {
                                error("❌ git push failed")
                            }

                            sh "rm ~/.git-credentials"
                            sh "git config --global --unset credential.helper"

                            echo "✔️ Promoted to version ${newVersion} on branch '${headBranch}'"
                            env.VERSION = newVersion
                        }
                    }
                }
            }
        }

        ---

        stage('Create Version Branch') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
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

                        echo "📦 Branch ${newBranchName} created or updated"
                    }
                }
            }
        }

        ---

        stage('Copy Files to New Repo (If Applicable)') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                echo "Copying files to the new repository/branch... (skipped if not configured)"
            }
        }

        stage('Docker Login, Build and Tag') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
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
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
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
            echo "Pipeline failed! Check the logs for details."
        }
        success {
            echo "Pipeline completed successfully! Image ${env.DOCKER_IMAGE}:${env.VERSION} pushed."
        }
    }
}
