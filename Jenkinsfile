pipeline {
    agent none
    environment {
        DOCKER_IMAGE = "maye18/koreflow"
        GIT_CREDS = 'github-credentials'
        DOCKER_CREDS = 'dockerhub-credentials'
        AWS_CREDS_ID = 'aws-credentials'
        SSH_KEY_CRED_ID = 'ssh-credentials'
        DOCKER_BUILDKIT = '1'
        VERSION = ''
        NOTES = ''
        // DOCKER_CONFIG = "${env.WORKSPACE}/.docker"
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        AWS_REGION = 'us-west-2'
        CLUSTER_NAME = 'demo-environment'
        DEMO_ENV_INSTANCE_TYPE = 't3.medium'
        DEMO_ENV_COUNT = '1'
        KEY_NAME = 'monithor'
        SECURITY_GROUP_ID = 'sg-0f1a822015f1bc400'
    }
    stages {
        stage('Initialize Environment') {
            agent any
            steps {
                script {
                    def dockerGid = sh(returnStdout: true, script: 'getent group docker | cut -d: -f3').trim()
                    env.DOCKER_GID = dockerGid
                    echo "Discovered Docker GID on agent: ${env.DOCKER_GID}"
                }
            }
        }
        stage('Checkout SCM') {
            agent any
            steps {
                script {
                    sh "git config --global --add safe.directory ${env.WORKSPACE}"
                    echo 'Cleaning workspace before checkout...'
                    sh 'git clean -fdx'
                    echo 'Checking out SCM...'
                    checkout scm
                }
            }
        }
        stage('Check for version.json Changes') {
            when {
                changeset 'version.json'
            }
            agent any
            steps {
                script {
                    sh "git config --global --add safe.directory ${env.WORKSPACE}"
                    if (!fileExists('version.json')) {
                        error("version.json file not found in changes!")
                    }
                }
            }
        }
        stage('Parse version.json') {
            agent any
            steps {
                script {
                    sh "git config --global --add safe.directory ${env.WORKSPACE}"
                    def versionInfo = readJSON file: 'version.json'
                    env.VERSION = versionInfo.version
                    def notesList = versionInfo.notes
                    def tempNotes = ""
                    for (int i = 0; i < notesList.size(); i++) {
                        tempNotes += "- ${notesList[i]}"
                        if (i < notesList.size() - 1) {
                            tempNotes += "\n"
                        }
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
            agent any
            steps {
                script {
                    env.DOCKER_CONFIG = "${env.WORKSPACE}/.docker"
                    echo "DOCKER_CONFIG is set to: ${env.DOCKER_CONFIG}"
                }
            }
        }
        stage('Docker Login, Build and Tag') {
            agent any
            steps {
                sh 'mkdir -p ${DOCKER_CONFIG}'
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
                     sudo docker build \\
                        -t ${env.DOCKER_IMAGE}:${env.VERSION} \\
                        .
                """
            }
        }       
        stage('Push to Docker Hub') {
            agent any
            steps {
                sh """
                     sudo docker push ${env.DOCKER_IMAGE}:${env.VERSION}
                """
            }
        }
        stage('Provision AWS EC2 & Configure with Ansible') {
            agent any
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: env.DOCKER_CREDS,
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    ),
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: env.AWS_CREDS_ID,
                         accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                         secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]) {
                        // **מחיקת ip.txt ממעקב Git וגם פיזית, לפני יצירה מחדש.**
                        echo "Attempting to remove old ip.txt from Git tracking and WORKSPACE root..."
                        sh "git config --global --add safe.directory ${env.WORKSPACE}" // לוודא שגיט מכיר את התיקייה
                        sh "git rm --cached ip.txt || true" // || true כדי לא לגרום לכשל אם הקובץ לא במעקב
                        sh "rm -f ${env.WORKSPACE}/ip.txt"
                        echo "Old ip.txt removed from Git index and WORKSPACE (if it existed)."

                        dir(env.TERRAFORM_DIR) {
                            echo "Initializing Terraform..."
                            sh "terraform init"
                            echo "Planning Terraform changes..."
                            sh """
                                terraform plan -out=tfplan \\
                                -var="region=${env.AWS_REGION}" \\
                                -var="cluster_name=${env.CLUSTER_NAME}" \\
                                -var="demo_environment_type=${env.DEMO_ENV_INSTANCE_TYPE}" \\
                                -var="demo_environment_count=${env.DEMO_ENV_COUNT}" \\
                                -var="key_name=${env.KEY_NAME}" \\
                                -var="security_group_id=${env.SECURITY_GROUP_ID}"
                            """
                            echo "Applying Terraform changes..."
                            sh "terraform apply -auto-approve tfplan"
                            echo "Extracting public IP addresses..."
                            def publicIPsJSON = sh(returnStdout: true, script: "terraform output -json demo_environment_public_ips").trim()
                            def publicIPsList = readJSON(text: publicIPsJSON)
                            def firstPublicIP = publicIPsList[0]
                            writeFile file: "ip.txt", text: firstPublicIP
                            echo "Public IP saved to ${env.TERRAFORM_DIR}/ip.txt: ${firstPublicIP}"
                            sh 'cat ip.txt'
                            sh 'ls -l ip.txt'
                        }
                        echo "Copying ip.txt from ${env.TERRAFORM_DIR} to ${env.WORKSPACE}"
                        sh "cp ${env.TERRAFORM_DIR}/ip.txt ${env.WORKSPACE}/ip.txt"
                        echo "Content of ip.txt in WORKSPACE after copy:"
                        sh "cat ${env.WORKSPACE}/ip.txt"
                        echo "File details of ip.txt in WORKSPACE after copy:"
                        sh "ls -l ${env.WORKSPACE}/ip.txt"


                        dir(env.ANSIBLE_DIR) {
                            echo "Running Ansible inventory list to verify hosts..."
                            sh "ansible-inventory -i aws_ec2.yaml --list"
                        }
                        sshagent(credentials: [env.SSH_KEY_CRED_ID]) {
                            dir(env.ANSIBLE_DIR) {
                                echo "Running Ansible playbook using dynamic inventory..."
                                try {
                                    sh "ansible-playbook -i aws_ec2.yaml main.yaml -vvv"
                                    echo "Ansible configuration complete."
                                } catch (Exception e) {
                                    error "Ansible playbook failed: ${e.message}"
                                }
                            }
                        }
                    }
                }
            }
        }
        stage('Commit IP to Git') {
            agent any
            steps {
                script {
                    dir(env.WORKSPACE) {
                        withCredentials([usernamePassword(
                            credentialsId: env.GIT_CREDS,
                            usernameVariable: 'GIT_USERNAME',
                            passwordVariable: 'GIT_PASSWORD'
                        )]) {
                            sh "git config --global --add safe.directory ${env.WORKSPACE}"
                            sh """
                                git config --global user.name "${GIT_USERNAME}"
                                git config --global user.email "${GIT_USERNAME}@users.noreply.github.com"
                                git config --global url."https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/".insteadOf "https://github.com/"
                            """
                            echo "Attempting to checkout 'test' branch..."
                            sh 'git checkout test || git checkout -b test'

                            // **התיקון כאן:** שינוי הגרשיים מ-" ל-'
                            sh 'echo "Current working directory: $(pwd)"'

                            echo "Content of ip.txt at WORKSPACE root before Git ops:"
                            sh 'cat ip.txt || echo "ip.txt not found at WORKSPACE root."'
                            echo "File details of ip.txt at WORKSPACE root before Git ops:"
                            sh 'ls -l ip.txt || echo "ip.txt not found at WORKSPACE root."'


                            echo "Checking .gitignore for ip.txt:"
                            sh 'git check-ignore -v ip.txt || echo "ip.txt is not ignored by .gitignore."'
                            echo "Git status before adding new ip.txt:"
                            sh 'git status'
                            echo "Git diff for ip.txt (should show changes if any):"
                            sh 'git diff ip.txt || echo "No diff for ip.txt. (Expected if IP has not changed from last commit)"'
                            echo "Git diff --cached for ip.txt:"
                            sh 'git diff --cached ip.txt || echo "No staged diff for ip.txt."'

                            def ipContent = readFile('ip.txt').trim()
                            def commitMessage = "Add/Update demo_environment IP: ${ipContent}"

                            echo "Attempting git add ip.txt (to add the new/updated file)"
                            sh "git add ip.txt"
                            echo "Git status after add ip.txt:"
                            sh 'git status'

                            echo "Attempting git commit with message: ${commitMessage}"
                            sh "git diff-index --quiet HEAD || git commit -m \"${commitMessage}\""
                            sh "git diff-index --quiet HEAD && echo 'No changes to commit. (This is expected if IP has not changed)' || true"

                            echo "Attempting git push"
                            sh "git push origin HEAD:test"
                            echo "ip.txt committed and pushed to Git."
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            node('built-in') {
                cleanWs()
            }
        }
    }
}
