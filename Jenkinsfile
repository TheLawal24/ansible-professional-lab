pipeline {
    agent any

    environment {
        TARGET_HOST = 'ubuntu-devops'
        ANSIBLE_TAGS = 'webapp'
        ANSIBLE_HOST_OVERRIDE = '10.154.0.2'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    echo "=== Ansible Version ==="
                    ansible --version

                    echo "=== Playbook Syntax Check ==="
                    ansible-playbook site.yml --syntax-check
                '''
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ansible-ssh-key',
                        keyFileVariable: 'JENKINS_SSH_KEY',
                        usernameVariable: 'JENKINS_SSH_USER'
                    ),
                    string(
                        credentialsId: 'ansible-vault-password',
                        variable: 'JENKINS_VAULT_PASSWORD'
                    )
                ]) {
                    sh '''
                        set -e

                        VAULT_FILE="$(mktemp)"
                        trap 'rm -f "$VAULT_FILE"' EXIT

                        printf '%s\\n' "$JENKINS_VAULT_PASSWORD" > "$VAULT_FILE"
                        chmod 600 "$VAULT_FILE"

                        export SSH_PRIVATE_KEY="$JENKINS_SSH_KEY"
                        export VAULT_PASSWORD_FILE="$VAULT_FILE"

                        ./scripts/deploy.sh
                    '''
                }
            }
        }

        stage('Verify') {
            steps {
                sh '''
                    curl --fail \
                         --silent \
                         http://10.154.0.2:8081 \
                         | grep "LAWAL-ANSIBLE-WEBAPP"

                    echo "Application verification successful."
                '''
            }
        }
    }

    post {
        success {
            echo 'Ansible deployment completed successfully.'
        }

        failure {
            echo 'Deployment failed. Review the failed stage above.'
        }

        always {
            deleteDir()
        }
    }
}
