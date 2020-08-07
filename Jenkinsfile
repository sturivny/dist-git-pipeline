#!groovy

@Library('fedora-pipeline-library@distgit') _

def pipelineMetadata = [
    pipelineName: 'dist-git',
    pipelineDescription: 'Run tier-0 tests from dist-git',
    testCategory: 'functional',
    testType: 'tier0-tf',
    maintainer: 'Fedora CI',
    docs: 'https://github.com/fedora-ci/rpmdeplint-pipeline',
    contact: [
        irc: '#fedora-ci',
        email: 'ci@lists.fedoraproject.org'
    ],
]
def artifactId
def testingFarmResult

def testType


pipeline {

    options {
        buildDiscarder(logRotator(daysToKeepStr: '180', artifactNumToKeepStr: '100'))
        timeout(time: 4, unit: 'HOURS')
    }

    agent {
        label 'master'
    }

    parameters {
        string(name: 'ARTIFACT_ID', defaultValue: '', trim: true, description: '"koji-build:&lt;taskId&gt;" for Koji builds; Example: koji-build:46436038')
        string(name: 'ADDITIONAL_ARTIFACT_IDS', defaultValue: '', trim: true, description: 'A comma-separated list of additional ARTIFACT_IDs')
    }

    environment {
        TESTING_FARM_API_KEY = credentials('testing-farm-api-key')
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    artifactId = params.ARTIFACT_ID

                    if (!artifactId) {
                        abort('ARTIFACT_ID is missing')
                    }

                    setBuildNameFromArtifactId(artifactId: artifactId)

                    def repoUrl = getRepoUrlFromTaskId("${artifactId.split(':')[1]}")
                    if (repoHasStiTests(repoUrl: repoUrl, branch: env.BRANCH_NAME) {
                        testType = 'sti'
                    } else if (repoHasTmtTests(repoUrl: repoUrl, branch: env.BRANCH_NAME) {
                        testType = 'tmt'
                    }

                    if (!testType) {
                        abort('No dist-git tests (STI/TMT) were found, skipping...')
                    }
                }
            }
        }

        stage('Test') {
            steps {
                sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())                

                script {
                    def requestPayload = """
                        {
                            "api_key": "${env.TESTING_FARM_API_KEY}",
                            "test": {
                                "${testType}": {
                                    "url": "${getGitUrl()}",
                                    "ref": "${getGitRef()}"
                                }
                            },
                            "environments": [
                                {
                                    "arch": "x86_64",
                                    "variables": {
                                        "RELEASE_ID": "${getReleaseIdFromBranch()}",
                                        "TASK_ID": "${artifactId.split(':')[1]}"
                                    }
                                }
                            ]
                        }
                    """
                    // def response = submitTestingFarmRequest(payload: requestPayload)
                    
                    sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())

                    // testingFarmResult = waitForTestingFarmResults(requestId: response['id'], timeout: 60)
                    // evaluateTestingFarmResults(testingFarmResult)

                }
            }
        }
    }

    post {
        success {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testingFarmResult: testingFarmResult, dryRun: isPullRequest())
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, testingFarmResult: testingFarmResult, dryRun: isPullRequest())
        }
    }
}
