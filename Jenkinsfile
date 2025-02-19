@Library('slack-notification')
import org.gradiant.jenkins.slack.SlackNotifier

pipeline {
    agent none

    stages {
        stage('Tests') {
            parallel {
                stage('shell') {
                    agent {
                        dockerfile {
                            label 'generic-docker'
                            filename 'ci/common.Dockerfile'
                            args '-u 0:0'
                        }
                    }
                    steps {
                        sh script: 'typos', label: 'check typos'
                        sh script: './qa-test --shell', label: 'shell scripts lint'
                    }
                    post {
                        always {
                            // linters results
                            recordIssues enabledForFailure: true, failOnError: true, sourceCodeEncoding: 'UTF-8',
                                         tool: checkStyle(pattern: '.shellcheck/*.log', reportEncoding: 'UTF-8', name: 'Shell scripts')

                            script {
                                new SlackNotifier().notifyResult("shell-team")
                            }
                        }
                    }
                }
                stage('man') {
                    agent {
                        dockerfile {
                            label 'generic-docker'
                            filename 'ci/common.Dockerfile'
                            args '-u 0:0'
                        }
                    }
                    steps {
                        dir("man") {
                            sh script: 'make', label: 'man page'
                        }
                    }
                    post {
                        always {
                            script {
                                new SlackNotifier().notifyResult("shell-team")
                            }
                        }
                    }
                }
            }
        }
    }
}
