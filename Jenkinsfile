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
                    def logResult = { message ->
                        def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")
                        writeFile file: 'pipelineResults.log', text: "[${timestamp}] ${message}\n", append: true
                    }
                    env.LOG_FN = logResult // Save to env to reuse

                    env.DOCKER_GID = sh(returnStdout: true, script: 'getent group docker | cut -d: -f3').trim()
                    echo "Discovered Docker GID on agent: ${env.DOCKER_GID}"

                    writeFile file: 'pipelineResults.log', text: ''
                    logResult("✅ Initialized environment, Docker GID: ${env.DOCKER_GID}")
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
                        env.LOG_FN("✅ Checked out branch: ${env.BRANCH_NAME}")
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

                    def changedEngine = filesChanged.any { it.startsWith('engine/') }
                    def changedCLI = filesChanged.any { it.startsWith('korectl/') }

                    env.ENGINE_CHANGED = changedEngine.toString()
                    env.CLI_CHANGED = changedCLI.toString()

                    env.LOG_FN("🔍 Files changed: ${filesChanged}")
                    env.LOG_FN("🔧 ENGINE_CHANGED=${env.ENGINE_CHANGED}, CLI_CHANGED=${env.CLI_CHANGED}")

                    if (filesChanged.size() == 1 && filesChanged[0] == 'version.json') {
                        echo "Only version.json changed - skipping rest of the pipeline."
                        env.LOG_FN("ℹ️ Only version.json changed - pipeline skipped.")
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
                    env.LOG_FN("✅ Parsed version.json: ${env.VERSION}")
                }
            }
        }

        stage('Setup Workspace-Dependent Env Vars') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                script {
                    env.DOCKER_CONFIG = "${env.WORKSPACE}/.docker"
                    echo "DOCKER_CONFIG is set to: ${env.DOCKER_CONFIG}"
                    env.LOG_FN("🔧 DOCKER_CONFIG set: ${env.DOCKER_CONFIG}")
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
                script { env.LOG_FN("✅ CLI tests run (simulated)") }
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
                    env.LOG_FN("✅ Built Docker image: ${DOCKER_IMAGE}:${VERSION}")
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
                script { env.LOG_FN("✅ ENGINE tests run (simulated)") }
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
                    '''
                    script { env.LOG_FN("✅ Docker image pushed: ${DOCKER_IMAGE}:${VERSION}") }
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

                        if (latestVersionBranch && latestVersionBranch != mainBranch) {
                            echo "Merging latest version branch ${latestVersionBranch} into ${mainBranch}"
                            sh "git checkout ${mainBranch}"
                            sh "git pull origin ${mainBranch}"
                            sh "git merge origin/${latestVersionBranch} || echo 'Nothing to merge'"
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
                        env.LOG_FN("✅ Branch ${newBranchName} updated with version.json")

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
                            env.LOG_FN("🏷️ Tag ${tagName} created and pushed")
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

                        env.LOG_FN("✅ Finished version branching and bump for ${env.VERSION}")
                    }
                }
            }
        }

        stage('Trigger CD Pipeline') {
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
                    build job: 'Provisioning', propagate: false
                    env.LOG_FN("🚀 Triggered downstream CD pipeline: Provisioning")
                }
            }
        }

        stage('Push Pipeline Results Log') {
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
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

                        def resultsBranch = "results/v${env.VERSION}"
                        def remoteRef = "origin/${resultsBranch}"

                        def branchExists = sh(script: "git branch -r | grep -w ${remoteRef}", returnStatus: true) == 0

                        if (branchExists) {
                            echo "🔁 Branch ${resultsBranch} already exists. Resetting it."
                            sh "git checkout ${resultsBranch}"
                            sh "git reset --hard ${remoteRef}"
                        } else {
                            echo "🌱 Creating new results branch: ${resultsBranch}"
                            sh "git checkout -b ${resultsBranch}"
                        }

                        sh "git add pipelineResults.log"
                        sh "git commit -m 'Add pipeline results log for version v${env.VERSION}' || echo '⚠️ No changes to commit'"
                        sh "git push origin ${resultsBranch}"

                        env.LOG_FN("📄 pipelineResults.log committed and pushed to ${resultsBranch}")

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
                env.LOG_FN("ℹ️ Pipeline finished with result: ${currentBuild.currentResult}")
            }
            cleanWs()
        }
        failure {
            echo "Pipeline failed!"
            script { env.LOG_FN("❌ Pipeline failed!") }
        }
        success {
            echo "Pipeline succeeded!"
            script { env.LOG_FN("✅ Pipeline succeeded! Image: ${env.DOCKER_IMAGE}:${env.VERSION}") }
        }
    }
}