#!groovy

@Library('fedora-pipeline-library@prototype') _

import org.fedoraproject.jenkins.koji.Koji

def podYAML = """
spec:
  containers:
  - name: ci-runner
    image: quay.io/bgoncalv/fedoraci-dist-git:latest
    tty: true
    resources:
      limits:
        cpu: 1
        memory: "6Gi"
      requests:
        cpu: 1
        memory: "4Gi"
    securityContext:
        privileged: true
    env:
    - name: STR_CPU_LIMIT
      value: "6"
"""

def pipelineMetadata = [
    pipelineName: 'dist-git-pipeline',
    pipelineDescription: 'Fedora dist-git pipeline',
    testCategory: 'functional',
    testType: 'tier0',
    maintainer: 'Fedora CI',
    docs: 'https://github.com/fedora-ci/dist-git-pipeline',
    contact: [
	irc: '#fedora-ci',
	email: 'ci@lists.fedoraproject.org'
    ],
]

def buildName
def test_playbooks
def artifactId
def hasTests = false
def xunit = ""

pipeline {

    options {
        buildDiscarder(logRotator(daysToKeepStr: '180', artifactNumToKeepStr: '100'))
        timeout(time: 12, unit: 'HOURS')
    }

    agent {
        kubernetes {
            yaml podYAML
            defaultContainer 'ci-runner'
        }
    }

    parameters {
        string(
            name: 'task_id',
            defaultValue: "",
            trim: true,
            description: 'Koji task id. Example: 1234547'
        )
        string(
            name: 'additional_task_ids',
            defaultValue: "",
            trim: true,
            description: 'Other task ids from group build (space separated)'
        )
        string(
            name: 'repo',
            defaultValue: "",
            trim: true,
            description: 'Repository name for PR'
        )
        string(
            name: 'branch',
            defaultValue: "",
            trim: true,
            description: 'Branch name for PR'
        )
        string(
            name: 'pr',
            defaultValue: "",
            trim: true,
            description: 'PR number'
        )
        string(
            name: 'namespace',
            defaultValue: "rpms",
            trim: true,
            description: 'PR namespace'
        )
        string(
            name: 'FEDORA_CI_MESSAGE_PROVIDER',
            defaultValue: "RabbitMQ",
            trim: true,
            description: 'Message provider'
        )
        booleanParam(
            name: 'dryRun',
            defaultValue: true,
            description: 'If true, no ci message will be sent'
        )
    }

    stages {
        stage('Prepare env') {
            options {
                timeout(time: 5, unit: 'MINUTES')
            }
            steps{
                script {
                    if (params.task_id){
                        def koji = new Koji()
                        def task_info = koji.getTaskInfo( params.task_id.toInteger() )

                        env.repo = task_info.packageName
                        env.build_target = koji.getBuildTargets( task_info.target )[0][ 'name' ]
                        def tagMatcher = build_target =~ /(f\d+).*/
                        if (env.build_target == "rawhide") {
                            env.release = env.build_target
                        } else if (tagMatcher.matches()) {
                            env.release = tagMatcher[0][1]
                        } else {
                            error("unsupported build target ${env.build_target}")
                        }
                        buildName = "${env.release}:${env.task_id}:${task_info.nvr}"
                        currentBuild.displayName = buildName
                        currentBuild.description = "<a href=\"https://koji.fedoraproject.org/koji/taskinfo?taskID=${env.task_id}\">Koji ${env.task_id}</a>"
                        env.branch = env.release
                        if (env.branch == "rawhide") {
                            env.branch = "master"
                        }
                        artifactId = "koji-build:${env.task_id}"

                    } else if (env.pr) {
                        buildName = "PR-${env.namespace}:${env.repo}:${env.pr}"
                        currentBuild.displayName = buildName
                        currentBuild.description = "<a href=\"https://src.fedoraproject.org/${env.namespace}/${env.repo}/pull-request/${env.pr}\">PR: ${env.pr}</a>"
                        env.release = env.branch
                        env.dist_ver =  env.branch
                        if (env.branch == "master") {
                            env.release = "rawhide"
                        }
                    } else {
                        error("Don't know how what to test")
                    }

                }
                // split script as workaround for https://github.com/fedora-ci/jenkins-pipeline-library/issues/13
                script {
                    if (params.task_id){
                        sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: params.dryRun)
                    }
                }
            }
        }
        stage('Get repo') {
            options {
                timeout(time: 5, unit: 'MINUTES')
            }
            steps{
                script {
                    def params = "--repo ${env.repo} --branch ${env.branch} --namespace ${env.namespace}"
                    if (env.pr) {
                        params += " --pr ${env.pr}"
                    }
                    def logs = "get-repo"
                    sh "python3 /tmp/checkout-repo.py ${params} -v --logs ${logs}  || true"
                    def result = readJSON file: "${logs}/checkout-repo.json"
                    if (result["status"] != 0) {
                        error(result["error_reason"])
                    }
                    test_playbooks = result["test_playbooks"]
                    if (test_playbooks.size() > 0) {
                        hasTests = true
                    }
                }
            }
        }

        stage('Build from PR') {
            environment {
                KOJI_KEYTAB = credentials('fedora.keytab')
            }
            options {
                timeout(time: 8, unit: 'HOURS')
            }
            steps {
                script {
                    if (!hasTests) {
                        return
                    }
                    if (env.pr) {
                        def logs = "build-pr"
                        sh "python3 /tmp/create-build.py --repo ${env.repo} --release ${env.release} --logs ${logs} -v || true"

                        def result = readJSON file: "${logs}/create-build.json"
                        if (result["status"] != 0) {
                            error(result["error_reason"])
                        }
                        env.task_id = result["task_id"]
                        artifactId = "koji-build:${env.task_id}"
                    }
                }
            }
        }

        stage('Prepare qcow2') {
            options {
                timeout(time: 30, unit: 'MINUTES')
            }
            steps {
                script {
                    if (!hasTests) {
                        return
                    }
                    sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: params.dryRun)
                    def params = "--release ${env.release}"
                    if (env.namespace == "rpms") {
                        params += " --task-id ${env.task_id}"
                    }
                    if (env.additional_task_ids != "") {
                        def tasks = env.additional_task_ids.split(" ")
                        tasks.each { id ->
                            params += " --additional-task-id ${id}"
                        }
                    }
                    def logs = "prepare-qcow2"
                    sh "python3 /tmp/virt-customize.py ${params} --install-rpms --no-sys-update --artifacts ${logs} || true"
                    def result = readJSON file: "${logs}/virt-customize.json"
                    if (result["status"] != 0) {
                        error(result["error_reason"])
                    }
                    env.qcow2_image = result["image"]
                }
            }
        }

        stage('nvr verify') {
            options {
                timeout(time: 5, unit: 'MINUTES')
            }
            steps {
                script {
                    if (!hasTests) {
                        return
                    }
                    def logs = "nvr-verify"
                    sh "python3 /tmp/run-playbook.py --image ${env.qcow2_image} --playbook /tmp/rpm-verify.yml --no-check-result --artifacts ${logs} -e rpm_repo=/opt/task_repos/${env.task_id} -v || true"
                    def result = readJSON file: "${logs}/run-playbook.json"
                    if (result["status"] != 0) {
                        artifacts = result["artifacts"]
                        sh "cat ${artifacts}/*"
                        error(result["error_reason"])
                    }
                }
            }
        }

        stage('run test') {
            options {
                timeout(time: 8, unit: 'HOURS')
            }
            steps {
                script {
                    if (!hasTests) {
                        return
                    }
                    test_playbooks.each { playbook ->
                        pb_artifact = playbook.split("\\.")[0]
                        def artifact = "${WORKSPACE}/run-tests/${pb_artifact}"
                        sh "mkdir -p ${artifact}"
                        sh "cd ${env.repo}/tests && python3 /tmp/run-playbook.py --image ${env.qcow2_image} --playbook ${playbook} --artifacts ${artifact} -v 2>&1 | tee ${artifact}/console.txt"
                        def result = readJSON file: "${artifact}/run-playbook.json"
                        artifacts = result["artifacts"]
                        if (result["status"] != 0) {
                            // At least 1 playbook didn't pass
                            currentBuild.result = "UNSTABLE"
                        }
                        sh "ls ${artifacts}/* || true"
                    }
                    def log_url = "${env.BUILD_URL}/artifact/run-tests"
                    sh "python3 /tmp/merge-results.py -r run-tests --logs run-tests -o run-tests/merged_results.yml -x run-tests/xunit.xml -p ${log_url} -v"
                    xunit = sh(script: "cat run-tests/xunit.xml", returnStdout: true)
                }
            }
        }
    }

    post {
        always {
            script {
                archiveArtifacts artifacts: '**/*.*', excludes: "**/*.qcow2, **/*.rpm, **/task_repos/", allowEmptyArchive: true
            }
        }
        success {
            script {
                if (hasTests) {
                    sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, xunit: xunit, dryRun: params.dryRun)
                }
            }
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: params.dryRun)
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, xunit: xunit, dryRun: params.dryRun)
        }
    }
}
