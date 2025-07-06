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
                echo "Running CLI tests..."
            }
        }

        stage('Build Docker Image') {
            when { expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' } }
            steps {
                script {
                    echo "[STEP] Build Docker image ${DOCKER_IMAGE}:${VERSION} ..."
                    sh "docker build -t ${DOCKER_IMAGE}:${VERSION} ."
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

                        // Find latest version branch
                        def latestVersionBranch = sh(
                            script: "git branch -r | grep 'origin/v' | sort -Vr | head -n1 | awk -F'/' '{print \$2}'",
                            returnStdout: true
                        ).trim()

                        // Merge latest version into main
                        if (latestVersionBranch && latestVersionBranch != mainBranch) {
                            echo "🔀 Merging latest version branch ${latestVersionBranch} into ${mainBranch}"
                            sh "git checkout ${mainBranch}"
                            sh "git pull origin ${mainBranch}"
                            sh "git merge origin/${latestVersionBranch} || echo '⚠️ Nothing to merge or merge conflict'"
                            sh "git push origin ${mainBranch}"
                        } else {
                            echo "ℹ️ No version branches found or already up to date"
                            sh "git checkout ${mainBranch}"
                            sh "git pull origin ${mainBranch}"
                        }

                        // Create or reset version branch
                        def branchExists = sh(script: "git branch -r | grep -w ${remoteBranchRef}", returnStatus: true) == 0

                        if (branchExists) {
                            echo "🔁 Branch ${newBranchName} exists, resetting it"
                            sh "git checkout ${newBranchName}"
                            sh "git reset --hard ${remoteBranchRef}"
                        } else {
                            echo "🌱 Creating new branch ${newBranchName} from updated ${mainBranch}"
                            sh "git checkout -b ${newBranchName}"
                            sh "git push origin ${newBranchName}"
                        }

                        // Commit version.json and artifacts
                        sh "mkdir -p artifacts"
                        sh "cp -r test-report.xml artifacts/ || echo '⚠️ No test-report.xml found'"
                        sh "git add version.json artifacts/"
                        sh "git commit -m 'Add version.json and build artifacts for ${env.VERSION}' || echo '⚠️ No changes to commit'"
                        sh "git push origin ${newBranchName}"
                        echo "✅ Branch ${newBranchName} updated with version.json and artifacts"

                        // Update main branch again (optional)
                        sh "git checkout ${mainBranch}"
                        sh "git push origin ${mainBranch}"
                        echo "✅ Branch ${mainBranch} updated"

                        // Create tag if not exists
                        def tagName = "v${env.VERSION}"
                        def remoteTagExists = sh(script: "git ls-remote --tags origin ${tagName}", returnStatus: true) == 0

                        if (!remoteTagExists) {
                            def localTagExists = sh(script: "git tag -l ${tagName}", returnStatus: true) == 0
                            if (!localTagExists) {
                                sh "git tag ${tagName}"
                            }
                            sh "git push origin ${tagName}"
                            echo "🏷️ Tag ${tagName} created and pushed"
                        } else {
                            echo "⚠️ Tag ${tagName} already exists on remote, skipping tag creation"
                        }

                        // ⏫ Bump version for next build with [ci skip]
                        def (major, minor, patch) = env.VERSION.tokenize('.').collect { it as int }
                        patch += 1
                        def nextVersion = "${major}.${minor}.${patch}"

                        def versionFile = readFile('version.json')
                        versionFile = versionFile
                            .replaceFirst(/\"version\":\s*\"${env.VERSION}\"/, "\"version\": \"${nextVersion}\"")
                            .replaceFirst(/\"buildDate\":\s*\".*?\"/, "\"buildDate\": \"${new Date().format('yyyy-MM-dd HH:mm')}\"")
                        writeFile file: 'version.json', text: versionFile

                        sh "git add version.json"
                        sh "git commit -m 'Prep next version ${nextVersion} [ci skip]' || echo '⚠️ No next version bump to commit'"
                        sh "git push origin ${mainBranch}"
                        echo "🔁 Prepared for next dev version: ${nextVersion}"

                        // Cleanup credentials
                        sh "rm ~/.git-credentials"
                        sh "git config --global --unset credential.helper"

                        echo "📦 Finished: ${newBranchName} ready, tagged, and main is bumped"
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
                    build job: 'Provisioning'
                }
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
