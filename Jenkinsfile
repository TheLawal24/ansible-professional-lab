pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(true)
    }

    parameters {
        choice(
            name: 'DEPLOY_ENV',
            choices: ['dev', 'staging', 'prod'],
            description: 'Environment to deploy'
        )

        choice(
            name: 'ANSIBLE_TAGS',
            choices: ['webapp', 'docker', 'common'],
            description: 'Ansible role/tag to execute'
        )

        booleanParam(
            name: 'DRY_RUN',
            defaultValue: false,
            description: 'Run Ansible in check mode without applying changes'
        )
    }

    environment {
        TARGET_HOST = 'ubuntu-devops'
        ANSIBLE_HOST_OVERRIDE = '10.154.0.2'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                script {
                    def branch = env.GIT_BRANCH ?: 'unknown'

                    if (branch.startsWith('origin/')) {
                        branch = branch.substring(7)
                    }

                    env.CURRENT_BRANCH = branch

                    echo "Branch: ${env.CURRENT_BRANCH}"
                    echo "Environment: ${params.DEPLOY_ENV}"
                    echo "Ansible tags: ${params.ANSIBLE_TAGS}"
                    echo "Dry run: ${params.DRY_RUN}"
                }
            }
        }

        stage('Branch Policy') {
            steps {
                script {
                    if (params.DEPLOY_ENV == 'prod') {
                        if (env.CURRENT_BRANCH != 'main') {
                            error('Production deployments are allowed only from main.')
                        }
                    }

                    if (params.DEPLOY_ENV == 'staging') {
                        if (
                            env.CURRENT_BRANCH != 'main' &&
                            !env.CURRENT_BRANCH.startsWith('release/')
                        ) {
                            error('Staging deployments require main or a release/* branch.')
                        }
                    }

                    echo 'Branch policy passed.'
                }
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    echo "=== Ansible Version ==="
                    ansible --version

                    echo "=== Syntax Check ==="
                    ansible-playbook site.yml --syntax-check

                    echo "=== Inventory ==="
                    ansible-inventory --graph
                '''
            }
        }

        stage('Approval') {
            when {
                anyOf {
                    expression {
                        params.DEPLOY_ENV == 'staging'
                    }

                    expression {
                        params.DEPLOY_ENV == 'prod'
                    }
                }
            }

            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input(
                        message: "Approve deployment to ${params.DEPLOY_ENV}?",
                        ok: 'Approve Deployment'
                    )
                }
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
                        set -eu

                        VAULT_FILE="$(mktemp)"

                        cleanup() {
                            rm -f "$VAULT_FILE"
                        }

                        trap cleanup EXIT

                        printf '%s\n' "$JENKINS_VAULT_PASSWORD" > "$VAULT_FILE"
                        chmod 600 "$VAULT_FILE"

                        export SSH_PRIVATE_KEY="$JENKINS_SSH_KEY"
                        export VAULT_PASSWORD_FILE="$VAULT_FILE"
                        export ANSIBLE_TAGS="$ANSIBLE_TAGS"

                        if [ "$DRY_RUN" = "true" ]; then
                            echo "=== ANSIBLE CHECK MODE ==="

                            ansible-playbook site.yml \
                                --limit "$TARGET_HOST" \
                                --tags "$ANSIBLE_TAGS" \
                                --vault-password-file "$VAULT_PASSWORD_FILE" \
                                --private-key "$SSH_PRIVATE_KEY" \
                                -e "ansible_host=$ANSIBLE_HOST_OVERRIDE" \
                                --check
                        else
                            echo "=== REAL DEPLOYMENT ==="
                            ./scripts/deploy.sh
                        fi
                    '''
                }
            }
        }

        stage('Verify') {
            when {
                expression {
                    return params.DRY_RUN == false
                }
            }

            steps {
                sh '''
                    echo "=== Application Verification ==="

                    curl --fail \
                         --silent \
                         http://10.154.0.2:8081 \
                         | grep 'LAWAL-ANSIBLE-WEBAPP'

                    echo "Application verification successful."
                '''
            }
        }
    }

    post {
        success {
            script {
                currentBuild.description =
                    "${params.DEPLOY_ENV} | ${params.ANSIBLE_TAGS} | SUCCESS"
            }

            echo 'Pipeline completed successfully.'
        }

        failure {
            script {
                currentBuild.description =
                    "${params.DEPLOY_ENV} | ${params.ANSIBLE_TAGS} | FAILED"
            }

            echo 'Pipeline failed.'
        }

        aborted {
            echo 'Pipeline aborted or deployment approval rejected.'
        }

        always {
            deleteDir()
        }
    }
}