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
        // DOCKER_CONFIG = "${env.WORKSPACE}/.docker" // This will be set in a stage now
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        AWS_REGION = 'us-west-2'
        CLUSTER_NAME = 'demo-environment'
        DEMO_ENV_INSTANCE_TYPE = 't3.medium'
        DEMO_ENV_COUNT = '1'
        KEY_NAME = 'monithor'
        SECURITY_GROUP_ID = 'sg-02b3d29bdcd49a0cc'
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
}
    post {
        always {
            node('built-in') {
                cleanWs()
            }
        }
    }
}
