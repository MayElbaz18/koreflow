pipeline {
    agent any         

    environment {
        DOCKER_IMAGE = "maye18/koreflow"
        GIT_CREDS    = 'github-credentials'
        DOCKER_CREDS = 'dockerhub-credentials'
        AWS_CREDS_ID = 'aws-credentials'
        SSH_KEY_CRED_ID = 'ssh-credentials'
        DOCKER_BUILDKIT = '1'

        VERSION = ''      
        NOTES   = ''
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

        stage('Docker Login, Build and Tag') {
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
                    sudo docker push ${env.DOCKER_IMAGE}:${env.VERSION}
                """
            }
        }
    }

    post {
        always {
            node('built-in') { cleanWs() }
        }
    }
}
