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
                    // Clear log file at start
                    writeFile file: 'pipelineResults.logg', text: ''
                    def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                    sh "echo '[${timestamp}] ✅ Initialized environment' >> pipelineResults.logg"

                    env.DOCKER_GID = sh(returnStdout: true, script: 'getent group docker | cut -d: -f3').trim()
                    echo "Discovered Docker GID on agent: ${env.DOCKER_GID}"
                    timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                    sh "echo '[${timestamp}] Docker GID: ${env.DOCKER_GID}' >> pipelineResults.logg"
                }
            }
        }

        stage('Checkout SCM') {
            steps {
                script {
                    dir(env.WORKSPACE) {
                        sh "git config --global --add safe.directory ${env.WORKSPACE}"
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
                        def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                        sh "echo '[${timestamp}] ✅ Checked out branch: ${env.BRANCH_NAME}' >> pipelineResults.logg"
                    }
                }
            }
        }

        stage('Check for meaningful changes') {
            steps {
                script {
                    // Only use changeSets inside this script block!
                    def filesChanged = []
                    for (changeSet in currentBuild.changeSets) {
                        for (entry in changeSet.items) {
                            filesChanged.addAll(entry.affectedFiles.collect { it.path })
                        }
                    }
                    filesChanged = filesChanged.unique()
                    echo "Changed files: ${filesChanged}"

                    // Set env vars only as strings, not objects
                    env.ENGINE_CHANGED = filesChanged.any { it.startsWith('engine/') } ? 'true' : 'false'
                    env.CLI_CHANGED = filesChanged.any { it.startsWith('korectl/') } ? 'true' : 'false'

                    def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                    sh "echo '[${timestamp}] 🔍 Files changed: ${filesChanged}' >> pipelineResults.logg"
                    sh "echo '[${timestamp}] 🔧 ENGINE_CHANGED=${env.ENGINE_CHANGED}, CLI_CHANGED=${env.CLI_CHANGED}' >> pipelineResults.logg"

                    if (filesChanged.size() == 1 && filesChanged[0] == 'version.json') {
                        echo "Only version.json changed - skipping rest of the pipeline."
                        sh "echo '[${timestamp}] ℹ️ Only version.json changed - pipeline skipped.' >> pipelineResults.logg"
                        currentBuild.result = 'SUCCESS'
                        // Use 'return' only inside script block, not outside
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
                    def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                    sh "echo '[${timestamp}] ✅ Parsed version.json: ${env.VERSION}' >> pipelineResults.logg"
                }
            }
        }

        stage('Setup Workspace-Dependent Env Vars') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                script {
                    env.DOCKER_CONFIG = "${env.WORKSPACE}/.docker"
                    echo "DOCKER_CONFIG is set to: ${env.DOCKER_CONFIG}"
                    def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                    sh "echo '[${timestamp}] 🔧 DOCKER_CONFIG set: ${env.DOCKER_CONFIG}' >> pipelineResults.logg"
                }
            }
        }

        stage('CLI Tests (If CLI Changed)') {
            when {
                allOf {
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                    expression { env.CLI_CHANGED == 'true' }
                }
            }
            steps {
                echo "Running CLI tests..."
                script { 
                    def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                    sh "echo '[${timestamp}] ✅ CLI tests run (simulated)' >> pipelineResults.logg"
                }
            }
        }

        stage('Build Docker Image') {
            when {
                allOf {
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                    anyOf {
                        expression { env.ENGINE_CHANGED == 'true' }
                        expression { env.CLI_CHANGED == 'true' }
                    }
                }
            }
            steps {
                script {
                    echo "[STEP] Build Docker image ${DOCKER_IMAGE}:${VERSION} ..."
                    sh "docker build -t ${DOCKER_IMAGE}:${VERSION} ."
                    sh "docker build -t ${DOCKER_IMAGE}:latest"
                    def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                    sh "echo '[${timestamp}] ✅ Built Docker image: ${DOCKER_IMAGE}:${VERSION}' >> pipelineResults.logg"
                }
            }
        }

        stage('Engine Tests with Kind and Helm, (If ENGINE Changed)') { 
            when {
                allOf {
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                    expression { env.ENGINE_CHANGED == 'true' }
                }
            }
            steps {
                echo "Running ENGINE tests..."
                script { 
                    def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                    sh "echo '[${timestamp}] ✅ ENGINE tests run (simulated)' >> pipelineResults.logg"
                }
            }
        }

        stage('Docker Login and Push') {
            when {
                allOf {
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                    anyOf {
                        expression { env.ENGINE_CHANGED == 'true' }
                        expression { env.CLI_CHANGED == 'true' }
                    }
                }
            } 
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDS,
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                    echo "$DOCKER_PASS" | docker login --username "$DOCKER_USER" --password-stdin
                    docker push ${DOCKER_IMAGE}:${VERSION}
                    docker push ${DOCKER_IMAGE}:latest
                    '''
                    script { 
                        def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                        sh "echo '[${timestamp}] ✅ Docker image pushed: ${DOCKER_IMAGE}:${VERSION}' >> pipelineResults.logg"
                    }
                }
            }
        }

        stage('Create Version Branch and Tag and commit version.json and push') {
            when {
                allOf {
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                    anyOf {
                        expression { env.ENGINE_CHANGED == 'true' }
                        expression { env.CLI_CHANGED == 'true' }
                    }
                }
            }
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

                        sh "git fetch --all"

                        def mainBranch = "main"
                        def newBranchName = "v${env.VERSION}"
                        def remoteBranchRef = "origin/${newBranchName}"

                        def latestVersionBranch = sh(
                            script: "git branch -r | grep 'origin/v' | sort -Vr | head -n1 | awk -F'/' '{print \$2}'",
                            returnStdout: true
                        ).trim()
                        sh "git add pipelineResults.logg"
                        sh "git commit -m 'Add pipeline results log for version v${env.VERSION}' || echo '⚠️ No changes to commit'"                        
                        if (latestVersionBranch && latestVersionBranch != mainBranch) {
                            echo "Merging latest version branch ${latestVersionBranch} into ${mainBranch}"
                            sh "git checkout ${mainBranch}"
                            sh "git pull origin ${mainBranch}"
                            sh "git merge origin/${latestVersionBranch}"
                            sh "git push origin ${mainBranch}"
                        } else {
                            sh "git checkout ${mainBranch}"
                            sh "git pull origin ${mainBranch}"
                        }

                        def branchExists = sh(script: "git branch -r | grep -w ${remoteBranchRef}", returnStatus: true) == 0

                        if (branchExists) {
                            sh "git checkout ${newBranchName}"
                            sh "git reset --hard ${remoteBranchRef}"
                        } else {
                            sh "git checkout -b ${newBranchName}"
                            sh "git push origin ${newBranchName}"
                        }

                        sh "git add version.json"
                        sh "git commit -m 'Add version.json build for ${env.VERSION}' || echo 'No changes to commit'"
                        sh "git push origin ${newBranchName}"
                        def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                        sh "echo '[${timestamp}] ✅ Branch ${newBranchName} updated with version.json' >> pipelineResults.logg"

                        sh "git checkout ${mainBranch}"
                        sh "git push origin ${mainBranch}"

                        def tagName = "v${env.VERSION}"
                        def remoteTagExists = sh(script: "git ls-remote --tags origin ${tagName}", returnStatus: true) == 0

                        if (!remoteTagExists) {
                            def localTagExists = sh(script: "git tag -l ${tagName}", returnStatus: true) == 0
                            if (!localTagExists) {
                                sh "git tag ${tagName}"
                            }
                            sh "git push origin ${tagName}"
                            sh "echo '[${timestamp}] 🏷️ Tag ${tagName} created and pushed' >> pipelineResults.logg"
                        }

                        def (major, minor, patch) = env.VERSION.tokenize('.').collect { it as int }
                        patch += 1
                        def nextVersion = "${major}.${minor}.${patch}"

                        def versionFile = readFile('version.json')
                        versionFile = versionFile
                            .replaceFirst(/\"version\":\s*\"${env.VERSION}\"/, "\"version\": \"${nextVersion}\"")
                            .replaceFirst(/\"buildDate\":\s*\".*?\"/, "\"buildDate\": \"${new Date().format('yyyy-MM-dd HH:mm')}\"")
                        writeFile file: 'version.json', text: versionFile

                        sh "git add version.json"
                        sh "git commit -m 'Prep next version ${nextVersion} [ci skip]' || echo 'No next version bump to commit'"
                        sh "git push origin ${mainBranch}"

                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"

                        sh "echo '[${timestamp}] ✅ Finished version branching and bump for ${env.VERSION}' >> pipelineResults.logg"
                    }
                }
            }
        }

        stage('Trigger Provisioning Pipeline') {
            when {
                allOf {
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                    anyOf {
                        expression { env.ENGINE_CHANGED == 'true' }
                        expression { env.CLI_CHANGED == 'true' }
                    } 
                }
            }
            steps {
                script {
                    build job: 'Provisioning', wait: false, propagate: false
                    def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                    sh "echo '[${timestamp}] 🚀 Triggered downstream CD pipeline: Provisioning' >> pipelineResults.logg"
                }
            }
        }

        stage('Push Pipeline Results Log') {
            when {
                allOf {
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                    anyOf {
                        expression { env.ENGINE_CHANGED == 'true' }
                        expression { env.CLI_CHANGED == 'true' }
                    } 
                }
            }
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

                        sh "git fetch --all"

                        def newBranchName = "v${env.VERSION}"
                        def remoteRef = "origin/${newBranchName}"

                        def branchExists = sh(script: "git branch -r | grep -w ${remoteRef}", returnStatus: true) == 0

                        if (branchExists) {
                            echo "🔁 Branch ${newBranchName} already exists. Resetting it."
                            sh "git checkout ${newBranchName}"
                            sh "git reset --hard ${remoteRef}"
                        } else {
                            echo "🌱 Creating new results branch: ${newBranchName}"
                            sh "git checkout -b ${newBranchName}"
                        }

                        sh "git add pipelineResults.logg"
                        sh "git commit -m 'Add pipeline results log for version v${env.VERSION}' || echo '⚠️ No changes to commit'"
                        sh "git push origin ${newBranchName}"

                        def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                        sh "echo '[${timestamp}] 📄 pipelineResults.logg committed and pushed to ${newBranchName}' >> pipelineResults.logg"

                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"
                    }
                }
            }
        }

    }

    post {
        always {
            script {
                def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                sh "echo '[${timestamp}] ℹ️ Pipeline finished with result: ${currentBuild.currentResult}' >> pipelineResults.logg"
            }
            cleanWs()
        }
        failure {
            echo "Pipeline failed!"
            script { 
                def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                sh "echo '[${timestamp}] ❌ Pipeline failed!' >> pipelineResults.logg"
            }
        }
        success {
            echo "Pipeline succeeded!"
            script { 
                def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                sh "echo '[${timestamp}] ✅ Pipeline succeeded! Image: ${env.DOCKER_IMAGE}:${env.VERSION}' >> pipelineResults.logg"
            }
        }
    }
}