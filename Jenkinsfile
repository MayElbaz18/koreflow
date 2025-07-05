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

                    def changedEngine = filesChanged.any { it.startsWith('engine/') }
                    def changedCLI = filesChanged.any { it.startsWith('korectl/') }

                    env.ENGINE_CHANGED = changedEngine.toString()
                    env.CLI_CHANGED = changedCLI.toString()

                    if (filesChanged.size() == 1 && filesChanged[0] == 'version.json') {
                        echo "Only version.json changed - skipping rest of the pipeline."
                        currentBuild.result = 'SUCCESS'
                        return
                    }
                }
            }
        }

        stage('Version Bump') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                script {
                    def jsonContent = readFile('version.json')

                    def currentVersionPattern = ~/\"version\":\s*\"(\d+\.\d+\.\d+)\"/
                    def currentVersionMatcher = currentVersionPattern.matcher(jsonContent)

                    if (!currentVersionMatcher.find()) {
                        error(" Could not find 'version' field in version.json or it's not in expected format (X.Y.Z).")
                    }

                    def currentVersion = currentVersionMatcher.group(1)
                    echo "🔍 Current version: ${currentVersion}"

                    def (major, minor, patch) = currentVersion.tokenize('.').collect { it as int }
                    patch += 1
                    def newVersion = "${major}.${minor}.${patch}"
                    echo "⬆️  New version: ${newVersion}"

                    def updatedJson = jsonContent
                        .replaceFirst(/\"version\":\s*\"${currentVersion}\"/, "\"version\": \"${newVersion}\"")
                        .replaceFirst(/\"buildDate\":\s*\".*?\"/, "\"buildDate\": \"${new Date().format('yyyy-MM-dd HH:mm')}\"")

                    echo "DEBUG: updatedJson content:\n${updatedJson}"

                    writeFile(file: 'version.json', text: updatedJson)
                    echo "✅ version.json updated with new version: ${newVersion}"
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

        stage('CLI Tests (If CLI Changed)') {
            when {
                allOf {
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                    expression { env.CLI_CHANGED == 'true' }
                }
            }
            steps {
                echo "Running application tests..."
            }
        }

        stage('Build Docker Image') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                script {
                    echo "[STEP] Build Docker image ${DOCKER_IMAGE}:${VERSION} ..."
                    sh "sudo docker build -t ${DOCKER_IMAGE}:${VERSION} ."
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
                sh '''
                    set -e

                    echo "[STEP] Install kind and helm..."
                    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && mv ./kind /usr/local/bin/kind
                    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

                    echo "[STEP] Create test Kubernetes cluster..."
                    kind create cluster --name koreflow-ci --wait 60s

                    echo "[STEP] Load local Docker image into Kind cluster..."
                    kind load docker-image ${DOCKER_IMAGE}:${VERSION} --name koreflow-ci

                    echo "[STEP] Deploy koreflow via Helm chart using local image..."
                    helm install koreflow ./charts/koreflow \
                        --set image.repository=${DOCKER_IMAGE} \
                        --set image.tag=${VERSION} \
                        --wait

                    echo "[STEP] Wait for koreflow pod to become ready..."
                    kubectl wait --for=condition=ready pod -l app=koreflow --timeout=120s

                    echo "[STEP] Run Health check for koreflow inside pod..."
                    POD=$(kubectl get pods -l app=koreflow -o jsonpath="{.items[0].metadata.name}")
                    kubectl exec "$POD" -- curl -sf http://localhost:8080/health || {
                        echo "[ERROR] Health check failed!"
                        kind delete cluster --name koreflow-ci
                        exit 1
                    }

                    echo "[STEP] Run engine integration test script..."
                    kubectl exec "$POD" -- /bin/sh -c "chmod +x /app/test/engineTest.sh && /app/test/engineTest.sh" || {
                        echo "[ERROR] Engine integration test failed!"
                        kind delete cluster --name koreflow-ci
                        exit 1
                    }

                    echo "[STEP] Check for Slack module execution in logs..."
                    LOG_FOUND=$(kubectl logs "$POD" | grep -c "Sending info message to")
                    if [ "$LOG_FOUND" -gt 0 ]; then
                        echo "[✅] Slack workflow executed successfully."
                    else
                        echo "[❌] Slack workflow NOT detected in logs."
                        echo "[!] Dumping recent logs:"
                        kubectl logs "$POD" | tail -n 100
                        kind delete cluster --name koreflow-ci
                        exit 1
                    fi

                    echo "[STEP] Clean up test cluster..."
                    kind delete cluster --name koreflow-ci
                '''
            }
        }

        stage('Docker Login and Push') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDS,
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | sudo docker login --username "$DOCKER_USER" --password-stdin
                        sudo docker push ${DOCKER_IMAGE}:${VERSION}
                    '''
                }
            }
        }

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

                        def newBranchName = "v${env.VERSION}"
                        def remoteBranchRef = "origin/${newBranchName}"

                        def branchExists = sh(script: "git branch -r | grep -w ${remoteBranchRef}", returnStatus: true) == 0

                        if (branchExists) {
                            sh "git checkout ${newBranchName}"
                            sh "git reset --hard ${remoteBranchRef}"
                        } else {
                            sh "git checkout -b ${newBranchName}"
                            sh "git push origin ${newBranchName}"
                        }

                        sh "git add version.json"
                        sh "git commit -m 'Bump version to ${env.VERSION}' || echo 'No changes to commit'"
                        sh "git push origin ${newBranchName}"

                        def tagName = "v${env.VERSION}"
                        def tagExists = sh(script: "git tag -l ${tagName}", returnStatus: true) == 0

                        if (!tagExists) {
                            sh "git tag ${tagName}"
                            sh "git push origin ${tagName}"
                            echo "🏷️ Tag ${tagName} created and pushed"
                        } else {
                            echo "⚠️ Tag ${tagName} already exists, skipping tag creation"
                        }

                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"

                        echo "📦 Branch ${newBranchName} created or updated"
                    }
                }
            }
        }

        stage('Copy Files to New Repo (If Applicable)') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                echo "Copying files to the new repository/branch... (skipped if not configured)"
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
